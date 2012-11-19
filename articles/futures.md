A future is a concurrency construct that allows a programmer to schedule work
in a background thread while continuing execution of the program.  When the
value of the calculation is needed it's requested from the future proxy which
will either return it or block until it can if the value is not yet available.
Futures abstract some of the complexity inherent in scheduling a task to run in
the background and polling for its completion. We get asynchronous calculations
that happen concurrent to our main program's execution without callback
spaghetti and we're guaranteed to be able to get at the result when we require
it.

Sometimes it feels like we're supposed to fear concurrency as terrifying
complexity, but with the right patterns and practices concurrent programming is
more than manageable. We'll look at how a future could be implemented in ruby
and then dig into some examples to illustrate where they could be useful.

### A Naive Implementation

Let's scratch out a basic implementation of a `Future` proxy in ruby. In its
most basic form, it could look something like this:

```ruby
class Future
  def initialize(callable)
    @callable = callable
  end

  def run
    @thread ||= Thread.new { @value = @callable.call }

    self
  end

  def value
    run
    @thread.join unless defined?(@value)

    @value
  end
end
```

We have a simple class that is instantiated with a `callable` which is a `Proc`
or other object that responds to `call`. It exposes two methods. The first,
`run`, starts a thread in the background which invokes `call` on the given
`callable` object and sets the result as an ivar. The second, `value`, will
return the value if it's present or join the thread and block until it is
available.

We'll also add a convenience method to Kernel so we can use it anywhere we
want.

```ruby
module Kernel
  def future(&block)
    Future.new(block).run
  end
end
```

This method instantiates a new `Future`, runs it, and returns the proxy back to
the caller. Now we can use the `future` method to dispatch arbitrary tasks for
background execution and use the returned proxy to access the computed values
later in execution.

```ruby
>> calculation = future { 4 * 4 }
=> #<Future:0x007fa9511a2c08 @callable=#<Proc:0x007fa9511a2c30@(irb):10>, @thread=#<Thread:0x007fa9511a2be0 run>>
>> calculation.value
=> 16
```

As `Future` calls the block in a background thread, execution of multiple
futures will happen concurrently:

```ruby
futures = [
  future { sleep 2 },
  future { sleep 2 },
  future { sleep 2 }
]

futures.each(&:value)
```

We're building three futures here with a block in each that will sleep
for two seconds. If we were executing these serially, we'd expect about six
seconds of execution time as the iterator calls and sleeps for two seconds on
each execution.

```bash
jp@oeuf:~/workspace/tmp$ time ruby futures.rb

real  0m2.032s
user  0m0.024s
sys   0m0.006s
```

Each future started executing as soon as it was created in the background.
Since the three blocks were running at the same time, our dummy script executes
in about two seconds.

### Service Oriented Design

A practical example of why concurrency is important and where a pattern like
this might apply is within service oriented systems. As we begin to break down
our monolithic applications into services and daemons, within a web request we
may need to make some number of remote service calls in order to render a page
of content. A user might be authenticated via a user service, the page's
content might be stored in a remote CMS service, and recommendations for a user
might be stored within a recommender service. Of those three service calls at
least two can be run independently from the output of any other. When you
don't use concurrency to make these calls, it's like cooking dinner with only
one burner on your stove-top. You're now cooking one dish at a time so it takes
longer to get the food on the table.

