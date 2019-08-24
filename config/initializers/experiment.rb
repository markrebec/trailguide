# base experiment configuration
#
TrailGuide::Experiment.configure do |config|
  # the default algorithm to use for new experiments
  config.algorithm = :distributed

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

  # whether or not individual assignment is sticky when returning a variant
  #
  # this can be useful if you are using a custom, content-based algorithm where
  # the variant is determined by content rather than user bucketing, and you
  # want to treat participation more like impressions (i.e. for seo experiments)
  #
  # when this option is set to false, conversions will always be tracked against
  # the last variant that the participant was served
  #
  # true    participation is incremented the first time a participant is
  #         enrolled, and the participant is assigned their selection for future
  #         reference, stored via the configured participant adapter
  # false   participation will be incremented every time a variant is selected,
  #         and the participant will not be forced into a bucket
  config.sticky_assignment = true

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
  # config.on_choose = -> (experiment, variant, participant, metadata) { ... }

  # callback every time a participant is returned a variant in the experiment,
  # can be used for logging, tracking, etc.
  #
  # config.on_use = -> (experiment, variant, participant, metadata) { ... }

  # callback when a participant converts for a variant in the experiment, can be
  # used for logging, tracking, etc.
  #
  # config.on_convert = -> (experiment, checkpoint, variant, participant, metadata) { ... }


  # callback that can short-circuit participation based on your own logic, which
  # gets called *after* all the core engine checks (i.e. that the user is
  # not excluded or already participating, etc.)
  #
  # `allowed` will be the value returned by any previous callbacks in the chain
  #
  # should return true or false
  #
  # config.allow_participation = -> (experiment, allowed, participant, metadata) { ... return true }


  # callback that can short-circuit conversion based on your own logic, which
  # gets called *after* all the core engine checks (i.e. that the user is
  # participating in the experiment, is within the bounds of the experiment
  # configuration for allow_multiple_*, etc.)
  #
  # `allowed` will be the value returned by any previous callbacks in the chain
  #
  # should return true or false
  #
  # config.allow_conversion = -> (experiment, allowed, checkpoint, variant, participant, metadata) { ... return true }


  # callback that can be used to modify the rollout of a selected winner - for
  # example you could use a custom algorithm or even something like the flipper
  # gem to do a "feature rollout" from your control variant to your winner for
  # all users
  #
  # be aware that when using this alongside track_winner_conversions, whatever
  # variant is returned from this callback chain is what will be tracked for
  # participation and conversion as long as the experiment is still running
  #
  # `winner` will be the variant returned by any previous callbacks in the chain
  #
  # must return an experiment variant
  #
  # config.rollout_winner = -> (experiment, winner, participant) { return winner }
end
