# TrailGuide

TrailGuide is a rails engine providing a framework for running user experiments and A/B tests in rails apps.

## Getting Started

### Requirements

Currently only rails 5.x is officially tested/supported, and trailguide requires redis to store experiment metadata and (optionally) participants.

`docker-compose` is a great way to run redis in development. Take a look at the `docker-compose.yml` in the root of this repo for an example.

In production I recommend configuring redis as a persistent datastore (rather than a cache), in order to avoid evicting experiment or participant keys unexpectedly.

### Installation

Add this line to your Gemfile:

```
gem 'trailguide'
```

Then run `bundle install`.

### Engine & Admin Routes

If you plan on using the included javascript client, or if you just want an API to interact with experiments in other ways, you can mount the engine in your route config:

```ruby
# /config/routes.rb

Rails.application.routes.draw do
  # ...

  mount TrailGuide::Engine => 'api/experiments'

  # ...
end
```

You can also mount the admin engine to manage and analyze your experiments via the built-in admin UI. You'll probably want to wrap this in some sort of authentication, though the details will vary between applications. If you're already mounting other admin engines (i.e. something like `sidekiq` or `flipper`), you should be able to apply the same technique to trailguide.

```ruby
# /config/routes.rb

Rails.application.routes.draw do
  # ...

  mount TrailGuide::Engine => 'api/experiments'

  # example auth route helper
  authenticate :user, lambda { |u| u.admin? } do
    mount TrailGuide::Admin::Engine => 'admin/trailguide'
  end

  # ...
end
```

### Quick Start

Create and configure an experiment:

```ruby
# config/experiments.rb

experiment :simple_ab do |config|
  config.summary = "This is a simple A/B test" # optional

  variant :a
  variant :b
end
```

Start your experiment either via the admin UI or from a rails console with `TrailGuide.catalog.find(:simple_ab).start!` to enable enrollment.

Then use it (in controller actions for this example):

```ruby
def show
  # enroll in the experiment and do something based on the assigned variant group
  case trailguide.choose(:simple_ab)
    when :a
      # perform logic for group "a"
    when :b
      # perform logic for group "b"
  end

  # ...
end

def update
  # mark this participant as having converted when they take a certain action
  trailguide.convert(:simple_ab)

  # ...
end
```

If you've mounted the admin engine, you can view your experiment's participants and conversions there.

## Configuration

The core engine and base experiment class have a number of configuration options available to customize behavior and hook into various pieces of functionality. The best way to configure trailguide is via a config initializer, and this gem configures it's own defaults the same way.

```ruby
# config/initializers/trailguide.rb

TrailGuide.configure do |config|
  config.redis = Redis.new(url: ENV['REDIS_URL'])
  # ...
end

TrailGuide::Experiment.configure do |config|
  config.algorithm = :weighted
  # ...
end
```

