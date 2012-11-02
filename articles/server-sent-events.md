In the long, long ago, to add real-time content to a web page your only option
was a kludge of a JavaScript timer to poll an HTTP endpoint via XHR and
manipulate the page when new data became available. Still common (and even
[preferred by some](https://twitter.com/dhh/status/251005914344222720)), Ajax
polling seems inefficient at best and retrograde at worst. Every few seconds
we have to spin up a TCP connection, send a full HTTP request, wait for the
server to do some kind of work, and snarf back and parse an entire HTTP response.

All of these redundant connections and chatter aren't free. As more traffic
moves to mobile clients these inefficiencies have real-world impact on users'
device battery life and data transfer costs. Keepalive and `If-Modified-Since`
or `ETag` request headers might help but your server is still tied up on each
request doing redundant work for each client to figure out if there's new
content and your clients are still burning cycles spinning through this
process. Moreover, HTTP requests often become bloated with attributes like
cookies, locale preferences, tweet-sized user-agent strings, etc. that are
unnecessarily shoveled across the connection in each request.

### Server-Sent Events (SSE)

An alternative to polling is the Server-Sent Events API. SSE provides a
simplex connection between a server and a client that allows the server to
trigger events in the browser. Web applications can bind a callback to these
events via JavaScript.

WebSockets has gotten much more attention than Server-Sent Events. One good
reason for this is that WebSockets is much more fully featured than SSE.
It's essentially a completely separate protocol from HTTP that provides a
full-duplex connection which makes it more attractive for applications that
require low-latency bi-directional communication. The trade-off is that since
it's not HTTP there's added complexity in implementing it. For example,
much of the HTTP infrastructure deployed out in the wild isn't necessarily
aware of WebSockets and consequently the protocol's traffic can't traverse it.
As it stands today getting a WebSockets-speaking server propped up behind a
traditional load balancer can prove to be somewhat painful.

SSE doesn't have any of this overhead as it uses traditional HTTP for transport.
It's directed at real-world network environments so it has features like
automatic reconnection baked into it. It's exposed in the browser via the
[`EventSource`](https://developer.mozilla.org/en-US/docs/Server-sent_events/EventSource)
interface so it's trivial to write a shim for [browsers that don't support it](http://en.wikipedia.org/wiki/Server-sent_events#Web_browsers) to fall back to long-polling.

A SSE event only has a couple of attributes and looks something like YAML:

```yaml
id: 1
event: new-message
data: oh, hi!
```

`event` is an optional custom name of the event to trigger. JavaScript
applications can bind to specific events or choose to bind to all messages.
`data` is what's passed into the event when triggered. `id` is an optional
unique identifier for the message. If provided, `Last-Event-ID` will be sent
back to the server on reconnect for applications where messages can't be
dropped. SSE also allows a server to specify a `retry` in milliseconds and 
comments can be sent with a line starting with a colon.

Binding to these events using JavaScript is straight-forward:

```javascript
var stream = new EventSource("/stream");

stream.addEventListener("new-message", function (event) {
  console.log(event.data);
});
```

Any `new-message` events that are transmitted through the connection will now
trigger this callback and log the message to the console.

The [specification](http://www.w3.org/TR/eventsource/) envisions the protocol
to be extensible to serve other purposes outside the browser. For example,
it's possible to extend it to be used as a transport to deliver push
notifications to mobile devices over TCP/IP or SMS networks.

### Picture Frame

Let's build a small application to illustrate how Server-Sent Events works.
In this example we'll put together a toy application that creates a shared picture
frame. Any user can enter a search term which searches Flickr's API for that
term, retrieves a random image from the results and broadcasts it via a
Server-Sent Event. Each client subscribed will receive the event and update the
background of the page.

![](/images/server-sent-events/sushi.png)
![](/images/server-sent-events/pumpkin.png)
![](/images/server-sent-events/ice-cream.png)
![](/images/server-sent-events/clownfish.png)

We'll use small components to keep the example focused and forego using any
specific framework. Since we want to be able to service connections
concurrently we'll use [Thin](http://code.macournoyer.com/thin/) as an
application server. Our implementation of the picture frame will be a Rack
application behind [HTTP Router](https://github.com/joshbuddy/http_router) for
routing between our actions and serving static content. We expect to have at
least two actions: one to subscribe to the SSE stream, one to publish new
content to the stream, a static HTML page to display the frame and a little
JavaScript to act on events from the stream.

If you return a `Deferrable` as the body of a response, [Thin will keep the
connection open](https://github.com/macournoyer/thin/blob/master/lib/thin/connection.rb#L115) until the deferred object is complete. [`Deferrable`
objects](http://eventmachine.rubyforge.org/docs/DEFERRABLES.html) represent an
operation in flight and accept two callbacks: a `callback` which is fired on
success and an `errback` which is fired on failure. We'll create a deferred
body which can be used to write to the active connection and to signal to Thin
when we want to close the connection.

```ruby
class Body
  include EM::Deferrable

  def each(&block)
    @callback = block
  end

  def write(data)
    @callback.call(data)
  end
end
```

When Thin calls `each` it'll pass a block that can be used to emit data to
the connection. We store that block and expose a `write` method for
calling it.

We can use this to build an endpoint that can handle concurrent connections
as long as we're careful not to block the reactor. Here's an example
rackup file that mounts a small Rack application that returns a ping each second
four times and then closes the connection.

```ruby
app = ->(env) {
  count = 0
  body = Body.new

  timer = EM.add_periodic_timer(1) {
    body.write "ping\n\n"
    count += 1

    if count == 5
      timer.cancel

      body.write "ok, bye!\n\n"
      body.succeed
    end
  }

  [200, {"Content-Type" => "text/plain"}, body]
}

run app
```

Now when we start the server it'll accept connections on the specified port
and only close that connection after four pings.

```text
jp@oeuf:~/workspace/tmp$ thin start -R example.ru -p 4000
>> Thin web server (v1.5.0 codename Knife)
>> Maximum connections set to 1024
>> Listening on 0.0.0.0:4000, CTRL+C to stop
```

![](/images/server-sent-events/curl.gif)

Now to the picture frame. Let's start with the subscribe action. This endpoint
will subscribe a user to the stream so it should keep the connection alive and
send events when they are triggered by another user. To start we'll build
a class that expects to be instantiated with a Rack `env` and a channel object
which will be used to transmit messages to subscribers.

```ruby
module Actions
  class Subscribe
    HEADERS = {
      "Content-Type"  => "text/event-stream",
      "Connection"    => "keepalive",
      "Cache-Control" => "no-cache, no-store"
    }

    def initialize(env, channel)
      @env = env
      @body = Body.new
      @channel = channel
    end

    def run
      @channel.subscribe do |message|
        body.write("event: picture\n")
        body.write("data: #{data.to_json}\n\n")
      end

      [200, HEADERS, @body]
    end
  end
end
```

This is the entirety of the server-side code necessary to build a Server-Sent
Events stream. We set the `Content-Type` of the response to `text/event-stream`
and setup our channel subscription to trigger a `picture` event when a new
message is received from the channel.

Next we'll build an endpoint for a user to perform a search. The publish
endpoint expects to receive a POST with a keyword parameter. It takes that
keyword and uses a `FlickrSearch` class to get the data to publish back to the
channel. For good measure it also sends the result to the original publisher
and suceeds the `Deferrable` which closes the channel. `FlickrSearch` is a
`Deferrable` that uses `em-http-request` to fetch data from Flickr and return
the result asynchronously. The result is an object that responds to `to_json`
and returns a hash that includes the original keyword that was used for the
search and the URL to a random result.

```ruby
module Actions
  class Publish
    def initialize(env, channel)
      @env = env
      @channel = channel
      @body = Body.new
    end

    def run
      search = FlickrSearch.new(params["keyword"]).get

      search.callback do |result|
        @channel.push(result)

        @body.write(result.to_json)
        @body.succeed
      end

      search.errback { @body.fail }

      [200, {"Content-Type" => "application/json"}, body]
    end

    private

    def params
      @params ||= Rack::Utils.parse_query(@env["rack.input"].read)
    end
  end
end
```

The only page of the application will be a small, static HTML page to setup
the a form to allow searches.

```html
<html>
  <head>
    <style type="text/css">
      input {
        position: absolute;
        font-size: 48px;
        bottom: 10px;
      }
    </style>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
    <script src="/js/application.js"></script>
  </head>
  <body>
    <form>
      <input type="text"></input>
    </form>
  </body>
</html>
```

To wire up the page to our stream we have a little bit of CoffeeScript glue
code.

```coffeescript
source = new EventSource("/subscribe")

source.addEventListener "picture", (event) ->
  data = JSON.parse(event.data)
  $("body, input").trigger "changeBackground", [data.url, data.keyword]

jQuery ->
  $("body").bind "changeBackground", (event, url, keyword) ->
    $(this).css(
      "background":              "url(#{url}) no-repeat center center fixed"
      "-webkit-background-size": "cover"
      "-moz-background-size":    "cover"
      "background-size":         "cover"
    )

  $("input").bind "changeBackground", (event, url, keyword) ->
    $(this).val("").attr("placeholder", keyword)

  $("form").submit (event) ->
    event.preventDefault()
    input = $(this).find("input")
    $.post "/publish", keyword: input.val()
```

The call to `EventSource` is all that is required to open up the stream.  When
we receive a picture event, we trigger a `changeBackground` event on our
`<body>` and `<input>` elements. The `jQuery` block sets up the nodes to
respond to `changeBackground` with their respective presentation logic. The
input clears what has been typed into it and sets a placeholder with the last
search and the body changes its background to the search's returned URL and
does some CSS incantations to make the background appear full screen.

We also bind a `submit` callback to our form to wire it up to POST to our
publish endpoint as an XHR request rather than a postback. Since we don't have
full-duplex communication via SSE, we're cheating by using Ajax for upstream
communications. This SSE Down/ Ajax Up approach is completely acceptable for
this application, but if it wasn't for some reason we might consider
WebSockets instead.

The Rack application to make these pieces work together is quite small. We're
going to inject a memoized `EventMachine::Channel` into each action to act as
the application's event bus and rely on `HTTP Router` to route requests to our
actions and serve our static index page and compiled JavaScript.

```ruby
class PictureFrame
  def self.app
    @routes ||= HttpRouter.new do
      post("/publish").
        to { |env| Actions::Publish.new(env, PictureFrame.channel).run }
      get("/subscribe").
        to { |env| Actions::Subscribe.new(env, PictureFrame.channel).run }
      add("/").static("public/index.html")
      add("/").static("public")
    end
  end

  def self.channel
    @channel ||= EventMachine::Channel.new
  end
end
```

Now that everything's stitched together, all users on the page will see its
background changed when another user enters a search term. It looks something
like this:

![](/images/server-sent-events/demo.gif)

```javascript
event: picture
data: {"url":"//farm1.staticflickr.com/48/177506457_6da382ee6d_z.jpg","keyword":"sushi"}

event: picture
data: {"url":"//farm4.staticflickr.com/3654/3649989777_5aecf0c923_z.jpg","keyword":"french fries"}

event: picture
data: {"url":"//farm5.staticflickr.com/4031/5074677539_647560db25_z.jpg","keyword":"staten island ferry"}

event: picture
data: {"url":"//farm7.staticflickr.com/6066/6135449745_5df2e0c5e7_z.jpg","keyword":"flatiron building"}
```


[The final application](http://picture-frame.herokuapp.com) is deployed to
Heroku and [the source](http://github.com/jpignata/picture-frame) is on
GitHub.

### Using SSE in Your Applications

If you only need a simplex channel to a web client to update some data,
Server-Sent Events is a viable alternative to crufty polling or complex
WebSockets. Even with bi-directional requirements SSE Down/Ajax Up might be
sufficient and save you the trouble of turning up a WebSockets connection.

[Rails 4.0 can be used](http://tenderlovemaking.com/2012/07/30/is-it-live.html) to
build these endpoints. [Goliath](http://postrank-labs.github.com/goliath/) or
[Cramp](http://cramp.in/) can also be used [to implement SSE](http://www.html5rocks.com/en/tutorials/casestudies/sunlight_streamcongress/) with a
Ruby server. Implementation from scratch with Node.js, Twisted and Python,
or your particular weapon of choice is likely just as straight-forward.

On the client side of the wall it's already built into most browsers and
easily reusable by your native applications. Since it's a simple DOM interface
it's trivial to use SSE to make your dynamic functionality more efficient
for sufficiently modern browsers while maintaining chattier long-polling
for older browsers.
