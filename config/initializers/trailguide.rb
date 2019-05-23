# top-level trailguide rails engine configuration
#
TrailGuide.configure do |config|
  # logger object
  config.logger = Rails.logger

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

  # whether or not to ignore orphaned group/experiment conversion calls in the
  # admin - this can be useful if you intentionally leave calls to
  # `trailguide.convert(:group_name)` at key points in your application, but
  # also periodically add/remove experiments using those groups
  #
  # true  will not track orphaned convert calls nor expose them in the admin
  #       interface
  # false will track orphaned convert calls, and notify you via the admin
  #       interface so you can track them down and remove them as you'd like
  config.ignore_orphaned_groups = false

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

  # whether or not to clean up any old/inactive experiments for participants
  # regularly as part of the experiment flow - this is very fast, and only adds
  # a couple milliseconds to participant initialization, but isn't strictly
  # necessary, since expired enrollment will never affect future experiment
  # participation - it might be good practice if you're using redis to store
  # participant data without expiration, or to avoid overflowing a client cookie
  #
  # true      will explicitly clean up any old/inactive experiment keys for each
  #           participant the first time they're initialized during a script
  #           execution (web request, etc.)
  # :inline   will only clean up any old/inactive experiment keys that are
  #           encountered when referencing a participant's active experiments
  # false     will skip the cleanup process entirely
  config.cleanup_participant_experiments = true

  # the ttl (in seconds) for unity session unification keys - only applicable if
  # you're using the unity adapter and/or are leveraging unity outside of
  # trailguide experiments - particularly useful if you want to use something
  # like the volatile-lru eviction policy for your redis instance
  #
  # nil       no expiration for unity session unification keys
  # 31556952  1 year (in seconds) expiration for unity keys
  config.unity_ttl = nil

  # callback when your participant adapter fails to initialize, and trailguide
  # falls back to the anonymous adapter
  config.on_adapter_failover = -> (adapter, error) do
    TrailGuide.logger.error error
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

  # whether or not to store individual participation when returning a variant
  #
  # this can be useful if you are using a custom, content-based algorithm where
  # the variant is determined by content rather than user bucketing, and you
  # want to treat participation more like impressions (i.e. for seo experiments)
  #
  # true    participation is incremented the first time a participant is
  #         enrolled, and the participant is assigned their selection for future
  #         reference, stored via the configured participant adapter
  # false   participation will be incremented every time a variant is returned,
  #         and the participant will not have their assignment stored
  config.store_participation = true

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

  # whether or not to enable calibration before an experiment is started - the
  # participants and conversions will be tracked for your control group while
  # an experiment remains unstarted, which can be useful for gathering a
  # baseline conversion rate if you don't already have one
  #
  # control is always returned for unstarted experiments by default, and this
  # configuration only affects whether or not to track metrics
  #
  # this setting only applies when start_manually is also true
  #
  # true  metrics for participation and conversion will be tracked for the
  #       control group until the experiment is started
  # false metrics will not be tracked while the experiment remains unstarted
  config.enable_calibration = false

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

  # whether or not this experiment can be resumed after it's stopped - allows
  # temporarily "pausing" an experiment then resuming it without losing metrics
  #
  # true    this experiment can be paused and resumed
  # false   this experiment can only be stopped and reset/restarted
  config.can_resume = false

  # set a default target sample size for all experiments - this will prevent
  # metrics and stats from being displayed in the admin UI until the sample size
  # is reached or the experiment is stopped
  #
  # config.target_sample_size = nil

  # callback when connecting to redis fails and trailguide falls back to always
  # returning control variants
  config.on_redis_failover = -> (experiment, error) do
    TrailGuide.logger.error error
  end

  # callback on experiment start, either manually via UI/console or
  # automatically depending on config.start_manually, can be used for logging,
  # tracking, etc.
  #
  # context may or may not be present depending on how you're triggering the
  # action - if you're using the admin, this will be the admin controller
  # context, if you're in a console you have the option to pass a context to
  # `experiment.start!` or not
  #
  # config.on_start = -> (experiment, context) { ... }

  # callback on experiment schedule manually via UI/console, can be used for logging,
  # tracking, etc.
  #
  # experiments can only be scheduled if config.start_manually is true
  #
  # context may or may not be present depending on how you're triggering the
  # action - if you're using the admin, this will be the admin controller
  # context, if you're in a console you have the option to pass a context to
  # `experiment.schedule!` or not
  #
  # config.on_schedule = -> (experiment, start_at, stop_at, context) { ... }

  # callback on experiment stop manually via UI/console, can be used for
  # logging, tracking, etc.
  #
  # context may or may not be present depending on how you're triggering the
  # action - if you're using the admin, this will be the admin controller
  # context, if you're in a console you have the option to pass a context to
  # `experiment.stop!` or not
  #
  # config.on_stop = -> (experiment, context) { ... }

  # callback on experiment pause manually via UI/console, can be used for
  # logging, tracking, etc.
  #
  # context may or may not be present depending on how you're triggering the
  # action - if you're using the admin, this will be the admin controller
  # context, if you're in a console you have the option to pass a context to
  # `experiment.pause!` or not
  #
  # config.on_pause = -> (experiment, context) { ... }

  # callback on experiment resume manually via UI/console, can be used for
  # logging, tracking, etc.
  #
  # context may or may not be present depending on how you're triggering the
  # action - if you're using the admin, this will be the admin controller
  # context, if you're in a console you have the option to pass a context to
  # `experiment.resume!` or not
  #
  # config.on_resume = -> (experiment, context) { ... }

  # callback on experiment delete manually via UI/console, can be used for
  # logging, tracking, etc. - will also be triggered by a reset
  #
  # context may or may not be present depending on how you're triggering the
  # action - if you're using the admin, this will be the admin controller
  # context, if you're in a console you have the option to pass a context to
  # `experiment.delete!` or not
  #
  # config.on_delete = -> (experiment, context) { ... }

  # callback on experiment reset manually via UI/console, can be used for
  # logging, tracking, etc. - will also trigger any on_delete callbacks
  #
  # context may or may not be present depending on how you're triggering the
  # action - if you're using the admin, this will be the admin controller
  # context, if you're in a console you have the option to pass a context to
  # `experiment.reset!` or not
  #
  # config.on_reset = -> (experiment, context) { ... }

  # callback when a winner is selected manually via UI/console, can be used for
  # logging, tracking, etc.
  #
  # context may or may not be present depending on how you're triggering the
  # action - if you're using the admin, this will be the admin controller
  # context, if you're in a console you have the option to pass a context to
  # `experiment.declare_winner!` or not
  #
  # config.on_winner = -> (experiment, winner, context) { ... }


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
  # be aware that when using this alongside track_winner_conversions, whatever
  # variant is returned from this callback chain is what will be tracked for
  # participation and conversion as long as the experiment is still running
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