Take a look at [`config/initializers/trailguide.rb`](https://github.com/markrebec/trailguide/blob/master/config/initializers/trailguide.rb) in this repo for a full list of defaults and examples of the available configuration options.

### Configuring Experiments

Before you can start running experiments in your app you'll need to define and configure them. There are a few options for defining experiments - YAML files, a ruby DSL, or custom classes - and they all inherit the base `TrailGuide::Experiment.configuration` for defaults, which can be overridden per-experiment.

#### YAML

YAML files are an easy way to configure simple experiments. They can be put in `config/experiments.yml` or `config/experiments/**/*.yml`:

```yaml
# config/experiments.yml

simple_ab:
  variants:
    - 'option_a'
    - 'option_b'
```

```yaml
# config/experiments/search/widget.yml

search_widget:
  start_manually: false
  algorithm: 'distributed'
  variants:
    - 'original'
    - 'simple'
    - 'advanced'
```

#### Ruby DSL

The ruby DSL provides a more dynamic and flexible way to configure your experiments, and allows you to define custom behavior via callbacks and options. You can put these experiments in `config/experiments.rb` or `config/experiments/**/*.rb`:

```ruby
# config/experiments.rb

experiment :search_widget do |config|
  config.start_manually = false
  config.algorithm = :distributed

  # the first variant is your control by default, but you can declare any one as
  # the control like we do below
  variant :simple
  variant :original, control: true
  variant :advanced

  goal :interacted
  goal :searched

  on_choose do |experiment, variant, metadata|
    # ... send a track to some third party service ...
  end

  on_convert do |experiment, variant, goal, metadata|
    # ... send a track to some third party service ...
  end
end
```

#### Custom Classes

You can also take it a step further and define your own custom experiment classes, inheriting from `TrailGuide::Experiment`. This allows you to add or override all sorts of additional behavior on top of all the standard configuration provided by the DSL. In fact, the YAML and ruby DSL configs both use this to parse experiments into anonmymous classes extending `TrailGuide::Experiment`.

You can put these classes anywhere rails will autoload them (or require them yourself), but I recommend `app/experiments/**/*.rb`:

```ruby
# app/experiments/my_complex_experiment.rb

class MyComplexExperiment < TrailGuide::Experiment

  # all standard experiment config goes in the `configure` block
  configure do |config|
    config.reset_manually = true

    control :option_a
    variant :option_b
    variant :option_c
    variant :option_d

    on_start do |experiment|
      # ... do some custom stuff when the experiment is started ...
    end
  end

  # override the experiment `choose!` method, and maybe do some custom stuff
  # depending on custom options you pass in
  def choose!(**opts)
    if opts[:foo] == :bar
      return control
    else
      super(**opts)
    end
  end

  def foobar
    # ... you can define whatever other custom methods, mixins and behaviors ...
  end

end
```

You can also use inheritance to setup base experiments and inherit configuration:

```ruby
class ApplicationExperiment < TrailGuide::Experiment
  configure do |config|
    # ... config, variants, etc.
  end
  # ... custom behavior, etc.
end

class MyAppExperiment < ApplicationExperiment
  # inherits config from ApplicationExperiment
end

class MyDefaultExperiment < TrailGuide::Experiment
  # inherits from configured trailguide defaults
end
```

You can even use these in your DSL-defined experiments by specifying a `class:` argument:

```ruby
# config/experiments.rb

experiment :my_inheriting_experiment, class: ApplicationExperiment do |config|
  # ...
end
```

### Participant Adapters

While all experiment configuration, metadata and metrics are stored in redis, there are various adapters available for participants to control where individual assignments are stored for each user. These adapters are configurable and extensible, so you can customize them or even create your own by following a simple interface.

The following participant adapters are included with trailguide:

* cookie (default) - stores participant assignments in a cookie in their browser
* session - stores participant assignments in a hash in their rails session
* redis - stores participant assignments in redis, under a configurable key identifier (usually `current_user.id` or a cookie storing some sort of tracking/visitor ID for logged out users)
* anonymous - temporary storage, in a local hash, that only exists for as long as you have a handle on the participant object (usually a last resort fallback)
* multi - attempts to use the "best" available adapter based on the current context
* unity - uses `TrailGuide::Unity` to attempt to unify visitor/user sessions based on your configuration

#### Cookie

This is the default adapter, which stores participation details in a cookie in the user's browser. If you want to configure the cookie name, path or expiration, you can do so directly in your initializer:

```ruby
TrailGuide.configure do |config|
  # config.adapter = :cookie
  config.adapter = TrailGuide::Adapters::Participants::Cookie.configure do |config|
    config.cookie = :trailguide
    config.path = '/'
    config.expiration = 1.year.to_i
  end
end
```

#### Session

The session adapter will store participation in a hash under a configurable key within the user's rails session.

```ruby
TrailGuide.configure do |config|
  # use the symbol shortcut for defaults
  config.adapter = :session

  # or configure it
  config.adapter = TrailGuide::Adapters::Participants::Session.configure do |config|
    config.key = :trailguide
  end
end
```

#### Redis

The redis adapter stores participation details in a configurable redis key, which makes it great for ensuring consistency across visits and even devices. While the cookie and session adapters are restricted to a single browser or even a single browsing session, the redis adapter is more persistent and controllable, with the tradeoff being that you'll need to be able to identify your users in some way (i.e. `current_user.id`).

```ruby
TrailGuide.configure do |config|
  # use the symbol shortcut for defaults
  config.adapter = :redis

  # or configure it
  config.adapter = TrailGuide::Adapters::Participants::Redis.configure do |config|
    config.namespace = :participants
    config.expiration = nil
    config.lookup = -> (context) { context.current_user.id } # context is wherever you're calling trailguide, usually a controller or view
  end
end
```

#### Anonymous

The anonymous adapter is a simple, ephemeral ruby hash that only exists for as long as you have a reference to that local participant object. It's generally only used as a last resort when there's no way to identify a participant who is enrolling in an experiment, because there's no way to get a new reference later on (for example to track conversion).

#### Multi

The multi adapter will attempt to use the "best" available adapter, depending on the context from which trailguide is being invoked (controller, view, background job, etc.). It comes with a default configuration that prefers to use redis if a `current_user` is available, otherwise tries to use cookies if possible, then session if possible, falling back to anonymous as a last resort.

You can use the multi adapter to wrap any adapter selection logic you like, the only requirement is that you return one of the other adapters:

```ruby
TrailGuide.configure do |config|
  # use the symbol shortcut for defaults
  config.adapter = :multi

  # or configure it
  config.adapter = TrailGuide::Adapters::Participants::Multi.configure do |config|
    # should be a proc that returns another adapter to be used
    config.adapter = -> (context) do
      if context.respond_to?(:current_user, true) && context.send(:current_user).present?
        TrailGuide::Adapters::Participants::Redis
      elsif context.respond_to?(:cookies, true)
        TrailGuide::Adapters::Participants::Cookie
      elsif context.respond_to?(:session, true)
        TrailGuide::Adapters::Participants::Session
      else
        TrailGuide::Adapters::Participants::Anonymous
      end
    end
  end
end
```

#### Unity

The unity adapter is a wrapper around `TrailGuide::Unity`, which attempts to unify user/visitor sessions, then selects and configures the appropriate adapter. It looks for an available, configurable "user ID" (`current_user`) and "visitor ID" (from a cookie) and configures the redis adapter appropriately. If there is no identifying information available it falls back to the anonymous adapter.

You can configure the visitor cookie and the user id attribute, as well as the adapters to be used in each case:

```ruby
TrailGuide.configure do |config|
  config.adapter = TrailGuide::Adapters::Participants::Unity.configure do |config|
    # setup the visitor ID cookie and user ID attribute
    config.visitor_cookie = :visitor_id # uses a cookie called visitor_id, must be set and managed by you separately
    config.user_id_key = :uuid # uses current_user.uuid, defaults to current_user.id

    # uses redis adapter for identified users
    config.user_adapter = TrailGuide::Adapters::Participants::Redis.configure do |config|
      config.namespace = 'unity:users'
      config.lookup = -> (user_id) { user_id }
      config.expiration = 1.year.seconds
    end

    # uses redis adapter for identified visitors
    config.visitor_adapter = TrailGuide::Adapters::Participants::Redis.configure do |config|
      config.namespace = 'unity:visitors'
      config.lookup = -> (visitor_id) { visitor_id }
      config.expiration = 1.year.seconds
    end

    # uses anonymous adapter for unidentified
    config.anonymous_adapter = TrailGuide::Adapters::Participants::Anonymous
  end
end
```

See the unity documentation for more info about unifying sessions.

### Algorithms

## Usage

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
