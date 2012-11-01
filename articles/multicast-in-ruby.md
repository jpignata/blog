IP multicasting allows a node to send one datagram to multiple interested
receivers. Hosts indicate their interest in traffic by subscribing to a
multicast address. Datagrams sent to this multicast address will be received
by all member nodes on a local network. A multicast address is any host
address in the 224/8 - 239/8 range of addresses which is reserved for
multicast.

Services that use multicasting are not often found on the public internet due
to the complexities involved in sharing this subscription state between
neighboring external networks and the lack of incentive for ISPs to support
it. You probably don't use multicast directly day-to-day, but if you're using
a MacOS or Linux system it's likely to be a member of a couple of multicast
groups by default.

<script src="https://gist.github.com/3990906.js?file=netstat-g.txt"></script>

`224.0.0.1` is the All Hosts multicast group.
[`RFC1122`](http://www.ietf.org/rfc/rfc1112.txt) dictates that all hosts that
fully support multicasting must always maintain a membership for it.
224.0.0.251 is the mDNS multicast group which MacOS uses for DNS resolution of
the .local domain.

If we send an ICMP echo request to either of these addresses, we'll get back an
ICMP echo reply for each member host:

<script src="https://gist.github.com/3990906.js?file=ping.txt"></script>

Using `tcpdump` we can see that while we only send one request we get two replies
with the same sequence number:

<script src="https://gist.github.com/3990906.js?file=tcpdump.txt"></script>

### Multicasting in Ruby

Ruby's `socket` library exposes a wrapper to the underlying operating system
socket implementation. Normally we'd be working with abstractions well above
`socket`. It's pretty low-level and isn't the friendliest library to work
with, but it allows us to directly manipulate sockets directly to properly
bind to the multicast address group.

Here's a basic send/receive example. The first script, `send.rb`, opens up a
UDP socket, sets the multicast TTL of the datagram to 1 to prevent it from
being forwarded beyond our local network, and sends whatever the first
command line argument passed to the script was across the socket.

<script src="https://gist.github.com/3990906.js?file=send.rb"></script>

`receive.rb` also opens a UDP socket but does a little more work to set itself
up to receive messages from the multicast address group. It sets two options
on the socket: one to add the membership to the IP multicast group and one to
allow multiple receivers to bind to the same port. The second option allows
two or more programs on the same host to receive messages from the same
multicast group. Lastly, it binds to the address and port and then sets up a
small loop to block, wait for a message, and print its contents to the
terminal.

<script src="https://gist.github.com/3990906.js?file=receive.rb"></script>

![](/images/multicast-in-ruby/demo.gif)

The `socket` library is not the easiest to work with and usually involves a
lot of man page reading. Previous editions of the
[pickaxe](http://pragprog.com/book/ruby3/programming-ruby-1-9) has an whole
appendix for the `socket` library but pragprog decided to remove it from the
book in its current incarnation. Luckily, they have [released its
contents](http://pragprog.com/book/ruby3/programming-ruby-1-9) for free in PDF
and e-reader formats.

### Chat, Serverlessly

Articles about building a chat server in a given toolset is a trope of
programming writing. Let's embrace the cliche and take that example but
implement it in as a peer to peer service using multicast to allow chat
clients on different hosts on the same network to exchange messages.

We'll call the project backchannel. Its basic operations are:

1. When the client receives a message through the socket from another user,
draw the message into the window

2. When the user types in a message and hits return, send that message to
other listening clients over the socket

Clients will become a member of a multicast group and use the group to
exchange chat messages. I used ruby to pick a random number (`rand(10_000)`)
and drew 6188 so I'll use 224.6.1.88 as the multicast address and bind to port
6188.

In our description we've mentioned three different nouns: a client, a window
and a message. Let's start by doing some cocktail napkin design.

![](/images/multicast-in-ruby/design.png)

`Client` is responsible for sending and receiving messages. It exposes a
listener interface to allow listeners to be alerted to new messages and a
transmit method for sending arbitrary content across the socket.

`Window` is responsible for managing the UI which entails drawing messages into
the terminal and capturing our input and sending new messages. It'll require a
handle onto the client to allow us to transmit messages and it'll need to keep
a backlog of messages to be able to draw chat history.

`Message` will be transmitted as a human readable JSON objects. It will have
three attributes: a client ID, the user's handle and some message content.
Let's start with `Message` since it's a simple value object:

<script src="https://gist.github.com/3990906.js?file=message.rb"></script>

No surprises there. We define `attr_reader` for the properties we're bundling
together and some convenience methods for JSON serialization and deserialization.

Next we'll look at `Client`. It's the object that knows how to send and
receive messages from the multicast address group. It exposes a method for
sending messages and a hook for allowing another object to listen for new
messages. Since it's the object responsible for chat operations, it will also
generate and hold a random `client_id` and hold the user's chosen `handle`.

<script src="https://gist.github.com/3990906.js?file=client.rb"></script>

Much of this code was adapted from the `send.rb` and `receive.rb` scripts above
but it has some of its own characteristics worth discussing. `listen` spins up
a new `Thread`. This is necessary because in order to listen for new messages
we're using a blocking call. Spinning up a `Thread` will allow our program to do
other work while waiting for new messages.

We've decoupled any interested receivers of messages from `Client` by
adding a hook to allow interested parties to subscribe to messages through the
`add_message_listener` method. Now our `Window` doesn't need to have any
concrete wiring to `Client` but rather just has to register itself on
initialization and implement a `new_message` method.

Window manages the UI and implements another dusty ruby wrapper -- `curses`.
I'm going to elide most of these details as those incantations are obscure and
will be the subject of a future article.

<script src="https://gist.github.com/3990906.js?file=window.rb"></script>

This class is fairly simple when most of the presentation layer cruft is
set aside. On initialization a `Client` is passed in and a new array is
initialized to store message history.

Once `start` is called, `Window` adds itself as a message listener.
`new_message` will be called by `Client` when a new message is available. That
method will add that message to the end of the array and call a `redraw`
method to do the dirty UI details.

User input is captured via a loop using `curses' getstr` method. We pass the
content to `Client` for transmission over the network. `Client` passes us back a
`Message` which we add to the collection and redraw the screen.

Finally, we have some glue code to introduce `Client` and `Window` and start
the program:

<script src="https://gist.github.com/3990906.js?file=backchannel.rb"></script>

The result of these three small classes is an IRC-like program that allows any
users connected over the same physical network to pass messages. Calling
`Backchannel.start` will draw the screen and wire up the client to the
multicast address group.

![](/images/multicast-in-ruby/pulp-fiction.png)

The [full source](http://github.com/jpignata/backchannel) of the final
application is on GitHub and you can play with it by running `gem install
backchannel` and starting backchannel with `backchannel <HANDLE>`. Since we're
setting `SO_REUSEPORT`, multiple programs on the same system can connect to
the same chat for demonstration purposes.

I've never used multicasting in a real-world application but will be keeping
my eyes open for an opportunity. Since we're all carrying around computers in
our pockets now, local, opt-in networks seem applicable to all kinds of things.
