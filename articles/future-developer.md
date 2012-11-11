A successful software project is likely to pass between many developers in its
lifetime. You are one link in your project's chain of custody and every line
of code you commit to your project is an artifact you're leaving to be
discovered by Future Developer. Just as you've inherited the decisions of the
developers that came before you, other developers will inherit the decisions
you're making today. Onto them we bequeath our misunderstandings, our
shortcuts, our applications of half-understood patterns and technologies, our
inconsistencies, our inattention to detail, our procrastinations, our
quick-and-dirty changes, our hidden skeletons, our dirty laundry. More rarely,
they will be the beneficiaries of our discipline, deliberation, and preparation.

You are in the best position to empathize with and anticipate the needs of
Future Developer. Every good decision we make for our project will have ripple
effects on his or her productivity. Why is this important? As Bob Martin asks
in [Clean Code](http://www.amazon.com/Clean-Code-Handbook-Software-
Craftsmanship/dp/0132350882), "Have you ever been significantly impeded by bad
code? So then -- why did you write it?" The same strategies to improve the
conditions for future generations of teams working on your project will serve
your team well in the present. When you come back to some obscure corner of
the codebase that you cobbled together six months ago, you're likely to have
only a little more context than Future Developer will when he or she sees it
or the first time. The clues and polish you've left for other developers will
benefit your future self. Projects that are poorly maintained are draining to
contribute to and lead to team attrition. Investing in the quality and future
maintainability of the software you're creating is an investment in a happy,
productive workplace for the present and future.

I'm going to pick a few practices in no particular order that we can use to
setup Future Developer for success.

### 1. Be Consistent

As projects age and requirements become more complex, we tend to introduce new
patterns and designs to manage this complexity. It's hard to tell if a pattern
or approach is pulling its weight immediately. Most of the time the feedback
that proves or disproves its value comes when another developer has to make a
change to that area of the codebase. Sometimes these patterns grow into
conventions that we begin to reach for to solve problems.

There's immense benefit to that: conventions communicate intent. If we tend
to solve problems in the same sorts of ways in a codebase, Future Developer
can start to predict how pieces of the codebase work together reducing the
amount of time necessary to diagnose problems and implement changes.

Often what we leave behind is a hodgepodge of patterns and conventions which
never made it to universal acceptance across the team or have been ignored in
the codebase as old cruft. This happens for a variety of reasons: the
conventions introduced didn't work well enough to make it into other areas of
the codebase or maybe new developers didn't know there was a convention or
pattern for handling a given requirement.

Rails' opinions and conventions are powerful. They allow developers to join a
project and quickly be productive if they've had any exposure to projects that
have used the framework. Sometimes we muddy these conventions and dilute their
power. For example,  in Rails systems we sometimes see controllers built in
many different styles. Some are composed using a project like
`resource_controller`, others follow the standard Rails `resources` convention
while others are junk drawers of random actions. Another common anti-pattern
is having configuration data sprinkled and initialized all throughout your
system.

Don't have half a dozen different ways of configuring aspects of your system
and make it clear how a controller should be built in your system. Once you've
experimented for a while and have settled on an approach, take the time to go
back to previous work and refactor into the new pattern. This doesn't mean
that you should add arbitrary constraints. There's good reason, for example,
to have some configuration stored with the project and some stored in the
environment to aid in deployment, but there should be one common structure and
access pattern for using configuration data.

Add conventions to your README or selected documentation repository. This will
give Future Developer a head start on adding functionality to the system and
to in understanding how its components are constructed.

### 2. Prune Dead Code

Another common characteristic of systems that have existed for some time is
the collection of barnacles in the form of dead code. These components in your
project may have at one time been providing business value but they've been
deprecated and hidden from production for months. There's probably even a slew
of full-stack acceptance tests validating those parts of the system are
functioning and slowing down your test suite.

