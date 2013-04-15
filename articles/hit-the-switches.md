## [jpignata/switches](https://github.com/jpignata/switches)

Ruby developers love continuous deployment. Don't believe me? Just find one and
ask them, "say, how often do you deploy a day?" They won't answer, though,
since they'll be too busy kicking off another deploy from their phone. The
trend is a great thing -- many teams measure the time between features and
fixes being completed and being live in front of real users in minutes or hours
instead of days or weeks.

Flickr talked extensively about [using feature
flippers](http://code.flickr.net/2009/12/02/flipping-out/) to eliminate long
running branches while still ensuring the deploy pipeline isn't blocked by work
in progress. Using feature flags, Flickr continued to deploy multiple times a
day while all work was continuously integrated in the same main branch that was
being continuously deployed.

In the intervening years we've gotten more sophisticated in our approach to
feature flags. We gate not just on the running code's environment but also down
to request-specific parameters such as the current user. In our Ruby projects,
using tools like [rollout](https://github.com/jamesgolick/rollout) or
[flipper](https://github.com/jnunemaker/flipper) we can turn a feature on to a
specific set of users or to some arbitrary percentage of users. Using these
tactics we can conditionally expose a feature to a small subset of users. This
can allow us to both get feedback on the feature and see it perform under
real-world conditions before going fully live. We can iterate and tune and
optimize our feature before lifting the curtain to our full population of
users.

Since we often have many application server instances running, these projects
will use a backend to coordinate the sharing of feature switches state and each
feature switch will result in some kind of query.  We read this data far more
often than we write this data so it feels like we should be aggressively
caching on our application servers. This introduces a trade-off: if we cache
aggressively and expire this cache after some time-to-live period, it's
possible the nodes won't agree on the state of a feature flag. This could cause
a user to see a feature appear and disappear between requests. Ideally the
application server nodes would be lazy in fetching new configuration data, but
if we decide to make a change it should take effect globally and as close to
immediately as possible.

I've published an experimental gem to manage feature switches in a Ruby
application. [Switches](https://github.com/jpignata/switches) works much the
same as existing projects but has the explicit design goal of ensuring the
least possible chatter between application server instances and the shared
backend. Instead of querying Redis or Mongo for each feature switch we add to
a given execution path, switches uses in-memory structures for storing this
data. Whenever this data is changed a change notification is delivered via
a pub/sub bus which triggers a refresh of its in-memory cache.

```ruby
# config/initializers/switches.rb
$switches = Switches do |config|
  config.backend = "redis://localhost:6379/0"
end

# app/controllers/posts_controller.rb
def index
  if $switches.feature(:websockets_chat).on?(current_user.id)
    @chat = ChatConnection.new(current_user)
 end

  if $switches.feature(:redesign).on?(current_user.id)
    render :index, layout: :redesign
  end
end

# In an IRB session; once ran a change notification will be broadcast
# to all listening nodes. Each node will then refresh its data for the
# "redesign" feature.

# On for 10% of users
$switches.feature(:websockets_chat).on(10)

# Add user IDs 5, 454, and 2021 to the power_users cohort
$switches.cohort(:power_users).add(5).add(454).add(2021)

# On for users in the power_users cohort
$switches.feature(:redesign).add(:power_users)
```

Switches uses either Redis or Postgres for storage and coordination. I'm hoping
to experiment with other backends soon
([Zookeeper](http://zookeeper.apache.org/) and [CouchDB's _change
feed](http://guide.couchdb.org/draft/notifications.html) both seem promising.)

I've not yet gotten this gem production-ready yet, but will continue working on
it over the next few weeks. If you're using a feature switch library and are
concerned about network chatter get in touch.
