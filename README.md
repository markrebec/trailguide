# TrailGuide

TrailGuide is a rails engine providing a framework for running user experiments and A/B tests in rails apps.

## Acknowledgements

This gem is heavily inspired by the [split gem](https://github.com/splitrb/split). I've used split many times in the past and am a fan. It's an excellent alternative to trailguide, and really your best bet if you're not using rails. If you've used split in the past, you'll probably see a lot of familiar concepts and similarly named configuration variables. Parts of this project are even loosely modeled after some of the more brilliant patterns in split - like the user adapters for persistence.

### Motivation

While working on a project to more deeply integrate custom experiments into a rails app, I found myself digging into the split internals. Split has been the go-to for A/B testing in ruby for a while. It's grown and evolved over the years, but as I explored the codebase and the github repo it became clear I wouldn't be able to do a lot of what was required for the project without overriding much of the existing behavior. Additionally, there are some differing opinions and approaches taken here that directly conflicted with split's defaults - for example the way "combined experiments" work, or how split allows defining and running experiments directly inline, while trailguide requires configuration.

After spending so much time with split and struggling with some of the implementation, I saw what I thought was a clear model and path forward for a more customizable and extensible rails-focused framework.

## Getting Started

### Requirements

Currently only rails 5.x is officially supported, and trailguide requires redis as a datastore for experiment metadata.

`docker-compose` is a great way to run redis in development. Take a look at the `docker-compose.yml` in the root of this repo for an example.

### Installation

Add this line to your Gemfile:

```
gem 'trailguide'
```

Then run `bundle install`.

## Configuration

The core engine and base experiment class have a number of configuration flags available to customize behavior and hook into various pieces of functionality. The preferred way to configure trailguide is via a config initializer, and the gem sets it's config defaults via it's own initializer.

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

Take a look at `config/initializers/trailguide.rb` in this for a full list of defaults and examples of available configuration.

### Defining Experiments

Before you can start running experiments in your app, you'll need to define and configure them. There are a few options for defining experiments - YAML files, a ruby DSL, or custom classes - and they all inherit the base `TrailGuide::Experiment.configuration` for defaults, which can be overridden per-experiment.

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
  start_manually: true
  algorithm: 'distributed'
  variants:
    - 'basic'
    - 'simple'
    - 'advanced'
```

#### Ruby DSL

The ruby DSL provides a more dynamic and flexible way to configure your experiments, and allows you to define custom behavior via callbacks and options. You can put these experiments in `config/experiments.rb` or `config/experiments/**/*.rb`:

```ruby
# config/experiments.rb

experiment :search_widget do |config|
  config.start_manually = true
  config.algorithm = :distributed
  config.allow_multiple_goals = true

  variant :basic
  variant :simple, control: true
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

## Usage

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