Sometimes we're reluctant to delete this code because we're not sure if the
feature will be resurrected. Your product manager, when asked, might say "no,
leave it, we may reuse that one day." This is a false dilemma -- carrying
around a slowly rotting section of code for possible future reuse assumes that
reusing those parts of the codebase involves no changes. If we're ignoring it
because it's not actually live, it's not likely to be something we can just
"turn on" without significant work. You're carrying around that old code like
around like a [boat
anchor](http://en.wikipedia.org/wiki/Boat_anchor_(computer_science\)), wasting
cycles maintaining it because there's a small chance you may possibly one day
need part of it. Maybe. You don't know, but you spent a lot of time building
it so rather than deleting it you allow the code to slowly rot in your repository.

What's even more costly is that the continued existence of this code is a
possible trap for Future Developer. It detracts attention from the components
of your system that are actually live and is a possible red herring when he or
she is trying to understand or troubleshoot some aspect of the system. In a
system down emergency, old, dead code is noise waiting to waste valuable time.
Keeping the amount of code present in your code repository synchronized to the
amount of code actually functioning in your live system will reduce overall
maintenance costs and allow Future Developer to more quickly understand your
entire system.

Delete code that isn't in use with abandon. It'll still be under source
control if you need to refer to it later. Don't fall onto the wrong side of
the fallacy that you might be able to "turn it back on again later." If it had
any value then why did you turn it off to begin with?

### 3. Leave a Coherent Paper Trail

Aside from code itself, some of the tools we use in support of writing code have
their own paper trails. For example, there are
[commonly accepted practices](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
about what constitutes good `git` commit message hygiene and yet projects continue
to accumulate commit histories like this contrived example:

```text
jp@oeuf:~/workspace/blog(master*)$ git log --oneline app/controllers/application_controller.rb
8ec7f99 fuck i dunno lol
ffa919a shut up, atom parser
a33e9fa fixing again
cecc9dc one more time
968a28f fixing
3e3aeb2 ws
1fc597e pagination
edea155 adding dumb feature
```

When Future Developer ends up inevitably using `git blame` to get context
about a given feature, leave him or her the details they need to understand
the churn in the files in question. Use `merge --squash`, `commit --amend`,
`rebase`, and friends to massage your commits into a coherent set before
integrating your topic branch. Reword your commits after you're done -- take a
moment to include anything that seems relevant and summarize. Proofread for
grammar and spelling; you're publishing something that somebody else will need
to read and understand. Do Future Developer a favor and ensure you're leaving behind
an intelligible paper trail that contains the right amount of detail.

```text
jp@oeuf:~/workspace/blog(master*)$ git log --oneline app/controllers/application_controller.rb
commit 8ec7f998fb74a80886ece47f0a51bd03b0460c7a
Author: John Pignata <john@pignata.com>
Date:   Sat Nov 3 14:11:12 2012 -0400

    Add Google Analytics helper

commit 968a28f366e959081307e65253118a65301466f2
Author: John Pignata <john@pignata.com>
Date:   Sat Nov 3 13:49:50 2012 -0400

    Correct ATOM feed validation issues

    Using the W3C Validator (http://validator.w3.org/appc/), a few trivial
    errors were reported:

    * <author> should have a <name> node within it and not text
    * Timestamps should be in ISO8601 format

    This change fixes these issues and improves the spec coverage for the XML
    document.

commit 3e3aeb27ea99ecd612c436814c5a2b0dab69c2c3
Author: John Pignata <john@pignata.com>
Date:   Sat Nov 3 13:46:24 2012 -0400

    Fixing whitespace

    We're no longer indenting methods after `private` or `protected` directives
    as a matter of style. This commit fixes whitespace in all remaining
    classes.

commit 1fc597e788442e8cc774c6d11e7ac5e77b6c6e14
Author: John Pignata <john@pignata.com>
Date:   Sat Nov 3 12:34:50 2012 -0400

    Implement Kaminari pagination

    Move from will_paginate to kaminari in all controllers. The
    motivation is to be able to paginate simple Array collections
    without the monkey patching that will_paginate uses.

    * Consolidate helpers
    * Clean up whitespace

commit edea15560595bab044143149a7d6e528e8ae65d2
Author: John Pignata <john@pignata.com>
Date:   Sat Nov 3 12:27:16 2012 -0400

    Add ATOM feed for RSS readers

    * Include Nokogiri in Gemfile for its builder
    * Add AtomFieldBuilder model
    * Add link to feed from index page
```

### 4. Polish Your Interfaces

Some Ruby developers eschew method visibility for the methods in their
objects. What's the point? Any method is really callable using `send` anyway.
Why bother putting shackles around some methods? Just add that internal method
to the pile and if Future Developer wants to use it he or she can! We're all
adults, amirite?

If every object in your system is just a junk drawer of methods, it becomes
very difficult for anyone (including you) to understand how each object was
intended to be used and what messages it's intended to receive. The design of
the public interface of an object should make it absolutely obvious how other
objects in the system can interact with it. When each object's role and the
interactions between the objects in your system are not obvious, it increases
the amount of time it takes to understand not only each object but the system
in toto.

Hide as much of a component's internals as possible to keep interface small
and focused. Put extra energy into making sure your objects' public interfaces
are obvious, well named, and consistent. This gives Future Developer clear
signals about how you intend each object to be used and will highlight how
each can be reused. Use explicit method visibility to communicate this intent
and to enforce the surface area of the object's public interface.

### 5. Leave Comments, Not Too Many, Mostly RDoc

As developers our feelings about code comments can be best described as
[ambivalent](https://www.google.com/search?q=site%3Ac2.com+comments). On one
hand comments are extremely helpful in assisting a reader in understanding how
a given piece of code works. On the other hand as nothing enforces their
correctness, code comments are lies waiting to be told to the future. When
asked developers will say they value documentation but often projects have
very little beyond a mostly-out-of-date README and maybe a graveyard wiki
somewhere. What's more, when working with open source libraries we'll often
expect thorough RDoc documentation, an up-to-date README, and good example
code and when not present we'll complain bitterly. Scumbag developer: doesn't
maintain documentation, expects it from others.

As we pay more attention to things like the
[Single Responsibility Principle](http://www.objectmentor.com/resources/articles/srp.pdf)
and use patterns to loosen the coupling between objects we start to see
systems composed of many small objects wired together at runtime. While this
makes systems more pliable and objects more reusable there's a trade-off:
understanding an object's place within the larger system may be less
obvious and as such take more effort.  You can use all of the usual
refactorings to eliminate pesky inline comments and make your object as
readable as possible but it still might baffle Future Developer as to how the
object fits into the system.

RDoc-style documentation can be found in many open source projects. When
you're using Google to figure out if `update_attribute` fires callbacks or not
or what the signature for `select_tag` is, you'll likely land on the extracted
RDoc for [Ruby on Rails](http://api.rubyonrails.org/). Writing similar
documentation as part of your project will give Future Developer more context
when he or she is trying to understand the role of an object in the larger
context of your system. Adding a short, declarative sentence to the top of a
class and/or method indicating what it does could have substantial value for
future readers of the code. That said, wthout a strong shared culture of
keeping these comments up to date they could have negative value and
mislead a future reader of the code. The only thing worse than no documentation
is incorrect documentation.

### 6. Write intention-revealing tests

One way we provide documentation to a project is through the tests we leave
behind. These tests not only describe what the behavior of a given component
is but it enforces that the documentation is not out of date as it's
executable. Tools like RSpec and `minitest/spec` assist us in generating this
by-product documentation by encrouaging prose within the defining block of the
example. Unfortunately we sometimes look past the English words we're typing in
our rush to get to the actual code part of the red-green-refactor cycle. The
result of neglecting the English descriptions is that it's possible our tests
are not properly reflecting our objects as well as we think they might be.

It's almost as bad as finding a project with no test suite is finding a project
whose test suite doesn't help us in understanding how the system works. Test code
is code that also needs to be maintained and as such they need to very clearly
assert why they exist to a future reader. I understand the object "should" do something,
but why should it?

In building spec-style tests you should keep the English language descriptions
you're writing front and center. One way to do this is to run RSpec with the
documentation format:

```text
jp@oeuf:~/workspace/rspec-core(master)$ be rspec --format documentation spec
...
an example
  declared pending with metadata
    uses the value assigned to :pending as the message
    sets the message to 'No reason given' if :pending => true
  with no block
    is listed as pending with 'Not yet implemented'
  with no args
    is listed as pending with the default message
```

Instead of a field of green dots the documentation format outputs the nested
descriptions, contexts, and example titles you've been typing. This allows you
to scan through to see if your tests reveal actually how the object is
intended to behave. We'd do well to focus on that while we're building components
with an emphasis on coherence. Use the refactor step of red-green-refactor to
actually make your tests a coherent narrative of why that object exists,
how it behaves, and why this behavior exists.

### Future Developer, Delighted

These are just a few of the ways we can optimize for change with the
reasonable assumption that somebody else will be charged with making those
changes. Think about the next sets of eyes that will be responsible for
building and operating your current project when you're working on it. We've
all felt pangs of guilt about the maintainability or quality of something
we've shipped. Instead of feeling sympathy for all of the challenges you've
left in the codebase, begin to tally all of the drinks Future Developer will
owe you for all of the tidy work you've left behind.

_Thanks to [Dave Yeu](http://foodforsamurai.com/) from whom I've co-opted (read: stolen) the term "future developer."_