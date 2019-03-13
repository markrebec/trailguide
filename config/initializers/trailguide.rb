# top-level trailguide rails engine configuration
#
TrailGuide.configure do |config|
  # url string or initialized Redis object
  config.redis = ENV['REDIS_URL']

  # globally disable trailguide - returns control everywhere
  config.disabled = false

  # whether or not to include TrailGuide::Helper into controller and view
  # contexts
  #
  # true      the helper module is automatically mixed-in to controllers/views
  # false     you'll need to include the helper module manually where you want
  config.include_helpers = true

  # request param for overriding/previewing variants - allows previewing
  # variants with request params
  # i.e. example.com/somepage/?experiment[my_experiment]=option_b
  config.override_parameter = :experiment

  # whether or not participants are allowed to enter variant groups in multiple
  # experiments
  #
  # true      participants are entered into any experiments they encounter
  #
  # false     as soon as a participant enters an experiment, they are prevented
  #           from entering any future experiments (they will only ever be in a
  #           single experiment)
  #
  # :control  participants can enter any number of experiments as long as they
  #           are in the control groups, but as soon as they enter a non-control
  #           variant in any experiment, they will be prevented from entering
  #           any future experiments (they may be in multiple experiments, but
  #           in the control group for all except potentially one)
  config.allow_multiple_experiments = false

  # the participant adapter for storing experiment sessions
  #
  # :redis      uses redis to persist user participation
  # :cookie     uses a cookie to persist user participation
  # :session    uses the rails session to persist user participation
  # :anonymous  does not persist, can only convert in the same script/request
  #             execution while holding onto a reference to the object
  # :multi      allows using multiple adapters based on logic you define - i.e.
  #             use :redis if :current_user is present or use :cookie if not
  # :unity      a custom adapter for unity that helps track experiments across
  #             logged in/out sessions and across devices
  config.adapter = :cookie

  # callback when your participant adapter fails to initialize, and trailguide
  # falls back to the anonymous adapter
  config.on_adapter_failover = -> (adapter, error) do
    Rails.logger.error("#{error.class.name}: #{error.message}")
  end

  # list of user agents used by the default request filter proc below when
  # provided, can be an array or a proc that returns an array
  #
  # if using a proc, make sure it returns an array:
  # -> { return [...] }
  #
  # config.filtered_user_agents = []

  # list of ip addresses used by the default request filter proc below when
  # provided, can be an array or a proc that returns an array
  #
  # if using a proc, make sure it returns an array:
  # -> { return [...] }
  #
  # config.filtered_ip_addresses = []

  # default request filter logic uses the configured filtered ip and user
  # agents above, all requests matching this filter will be excluded from being
  # entered into experiments - used to block bots, crawlers, scrapers, etc.
  config.request_filter = -> (context) do
    is_preview? ||
      is_filtered_user_agent? ||
      is_filtered_ip_address?
  end
end

