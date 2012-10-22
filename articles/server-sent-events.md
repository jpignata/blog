In the long, long ago: to auto-update content on a web page your trusty hammer was a kludge of a `setInterval` callback which polled an HTTP endpoint via XHR and manipulated the page when new content was available. While still common (and even [preferred by some](https://twitter.com/dhh/status/251005914344222720)), it seems naggingly inefficient. Every few seconds we have to spin up a TCP connection, send a full HTTP request, wait for the server to do some kind of work and snarf back and parse an entire HTTP response.




All of this redundant chatter and connection establish/tear-down cycles aren't free. As more traffic moves to mobile clients these inefficiencies have real-world impact -- namely on things like battery life and data transfer costs. Keepalive and `If-Modified-Since` or `ETag` request headers might make polling more efficient but your server is still tied up on each request doing redundant work for each client to figure out if there's new content and your clients are still burning cycles spinning through this process. Moreover, HTTP requests often become bloated with components like cookies, locale preferences, tweet-sized user-agent strings, etc. that are unnecessarily shoveled over the wire in each request.


In response to the downsides of polling other techniques emerged for handling real-time content updates on a web page. These techniques are sometimes collectively referred to as "comet." Techniques include long-polling which holds open an HTTP connection until new content is available to HTTP streaming which uses either a multipart request or other chunked response to send data back to a web client. Each has its own quirks and downsides and none are natively handled by a browser. Ultimately what developers want is a channel that can be natively established via a browser API.


WebSockets was drafted in order to meet this need. WebSockets provides a full-duplex channel between HTTP clients and servers. Defined in [RFC 6455](http://tools.ietf.org/html/rfc6455) and weighing in at 71 pages, the protocol handles negotiation between client and server, has its own security extensions and defines its own frame. This complexity exists for a reason: tunnel a new protocol over HTTP turned out to be less trivial than initial conceived. Dealing with all of the HTTP-speaking proxies, servers and clients deploy to the Internet in a safe and secure way has made the protocol basically unusable for many situations. For example, try getting a WebSocket connection through an Amazon Elastic Load Balancer or various mobile proxies. For all of this complexity, in many cases a simplex connection that sends some small amount of data is all that is required.




### Enter Server-Side Events (SSE)


Opera in 2006
WHATWG specification
W3C specification


### Example: Shared Picture Frame


![](/images/server-sent-events/pumpkin.png)
![](/images/server-sent-events/clownfish.png)
![](/images/server-sent-events/ice-cream.png)
![](/images/server-sent-events/sushi.png)


In this example we'll build a toy application that creates a shared picture
frame. Any user can enter a search term which searches Flickr's API for that
term, retrieves a random image from the results and broadcasts it via a
Server-Sent Event. Each client listening to the channel then updates the
background of the page.
<script src="https://gist.github.com/3928474.js?file=gistfile1.coffee"></script>


[http://picture-frame.herokuapp.com](http://picture-frame.herokuapp.com)
[https://github.com/jpignata/picture-frame](https://github.com/jpignata/picture-frame)

Server-Sent Events you get a few nicities for free: connections will auto-reconnect.



Automatic reconnect
Avoids blocking other traffic
Reuses connections




Limitations
UTF-8
CORS




Interoperable outside of HTTP (think SMS and push notifications)

