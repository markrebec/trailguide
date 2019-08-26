# top-level trailguide rails engine configuration
#
TrailGuide.configure do |config|
  # logger object
  config.logger = Rails.logger

  # paths where trailguide will look for experiment configs and classes, each
  # can be configured with multiple paths
  config.paths.configs << 'config/experiments.*'
  config.paths.configs << 'config/experiments/**/*'
  config.paths.classes << 'app/experiments/**/*.rb'

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
