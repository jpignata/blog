When I'm reading Ruby code and I come across the `protected` keyword, I spend a moment taking a deeper look at the interface of the object using it. Protected method visibility is targeted to a very specific and seemingly rare use-case in Ruby: methods defined as protected are only callable by other objects whose class is of the same defining class or its subclasses. The [pickaxe book](http://pragprog.com/book/ruby3/programming-ruby-1-9) calls this "keeping it within the family."  [_The Ruby Programming Language_](http://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177) describes protected as "the least commonly defined and also the most difficult to understand" of the the method visibility types, so when I do see it I wonder what the author is trying to communicate. Is it a hint about the stability of the methods? Are the objects actually using protected access between instances? Did he or she want to encapsulate some behavior but use explicit `self` as a matter of style? Was this some unfortunate pattern promulgated by some random Ruby on Rails tutorial in 2007? Why would you reach for `protected` when the semantics of `private` seem sufficient to encapsulate an object's behavior?

Let's look at some of the common applications of protected method visibility. The most common patterns I've seen are: attributes for comparison operations, mutator methods, fulfilling an abstract class' contract, and framework hooks.

### Attributes for Comparison Operations

The most common employment of `protected` is applying it to attributes or methods that are necessary to compare two instances to each other without exposing that information in the object's public interface. Since operators on an object are actually method calls, we can override these methods and provide our own comparison logic for operations on an object. `protected` allows these objects to expose data needed in a comparison to each other but continue to hide it from the rest of the system.

For example, let's look at a simple `Collection` object. This object is responsible for management of a collection of items. The `Collection` doesn't expose the items directly but rather defines an interface for interacting with the internal array.

<script src="https://gist.github.com/3956477.js?file=collection-1.rb"></script>

Two `Collection` instances are deemed to be equal if they hold the same number of elements and the elements are in the same order. To expose this operation we define a method `==` on `Collection`:

<script src="https://gist.github.com/3956477.js?file=collection-2.rb"></script>

In order to compare the arrays we'll need to add an `items` getter but continue to hide this data from external callers. If we add a getter without specifying access control, a caller could access the contents of the array directly but if we set this method private, nobody -- including sibling objects -- will be able to access the property. `protected` does exactly what we want.

<script src="https://gist.github.com/3956477.js?file=collection-3.rb"></script>

`Collection` instances can now compare themselves to each other while still hiding their data from other callers. `Collection` objects will only respond to `items` for sibling `Collection` instances; calls from other objects will raise a `NoMethodError`.

<script src="https://gist.github.com/3956477.js?file=collection-4.rb"></script>

The usual caveat here is that in Ruby access control is "just a suggestion" and a user of an object can still reach in and access anything regardless of its visibility. For example:

<script src="https://gist.github.com/3956477.js?file=collection-5.rb"></script>

While this is true, there's still value in signaling your intentions to users of the object. Setting explicit access controls guides users to our defined interface and discourages fiddling with internals.

The Ruby standard library class `OpenStruct` uses this pattern. `OpenStruct` allows a user to set arbitrary attributes that can be accessed with dot notation.

<script src="https://gist.github.com/3956477.js?file=ostruct-1.rb"></script>

An `OpenStruct` is considered equal to another `OpenStruct` when they hold the same attributes. Under the hood `OpenStruct` stores these attributes in an internal hash table. It exposes this table as a protected method which allows other `OpenStruct` instances to determine equivalence. This is implemented similarly to the `Collection` example:

<script src="https://gist.github.com/3956477.js?file=ostruct-2.rb"></script>

### Mutator Methods for Immutable Objects