# base experiment configuration
#
TrailGuide::Experiment.configure do |config|
  # the default algorithm to use for new experiments
  config.algorithm = :weighted

  # whether or not experiments must be started manually
  #
  # true    experiments must be started manually via the admin UI or console
  # false   experiments will start the first time they're encountered by a user
  config.start_manually = true

  # whether or not participants will be reset upon conversion
  #
  # true    participants will only be entered into the experiment once, and the
  #         variant group they belong to is sticky for the duration
  # false   participants will be reset upon conversion and be able to re-enter
  #         the experiment if they encounter it again
  config.reset_manually = true

  # whether or not to enter participants into a variant when using the override
  # parameter to preview variants
  #
  # true    using overrides to preview experiments will enter participants into
  #         that variant group
  # false   using overrides to preview experiments will not enter participants
  #         into the experment (won't persist their variant group)
  config.store_override = false

  # whether or not we track participants when using the override parameter to
  # preview variants
  #
  # true    using overrides to preview experiments will increment the
  #         participant count for the override variant
  # false   using overrides to preview experiments will not increment the
  #         participant count for the override variant
  config.track_override = false
  
  # whether or not to continue tracking conversions after a winner has been
  # selected in order to continue monitoring performance of the variant
  #
  # true    continues to track conversions after a winner has been selected (as
  #         long as the experiment is still running)
  # false   all conversion and participation tracking stops once a winner has
  #         been selected
  config.track_winner_conversions = false

  # whether or not to allow multiple conversions of the same goal, or default
  # conversion if no goals are defined
  #
  # true    tracks multiple participant conversions for the same goal as long
  #         as they haven't been reset (see config.reset_manually)
  # false   prevents tracking multiple conversions for a single participant
  config.allow_multiple_conversions = false

  # whether or not to allow participants to convert for multiple defined goals
  #
  # true    allows participants to convert more than one goal as long as they
  #         haven't been reset (see config.reset_manually)
  # false   prevents converting to multiple goals for a single participant
  config.allow_multiple_goals = false

  # whether or not to skip the request filtering for this experiment - can be
  # useful when defining content-based experiments with custom algorithms which
  # bucket participants strictly based on additional content metadata and you
  # want to expose those variants to crawlers and bots
  #
  # true    requests that would otherwise be filtered based on your
  #         TrailGuide.configuration.request_filter config will instead be
  #         allowed through to this experiment
  # false   default behavior, requests will be filtered based on your config
  config.skip_request_filter = false

  # set a default target sample size for all experiments - this will prevent
  # metrics and stats from being displayed in the admin UI until the sample size
  # is reached or the experiment is stopped
  #
  # config.target_sample_size = nil

  # callback when connecting to redis fails and trailguide falls back to always
  # returning control variants
  config.on_redis_failover = -> (experiment, error) do
    Rails.logger.error("#{error.class.name}: #{error.message}")
  end

  # callback on experiment start, either manually via UI/console or
  # automatically depending on config.start_manually, can be used for logging,
  # tracking, etc.
  #
  # config.on_start = -> (experiment) { ... }

  # callback on experiment stop manually via UI/console, can be used for
  # logging, tracking, etc.
  #
  # config.on_stop = -> (experiment) { ... }

  # callback on experiment resume manually via UI/console, can be used for
  # logging, tracking, etc.
  #
  # config.on_resume = -> (experiment) { ... }

  # callback on experiment reset manually via UI/console, can be used for
  # logging, tracking, etc.
  #
  # config.on_reset = -> (experiment) { ... }

  # callback when a winner is selected manually via UI/console, can be used for
  # logging, tracking, etc.
  #
  # config.on_winner = -> (experiment, winner) { ... }


  # callback when a participant is entered into a variant for the first time,
  # can be used for logging, tracking, etc.
  #
  # config.on_choose = -> (experiment, variant, metadata) { ... }

  # callback every time a participant is returned a variant in the experiment,
  # can be used for logging, tracking, etc.
  #
  # config.on_use = -> (experiment, variant, metadata) { ... }

  # callback when a participant converts for a variant in the experiment, can be
  # used for logging, tracking, etc.
  #
  # config.on_convert = -> (experiment, variant, checkpoint, metadata) { ... }


  # callback that can short-circuit participation based on your own logic, which
  # gets called *after* all the core engine checks (i.e. that the user is
  # not excluded or already participating, etc.)
  #
  # should return true or false
  #
  # config.allow_participation = -> (experiment, metadata) { ... return true }


  # callback that can short-circuit conversion based on your own logic, which
  # gets called *after* all the core engine checks (i.e. that the user is
  # participating in the experiment, is within the bounds of the experiment
  # configuration for allow_multiple_*, etc.)
  #
  # should return true or false
  #
  # config.allow_conversion = -> (experiment, checkpoint, metadata) { ... return true }


  # callback that can be used to modify the rollout of a selected winner - for
  # example you could use a custom algorithm or even something like the flipper
  # gem to do a "feature rollout" from your control variant to your winner for
  # all users
  #
  # must return an experiment variant
  #
  # config.rollout_winner = -> (experiment, winner) { ... return variant }
end

# admin ui configuration
#
TrailGuide::Admin.configure do |config|
  # display title for admin UI
  #
  config.title = 'TrailGuide'

  # display subtitle for admin UI
  #
  config.subtitle = 'Experiments and A/B Tests'

  # request parameter can be used to "peek" at results even before an
  # experiment's target_sample_size has been hit if one is configured
  #
  # if you set this to nil, admins will not be able to peek at experiment
  # results until the target sample size is hit or the experiment is stopped
  #
  config.peek_parameter = nil
end
