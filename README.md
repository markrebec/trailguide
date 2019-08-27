# TrailGuide

[![Build Status](https://travis-ci.org/markrebec/trailguide.svg?branch=master)](https://travis-ci.org/markrebec/trailguide)
[![Coverage Status](https://coveralls.io/repos/github/markrebec/trailguide/badge.svg?branch=master)](https://coveralls.io/github/markrebec/trailguide?branch=master)

TrailGuide is a framework to enable running A/B tests, user experiments and content experiments in rails applications. It is backed by redis making it extremely fast, and provides configuration options allowing for flexible, robust experiments and behavior.

## Features

* **Fast** - TrailGuide makes efficient use of redis, storing a few simple metadata key/value pairs for experiments. Combined with ruby class-based experiments, efficient built-in algorithms, and participant adapters, enrolling in an experiment takes only a few milliseconds.
* **Flexible** - Core behavior, participant assignment and individual experiments are highly configurable and can be used in almost any context, with options to control everything from variant options and metrics, to enrollment, conversion behavior, request filtering and more.
* **Hooks and Callbacks** - There are a number of hooks available to handle things like failover cases or filtering participation/conversion, as well as callbacks to enable logging/tracking/whatever when lifecycle or enrollment events occur. (TODO wiki link to callbacks page)
* **Algorithms** - TrailGuide comes with a few built-in algorithms for common use cases, or you can create your own algorithm class by following a simple interface. (TODO wiki link to algorithm page)
* **Conversion Goals** - Define simple conversion goals or more complex funnels, and track how your variants are performing against those goals.
* **Experiment Groups** - If you're running a large number of experiments, it can be helpful to organize them into logical groups, which can also be referenced when converting multiple experiments against shared conversion goals.
* **Combined Experiments** - Combined experiments are a way to share configuration (variants, goals, groups, flags, etc.), lifecycle (running, paused, etc.) and participation between two or more experiments, while tracking conversion and managing winning variants individually.
* **Analysis** - Once your experiment is complete TrailGuide can provide you with results using the built-in analyzers, either z-score (default) or bayesian. (TODO wiki link to analysis)

## Getting Started

### Requirements

Currently only rails 5.x is officially tested/supported, and TrailGuide requires redis to store experiment metadata and (optionally) participants' assignment.

`docker-compose` is a great way to run redis in development. Take a look at the [`docker-compose.yml` in the root of this repo](https://github.com/markrebec/trailguide/blob/master/docker-compose.yml) for an example.

In production I recommend configuring redis as a persistent datastore (rather than a cache), in order to avoid evicting experiment or participant keys unexpectedly. You can [read more about key eviction and policies here](https://redis.io/topics/lru-cache).

### Installation

Add this line to your Gemfile:

```
gem 'trailguide'
```

Then run `bundle install`.

### Configuration

By default the redis client will attempt to connect to redis on `localhost:6379`, which is usually fine for development/testing but won't work in other environments.

Configure redis by either setting a `REDIS_URL` environment variable:

```
REDIS_URL=redis://127.0.0.1:6379
```

Or you can create a config initializer, which is useful if you plan on configuring TrailGuide further:

```ruby
# config/initializers/trailguide.rb

TrailGuide.configure do |config|
  config.redis = 'redis://127.0.0.1:6379'
  # or you can also use your own client
  # config.redis = Redis.new(url: 'redis://127.0.0.1:6379')
end
```

### Quick Start

Create and configure an experiment:

```ruby
# config/experiments.rb

experiment :simple_ab do |config|
  config.summary = "This is a simple A/B test" # optional

  variant :alpha # the first variant is always the "control" group unless declared otherwise
  variant :bravo
end
```

Then use it in controller:

```ruby
# app/controllers/things_controller.rb

def show
  # enroll in the experiment and do something based on the assigned variant group
  case trailguide(:simple_ab)
    when :alpha
      # perform your logic for group "alpha"
    when :bravo
      # perform your logic for group "bravo"
  end

  # ...
end

def update
  # mark this participant as having converted when they take a certain action
  trailguide.convert(:simple_ab)

  # ...
end
```

Or a view:

```erb
# app/views/things/show.html.erb

<% if trailguide(:simple_ab) == :alpha %>
  <div>...render alpha...</div>
<% else %>
  <div>...render bravo...</div>
<% end %>
```

TODO link to examples of `run`, `render`, etc.

Until your experiment is started, only the "control" group (in this case `:alpha`) will be served to visitors. Start your experiment either via the admin UI or from a rails console with `TrailGuide.catalog.find(:simple_ab).start!` to begin enrolling participants and serving variants.

### API / JavaScript Client

If you plan on using the included javascript client, or if you just want an API to interact with experiments in other ways, you can mount the engine in your route config:

```ruby
# config/routes.rb

Rails.application.routes.draw do

  mount TrailGuide::Engine => 'api/experiments'

  # ...
end
```

### Admin UI

You can also mount the admin engine to manage and analyze your experiments via the built-in admin UI. You'll probably want to wrap this in some sort of authentication, although the details will vary between applications. If you're already mounting other admin engines (i.e. something like `sidekiq` or `flipper`), you should be able to apply the same technique to trailguide.

```ruby
# config/routes.rb

Rails.application.routes.draw do

  mount TrailGuide::Engine => 'api/experiments'

  # example auth route helper
  authenticate :user, lambda { |u| u.admin? } do
    mount TrailGuide::Admin::Engine => 'admin/trailguide'
  end

  # ...
end
```

## Configuration

The core engine and base experiment class have a number of configuration options available to customize behavior and hook into various pieces of functionality with callbacks. The best way to configure trailguide is via a config initializer, and this gem configures it's own defaults the same way.

```ruby
# config/initializers/trailguide.rb

TrailGuide.configure do |config|
  config.redis = Redis.new(url: ENV['REDIS_URL'])
  # ...
end

TrailGuide::Experiment.configure do |config|
  # all experiments inherit from the top-level experiment class,
  # which allows you to provide global experiment configuration
  # here, and override custom behavior on a per-experiment basis
  config.algorithm = :weighted
  # ...
end
```

Take a look at [`the config initializers in this repo`](https://github.com/markrebec/trailguide/blob/master/config/initializers) for a full list of defaults and examples of the available configuration options.

### Configuring Experiments

Before you can start running experiments in your app you'll need to define and configure them. There are a few options for defining experiments - YAML files, a ruby DSL, or custom classes - and they all inherit the base `TrailGuide::Experiment.configuration` for defaults, which can be overridden per-experiment.

#### Experiments Paths

By default, TrailGuide will look for experiment configs in `config/experiments.*` and `config/experiments/**/*`, and will load custom experiment classes from `app/experiments/**/*`. You can override this behavior with the `TrailGuide.configuration.paths` object in your config initializer.

```ruby
# config/initializers/trailguide.rb

TrailGuide.configure do |config|
  # you can append a single file or a glob pattern onto the experiment config loadpaths
  config.paths.configs << 'foo/bar/experiments/**/*'

  # or you can explicitly override the values with your own
  config.paths.configs = ['foo/bar/baz.rb', 'other/path/**/*']

  # you can also append or override the path(s) from which custom experiment classes are loaded
  config.paths.classes = ['lib/experiments/**/*']
end

```

#### YAML

YAML files are an easy way to configure simple experiments. They will be loaded based on your path configurations above, and by default can be put in `config/experiments.yml` or `config/experiments/**/*.yml`:

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

The ruby DSL provides a more dynamic and robust way to configure your experiments, allowing you to define custom behavior via callbacks and other options. Like YAML experiments, they're loaded based on your path configurations, and by default You can put these experiments in `config/experiments.rb` or `config/experiments/**/*.rb`:

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

You can also take it a step further and define your own custom experiment classes, inheriting from `TrailGuide::Experiment`. This allows you to add or override all sorts of additional behavior on top of all the standard configuration provided by the DSL. In fact, the YAML and ruby DSL configs both use this to parse experiments into anonmymous classes inheriting from `TrailGuide::Experiment`.

You can put these classes anywhere rails will autoload them (i.e. `app/whatever`), or you can put them somewhere like `lib/experiments` and require them yourself, but TrailGuide will also attempt to load them for you based on your path configurations, which by default looks in `app/experiments/**/*.rb`:

```ruby
# app/experiments/my_complex_experiment.rb

class MyComplexExperiment < TrailGuide::Experiment
  # if you want to actually use this class as an experiment (like we do in this
  # example), you must call `register!` in order to register it in the catalog.
  #
  # if you want to use your class as a base class, so other experiments can
  # inherit from it, you should _not_ call `register!`
  register!

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
  # you can configure this experiment just like any other DSL-based experiment,
  # the only difference is that the resulting anonymous class will inherit from
  # ApplicationExperiment rather than directly from TrailGuide::Experiment

  # ...
end
```

## Usage

### Helpers

The `TrailGuide::Helper` module is available to be mixed into just about any context, and provides an easy way to interact with TrailGuide experiments. These helpers are mixed into controllers and views as helper methods by default, but you can disable this behavior by setting the `config.include_helpers` option to `false` if you'd rather explicitly include it where you want to use it.

When mixed in, the `trailguide` method provides a reference to the helper proxy, which in turn provides a few methods to interact with your experiments.

```ruby
# enroll in an experiment or reuse previous assignment
trailguide.choose(:experiment_name)
trailguide.choose!(:experiment_name)

# chooses, then automatically calls a method within the current context based on
# the selected variant
trailguide.run(:experiment_name)
trailguide.run!(:experiment_name)

# choose, then render a template or partial within the current context based on
# the selected variant
trailguide.render(:experiment_name)
trailguide.render!(:experiment_name)

# tracks a conversion only if participating, for the participant's currently assigned variant
trailguide.convert(:experiment_name)
trailguide.convert!(:experiment_name)
```

As a general rule of thumb, the bang (`!`) methods will loudly raise exceptions on any failures, while the non-bang methods will log errors and do their best to gracefully continue.

#### Enrollment

The `choose` method will either enroll a participant into an experiment for the first time or return their previously assigned variant if they've already been enrolled. It can accept an optional block to execute, and returns a `TrailGuide::Variant` object, *which can be compared directly to strings or symbols* or access it's properties directly (i.e. `variant.metadata[:foo]`).

```ruby
class MyController < ApplicationController
  def index
    # choose inline
    variant = trailguide.choose(:experiment_name) # TrailGuide::Variant instance
    if variant == 'variant_one'
      # ...
    elsif variant == 'variant_two'
      # ...
    end

    # use directly in a case or other comparison
    case trailguide.choose(:experiment_name)
      when :variant_one
        # ...
      when :variant_two
        # ...
    end


    # pass in a block
    trailguide.choose(:experiment_name) do |variant, metadata|
      # ... do something based on the assigned variant
    end


    # also accepts additional metadata which can be used in custom algorithms and
    # passed to blocks along with any configured variant metadata
    trailguide.choose(:experiment_name, metadata: {foo: :bar}) do |variant, metadata|
      # ...
    end
  end
end
```

You can also call `trailguide.choose` from your view templates and partials, though you probably want to keep any complex logic in your controllers (or maybe helpers). This would print out the variant name into an `h1`:

```erb
<% variant = trailguide.choose(:experiment_name) %>
<h1><%= variant.name %></h1>
```

#### Running Methods

If you prefer, you can encapsulate your logic into methods for each variant and ask trailguide to execute the appropriate one for you automatically within the given context.

```ruby
class MyController < ApplicationController
  def index
    # this would call one of the methods below depending on assignment
    trailguide.run(:experiment_name)
  end

  private

  def variant_one(**metadata)
    # ... do whatever, maybe use these almost like a `before_filter` to setup instance vars
  end

  def variant_two(**metadata)
    # ...
  end
end
```

By default the above will attempt to call methods with a name matching your assigned variant name, but you can configure custom methods via the `methods:` keyword argument.

```ruby
class MyController < ApplicationController
  def index
    # this would call one of the methods below depending on assignment
    trailguide.run(:experiment_name,
      methods: {
        variant_one: :my_first_method,
        variant_two: :my_second_method
      },
      metadata: {
        # you can also optionally pass custom metadata through
      })
  end

  private

  def my_first_method(**metadata)
    # ... do whatever - you could use these almost like a `before_filter` to setup different instance vars depending on assignment
  end

  def my_second_method(**metadata)
    # ...
  end
end
```

You **can** use `trailguide.run` in your views, but the methods you're calling must be available in that context. This usually means defining them as helper methods, either in your controller via `helper_method` or in a helpers module.

#### Rendering

Many experiments include some sort of UI component, and trailguide provides a handy shortcut to automatically render different templates/partials when that pattern suits your needs. The `trailguide.render` method can be used in controllers to render templates or in views to render partials, and uses rails' underlying render logic for each context.

```ruby
# config/experiments/homepage_ab.rb
experiment :homepage_ab do |config|
  variant :old
  variant :new
end

# app/controllers/homepage_controller.rb
class HomepageController < ApplicationController
  def index
    trailguide.render(:homepage_experiment)
  end
end

# this would render one of these templates within the layout (instead of homepage/index.html.erb)
# app/views/homepage/homepage_ab/old.html.erb
# app/views/homepage/homepage_ab/new.html.erb
```

You can also use render in a view to render partials instead of templates.

```ruby
# config/experiments/homepage_hero.rb
experiment :homepage_hero do |config|
  variant :old
  variant :new
end

# app/controllers/homepage_controller.rb
class HomepageController < ApplicationController
  def index
  end
end
```

```erb
<!-- app/views/homepage/index.html.erb -->
<%= trailguide.render(:homepage_hero) %>

<!-- this would render one of these partials -->
<!-- app/views/homepage/homepage_hero/_old.html.erb -->
<!-- app/views/homepage/homepage_hero/_new.html.erb -->
```

By default the render method looks for templates or partials matching the assigned experiment and variant within the current render context path. For templates (in controllers) this means something like `app/views/your_controller/experiment_name/variant_name.*`, and for partials (in views) something like `app/views/your_controller/experiment_name/_variant_name.*` (note the underscore for partials, following rails' conventions).

You can override the prefix or the full paths to the individual templates via the `prefix:` and `templates:` keyword args respectively.

```ruby
# looks for variant templates in app/views/foo/bar/experiment_name/*
trailguide.render(:experiment_name, prefix: 'foo/bar')

# specify the path for each variant's template (relative to rails view path)
trailguide.render(:experiment_name, templates: {
  variant_one: 'foo/bar/custom',
  variant_two: 'other/custom/template'
})

# renders one of these
# app/views/foo/bar/custom.html.erb
# app/views/other/custom/template.html.erb
```

#### Conversion

In order to analyze performance and potentially select a winning variant, you'll want to track a conversion metric relevant to your experiment. This might mean clicking a button, creating an account, adding something to a shopping cart, completing an order, or some other interaction performed by the user. You can convert a participant from pretty much any context with `trailguide.convert`.

```ruby
# converts the participant in their assigned variant, or does nothing if they haven't been enrolled in the experiment
trailguide.convert(:experiment_name)

# requires a goal for experiments configured with multiple goals
trailguide.convert(:experiment_name, :goal_name)
```

### Service Objects & Background Jobs

The way you use trailguide outside of a request context will mostly depend on the participant adapter being used. To get started, you'll need to include the `TrailGuide::Helper` module into whatever class or context you're working with.

The `:cookie` and `:session` adapters **will not work** in a background context, but the default `:redis`, `:multi` and `:unity` adapters will work if provided with a `trailguide_user`. This assumes that the `trailguide_user` matches the same user elsewhere in your request contexts (like in your controllers and views), which is commonly `current_user`. The default configurations for these supported adapters all look for either a `trailguide_user` or a `current_user` so they should work in most contexts.

A simple example might be sending a welcome email in a background job with a variable discount amount depending on what variant the user was enrolled into during signup.

```ruby
# config/experiments.rb
experiment :welcome_discount do |config|
  variant :10
  variant :15
end

# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def create
    # ... signup the user
    amount = trailguide.choose(:welcome_discount)
    flash[:info] = "Check your email for a $#{amount} discount!"
    SendWelcomeEmailJob.perform_later(current_user)
  end
end

# app/jobs/send_welcome_email_job.rb
class SendWelcomeEmailJob < ApplicationJob
  include TrailGuide::Helper

  def perform(user)
    # set this to an instance var before choosing so it's available in the supported trailguide_user method
    @user = user

    amount = trailguide.choose(:welcome_discount)
    UserMailer.welcome_email(@user, amount)
  end

  # using one of the supported adapters will automatically call this method if it exists
  def trailguide_user
    @user
  end
end
```

If you're using a custom adapter, you'll need to make sure that your adapter is able to infer the participant from your context.

## JavaScript Client

There is a simple javascript client available that mimics the ruby usage as closely as possible, and is ready to be used with the rails asset pipeline. This client uses axios to hit the API, and requires that you mount it in your routes.

```javascript
// require the trailguide client in your application.js or wherever makes sense
//= require trailguide

// create a client instance
// make sure to pass in the route path where you've mounted the trailguide engine
var client = TrailGuide.client('/api/experiments');

// enroll in an experiment
client.choose('experiment_name');

// convert for an experiment with an optional goal
client.convert('experiment_name', 'optional_goal');

// return the participant's active experiments and their assigned variant group
client.active();
```

## Conversion Goals

You can configure experiment goals if a single experiment requires multiple conversion goals, or if you just want to define a single named goal to be more explicit.

```ruby
experiment :button_color do |config|
  variant :red
  variant :green
  variant :blue

  goal :signed_up
  goal :checked_out

  # if this is false (default), once a participant converts to one of the defined goals, they will not be able to convert to any of the others unless the experiment is reset
  # if this is true, a single participant may convert to more than one goal, but only once each, which allows for simple conversion funnels
  config.allow_multiple_goals = true
end
```

When you define one or more named goals for an experiment, you must pass one of the defined goals when converting.

```ruby
trailguide.convert(:button_color, :signed_up)
```

## Conversion Groups

If you have multiple experiments that share a relevant conversion point, you can configure them with a shared group. This allows you to reference and convert multiple experiments at once using that shared group, and only experiments in which participants have been enrolled will be converted.

Shared groups can only be used for conversion, not for enrollment, since experiments don't share assignments.

For example if you have multiple experiments where performing a search is considered to be a successful conversion, you can configure them all with the same shared group then use that group in your calls to `trailguide.convert`.

```ruby
experiment :first_search_experiment do |config|
  config.group = :perform_search

  variant :a
  variant :b
end

experiment :second_search_experiment do |config|
  config.groups = [:perform_search, :other_group]

  variant :one
  variant :two
  variant :three
end

experiment :third_search_experiment do |config|
  group :other_group
  group :perform_search
  groups :yet_another_group, :one_more

  variant :red
  variant :blue
end

class SearchController < ApplicationController
  def search
    trailguide.convert(:perform_search)
    # ...
  end
end
```

### Orphaned Groups

Sometimes in the real world, you might accidentally remove all the experiments that were sharing a given group, but miss one of the conversion calls that used one of those groups. Maybe you forgot to search through your code for references to the group, or maybe you just didn't know you were removing the last experiment in that group. Ideally you'd be testing your code thoroughly, and you'd catch the problem before hitting production, but trailguide has a built-in safe guard just in case.

Instead of raising a `TrailGuide::NoExperimentsError` when no experiments match your arguments like the `trailguide.choose` and related methods do, the `trailguide.convert` method will log a warning and return `false` as if no conversion happened.

After a failed conversion for an orphaned group, the next time you visit the trailguide admin dashboard you'll see an alert with the details of any logged orphaned groups. If you wish to ignore orphaned groups entirely, perhaps so you can leave conversion calls in your application while you regularly rotate experiments into and out of those groups, you can set the `TrailGuide.configuration.ignore_orphaned_groups = true` config option in your initializer.

### Groups with Goals

Since grouping is primarily useful when converting, and experiments with defined goals require a goal to be passed in when converting, **any experiments that are sharing a group must define the same goals in order to be converted together.** Not all goals need to overlap, but you will only be able to convert goals that are shared when referencing a group.

If you're grouping your experiments, that probably means you have multiple experiments that are all being used in the same area of your app and therefore are likely sharing the same (or similar) conversion goals. You can assign your groups and goals the same names to make converting easier by referencing a single key:

```ruby
experiment :first_search_experiment do |config|
  variant :alpha
  variant :bravo

  groups :click_search, :click_banner, :search_experiments
  goals  :click_search, :click_banner, :custom_goal
end

experiment :second_search_experiment do |config|
  variant :one
  variant :two
  variant :three

  groups :click_search, :click_banner, :search_experiments
  goals  :click_search, :click_banner, :some_other_goal
end

experiment :third_search_experiment do |config|
  variant :red
  variant :blue

  groups :click_search, :click_banner, :search_experiments
  goals  :click_search, :click_banner
end

# then to convert all three experiments for the click_search group, against the
# click_search goal
trailguide.convert(:click_search)

# the above is the equivalent of calling them by a shared group name (in this example
# the :search_experiments group) and the conversion goal name
trailguide.convert(:search_experiments, :click_search)

# or the equivalent of converting each of the three experiments individually
# for that goal
trailguide.convert(:first_search_experiment, :click_search)
trailguide.convert(:second_search_experiment, :click_search)
trailguide.convert(:third_search_experiment, :click_search)

# and you can still convert the individual experiments with goals that are not
# shared by their group
trailguide.convert(:first_search_experiment, :custom_goal)
```

### Metrics

Metrics are a quick way to combine groups and goals and remove some of the boilerplate when sharing them between experiments. Using the `metrics` config, we can simplify the above examples a bit:

```ruby
experiment :first_search_experiment do |config|
  variant :alpha
  variant :bravo

  metrics :click_search, :click_banner  # this configures a group and a goal for each metric
  group   :search_experiments           # add another group (without a goal)
  goal    :custom_goal                  # add another goal (without a group)
end

experiment :second_search_experiment do |config|
  variant :one
  variant :two
  variant :three

  metrics :click_search, :click_banner  # this configures a group and a goal for each metric
  group   :search_experiments           # add another group (without a goal)
  goal    :some_other_goal              # add another goal (without a group)
end

experiment :third_search_experiment do |config|
  variant :red
  variant :blue

  metrics :click_search, :click_banner  # this configures a group and a goal for each metric
  group   :search_experiments           # add another group (without a goal)
end
```

## Combined Experiments

**TODO**

## Filtering Requests

**TODO**

## Admin UI

**TODO**

## API

**TODO**

## RSpec Helpers

**TODO**

## Contributing

**TODO**

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