Another use of `protected` I found in the Ruby standard library is using protected methods to maintain the immutability of a value object. Let's say we've decided our `Collection` is a value object and [should be immutable](http://c2.com/cgi/wiki?ValueObjectsShouldBeImmutable). There are new requirements that necessitate some operations that require `Collection` to change during runtime. Let's start with the first: the sum of two `Collection` instances is a new `Collection` which holds a superset of the summands' arrays.

<script src="https://gist.github.com/3956477.js?file=collection-6.rb"></script>

Since we've marked `items` as `protected` we can reach in from one instance into another, grab these items, add them to our items and instantiate a new collection.

<script src="https://gist.github.com/3956477.js?file=collection-7.rb"></script>

<script src="https://gist.github.com/3956477.js?file=collection-8.rb"></script>

This simple example is fairly similar to our last -- it involves overriding an operator method and using privileged data from the sibling instance in the operations. While state in neither `Collection` changed, they were able to collaborate and return a new `Collection` with the desired `items`.

`IPAddr` is a class in the Ruby standard library which is a value object that represents an IPv4 or IPv6 address. Under the hood it makes extensive use of this pattern for manipulating the IP address it represent.

Given an IP address (say, `192.168.0.77`) and a subnet mask (`255.255.255.248`), we can use bitwise operations to figure out the upper and lower boundaries of the network of which this host is a member. The lower boundary is referred to as the network address and the upper boundary as the broadcast address.

<script src="https://gist.github.com/3956780.js?file=ipaddr-1.rb"></script>

`IPAddr` exposes these operations but maintains immutability by cloning itself and calling protected methods on the new instance.

<script src="https://gist.github.com/3956780.js?file=ipaddr-2.rb"></script>

Instead of changing its state during these operations, it creates a copy of itself using `clone` and calls protected methods like `set` to mutate the instance and return it to the caller.

### Fulfilling an Abstract Class's Contract

Another example of the `protected` keyword is in ActiveSupport's caching layer. `ActiveSuppot::Cache::Store` defines an abstract class that can be inherited to implement a pluggable caching layer. A minimal viable implementation of a cache store involves implementing three methods: `read_entry`, `write_entry` and `delete_entry`. These are called by the public API of the abstract class and implement a specific storage strategy. This separates the concerns of how the cache behaviors from the specifics of how its data is stored.

<script src="https://gist.github.com/3959423.js?file=cache-1.rb"></script>

ActiveSupport ships with implementations to store cache data in memory, a file and memcached. Each implementation has its own methods for interacting with its respective store.

<script src="https://gist.github.com/3959423.js?file=cache-2.rb"></script>

By marking the abstract interface methods with `protected` and the implementation methods for the storage mechanism as `private` there's a demarcation between the concerns. There's no direct reason in the implementation for using protected methods in this case. The calls to these protected methods use an implicit `self` which means private method calls would work to encapsulate the object's behavior. Using the `protected` keyword is primarily a matter of convention to call into relief which concerns belong to what components to aid in maintenance.

### Framework Hooks

Another conventional use of protected methods is for methods within an object that aren't called directly by the object but are callback hooks that a framework is configured to call. For example, `ActionController::Base` allows an inheriting class to define filters that are called at specific moments in a request's lifecycle. We'll contrive an example using a Blog application.

<script src="https://gist.github.com/3960397.js?file=routes.rb"></script>

Let's add a `PostsController`. We want to use [strong_parameters](http://github.com/rails/strong_parameters) to prevent any unauthorized mass-assignment and add an authorization check to ensure the current user's access to create posts on the current blog.

<script src="https://gist.github.com/3960397.js?file=controller.rb"></script>

The `protected` keyword denotes methods that are called by ActionController and the `private` keyword is used for methods that we call in the controller itself to complete our work. Simliar to the previous example above, there's no implementation reason that we're using protected methods here aside from calling attention to the fact that the methods marked as protected and private are interfaces aimed at different consumers: the external framework and the internal object respectively. It's a hint to future readers of the code that while these methods aren't part of the object's public API, there are users of the interface beyond the object itself.

### Summary

`protected` is an odd beast; it accomplishes much of what `private` does but with the addition of some nuanced complexity and the (arguable) benefit of being able to call methods on `self` explicitly. There's some conventions around what protected means but they seem to vary from project to project. I could find no project with any guidelines around method visibility. It was not apparent in most of the code I read that had used `protected` why the original author had chosen to use it.

I talked to several developers while writing this who committed code to widely used projects and had used `protected`. I received the same response from each: 1) I don't remember why I used `protected` there 2) I wouldn't use `protected` if I was writing that code again, (`private`|`public`) would have been better 3) I don't use `protected` at all today.

In searching ruby-core for conversations about protected methods, it's clear this feature even confuses core contributors. The `OpenStruct` example above was [discussed on the list](http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/1558) as a replacement of an `instance_eval`. The contributor who suggested it was [tentative making the change](http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/1559): "From my ruby life for now, here's the only place where protected method lives."

Protected method visibility could make sense to use in workaday code for the above cases. If you're going to use it, leave a paper trail in either the commit message or the RDoc documentation for the method explaining why.
