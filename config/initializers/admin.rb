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

  # date/time format to use for display in the admin UI
  config.date_format = "%b %e %Y @ %l:%M %p"

  # time zone to use when formatting dates/times in the admin UI
  #
  # can be an ActiveSupport::TimeZone, a string that maps to an ActiveSupport::TimeZone[],
  # like "UTC" or "Pacific Time (US & Canada)", or a block that returns a
  # time zone or a string
  config.time_zone = -> { Time.zone || "UTC" }
end