In an oft-referenced [ACM Queue](http://queue.acm.org/) article,
[Werner Vogels](http://queue.acm.org/detail.cfm?id=1142065) asserted that
Amazon could make up to something like 100 service calls to assemble a page for
a visitor. In the same year, Amazon published their findings about the
relationship between their service's latency and customers' purchasing habits.
For every 100ms delay they were able to slice off of page load times,
[sales increased by 1%](http://www.strangeloopnetworks.com/resources/infographics/web-performance-and-ecommerce/amazon-100ms-faster-1-revenue-increase/).
So even if each request took 1 millisecond, if they were all done serially that
would cost 100 milliseconds and possibly one percent of sales. Considering the
complexity of what these services likely do, it seems reasonable that many take
longer to execute than that and that Amazon is probably doing much of this work
concurrently.

Using concurrent requests when farming portions of responsibility across
network-available services will make the most efficient use of our resources,
will reduce wall clock running time for requests, and allow our systems to
handle more transactions over a given amount of time.

### A Hacker News Crawler

Let's look at a contrived example. How would [RMS](http://stallman.org/) read
Hacker News? [Probably from the command line](http://stallman.org/stallman-computing.html).
Maybe even while eating breakfast,
[but I wouldn't bring it up.](https://secure.mysociety.org/admin/lists/pipermail/developers-public/2011-October/007647.html)
Let's build a simple script using Nokogiri to grab some URLs from the first
page of Hacker News, fetch each page, and print each article's title and
content onto STDOUT.

First, we'll define a simple `Page` object to represent an HTML document.

```ruby
require "open-uri"
require "nokogiri"

class Page
  def initialize(url)
    @url = url
  end

  def links
    document.css("a").map { |anchor| anchor["href"] }
  end

  def paragraphs
    document.css("p").map { |paragraph| paragraph.text }
  end

  def title
    node = document.css("title")
    node && node.text
  end

  def get
    document
    self
  end

  private

  def document
    @document ||= Nokogiri::HTML(content)
  end

  def content
    open(@url)
  end
end
```

A `Page` is instantiated with a URL and a call to `get` will pre-load the
document. There are a couple of accessor methods for what we suspect we'll
need such as the `title`, all of the `links` on a page, and all of the
content stored in `paragraphs`.

We'll create an object to represent the Hacker News homepage called `Index`:

```ruby
class Index
  URL = "http://news.ycombinator.com"

  def initialize
    @page = Page.new(URL)
  end

  def urls
    links = @page.links.select { |link| link.start_with?("http") }
    links[1..25]
  end
end
```

This object is composed of a page and has a method to return 25 of the absolute
`urls` on the page. This will exclude internal navigation links from the header.

Next we'll put together a simple `Crawler` to use these objects to get the
content from Hacker News. Our first stab at this will be synchronous so each
page will be fetched in serial:

```ruby
class Crawler
  def initialize(index)
    @index = index
  end

  def crawl
    pages.each do |page|
      Outputter.new(page).output
    end
  end

  private

  def pages
    @index.urls.map do |url|
      Page.new(url).get
    end
  end
end
```

The `Crawler` expects an `Index` object which responds to `urls` to be passed
into its initializer. Once it gets each page it'll pass that to `Outputter`: a
pretty printer used to display our contents neatly to the terminal. We'll use
the `HighLine` gem to handle most of the real work:

```ruby
require "highline"

class Outputter
  OUTPUT_WIDTH = 79

  def initialize(page)
    @page = page
  end

  def output
    highline.say("-" * OUTPUT_WIDTH)
    highline.say(@page.title)
    highline.say("-" * OUTPUT_WIDTH)

    highline.say(@page.paragraphs.join("\n\n"))
    highline.say("\n\n")
  end

  private

  def highline
    @highline ||= HighLine.new($stdin, $stdout, OUTPUT_WIDTH)
  end
end
```

Finally, we'll glue together a small script to introduce our `Crawler` and
`Index` and drive our program:

```ruby
require "future"
require "crawler"
require "index"
require "page"
require "outputter"

Crawler.new(Index.new).crawl
```

Since we're doing this synchronously, let's use `time` to figure out how long
this takes to run:

```text
jp@oeuf:~/workspace/crawler$ time ruby ./crawl
-------------------------------------------------------------------------------
The Quiet Ones - NYTimes.com
-------------------------------------------------------------------------------

EVER since I quit hanging out in Baltimore dive bars, the only place where I
still regularly find myself in hostile confrontations with my fellow man is
Amtrak’s Quiet Car. The Quiet Car, in case you don’t know, is usually the first
car in Amtrak’s coach section, right behind business class. Loud talking is
forbidden there — any conversations are to be conducted in whispers. Cellphones
off; music and movies on headphones only. There are little signs hanging from
the ceiling of the aisle that explain this, along with a finger-to-lips icon.
The conductor usually makes an announcement explaining the protocol.
Nevertheless I often see people who are ignorant of the Quiet Car’s rules take
out their cellphones to resume their endless conversation, only to get a polite
but stern talking-to from a fellow passenger.

...
real  0m32.405s
user  0m2.403s
sys   0m0.161s
```

Pretty pokey. Now let's use our `Future` object to run the requests. We'll
modify `Crawler` to first create a future for each URL and to pass each `value`
returned to the `Outputter`:

```ruby
class Crawler
  def initialize(index)
    @index = index
  end

  def crawl
    pages.each do |page|
      Outputter.new(page).output
    end
  end

  private

  def pages
    futures.map(&:value)
  end

  def futures
    @index.urls.map do |url|
      future { Page.new(url).get }
    end
  end
end
```

Let's run it again using `time`:

```text
jp@oeuf:~/workspace/crawler$ time ruby ./crawl
...

real  0m6.942s
user  0m2.296s
sys   0m0.164s
```

It's 4.5x faster because each request starts when we call `future` and happens
concurrently. It's like making 25 people making a phone call at the same time
rather than one person making 25 phone calls in serial.

This finished command line application is on [GitHub](http://github.com/jpignata/crawler).

### Our Concurrent Futures

The rise of service-oriented systems and the reality that we're likely to keep
getting more cores rather than faster processors in our computers will make
concurrency tools even more important when building our applications. Patterns
like futures allow us to more easily reason about what's actually happening in
a concurrent program. While our naive implementation isn't suitable for real
world use due to its lack of any error handling or the absence of a pool of
threads, the [Celluloid](http://github.com/celluloid/celluloid) library has a
[futures implementation](https://github.com/celluloid/celluloid/wiki/futures)
that is ready to be used in your production applications.