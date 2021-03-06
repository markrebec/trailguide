# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../dummy/config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'trail_guide/spec_helper'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

TrailGuide.configure do |config|
  config.redis = Redis::Namespace.new(
    :trailguide_specs,
    redis: Redis.new(url: ENV['REDIS_URL'])
  )
end

module TrailGuide::SpecDSL
  def create_experiment(name, **opts, &block)
    TrailGuide::Catalog::DSL.experiment name, **opts, &block
    exp = TrailGuide.catalog.find(name)
    exp.configure do # add a couple default variants if none were provided
      variant :control
      variant :alternate
    end if exp.variants.empty?
    exp
  end

  def destroy_experiment(name)
    TrailGuide.catalog.deregister(name)
  end
end

module TrailGuide::GroupDSL
  def experiment(name=nil, **opts, &block)
    name ||= [*('a'..'z'),*('0'..'9')].shuffle[0,8].join
    let(name)         { create_experiment(name, **opts, &block) }
    let(:experiment)  { send(name) }
    let(:experiments) { [] }
    before             { experiments << send(name) }
  end

  def experiment_subject(name=nil, **opts, &block)
    experiment(name, **opts, &block)
    subject { experiment }
  end

  def combined(name=nil, **opts, &block)
    name ||= [*('a'..'z'),*('0'..'9')].shuffle[0,8].join
    opts[:combined] ||= [:first, :second]
    experiment(name, **opts, &block)
    let(:combined) { send(name).combined_experiments }
  end

  def variant(name, varname=nil, &block)
    block ||= -> { experiment.variants.find { |v| v == name } }
    varname ||= name
    let(:variant, &block)
    let(varname, &block)
  end

  def metric(name, varname=nil, &block)
    block ||= -> { experiment.goals.find { |g| g == name } }
    varname ||= name
    let(:metric, &block)
    let(varname, &block)
  end

  def participant(context=nil, adapter: nil)
    adapter ||= TrailGuide::Adapters::Participants::Anonymous
    let(:participant) { TrailGuide::Participant.new(context, adapter: adapter) }
  end

  def trial(**opts, &block)
    name = opts.delete(:name)
    name ||= [*('a'..'z'),*('0'..'9')].shuffle[0,8].join
    context = opts.delete(:context)
    adapter = opts.delete(:adapter)
    adapter ||= TrailGuide::Adapters::Participants::Anonymous
    experiment(name, **opts, &block)
    participant(context, adapter: adapter)
    let(:trial) { experiment.new(participant) }
  end

  def trial_subject(**opts, &block)
    trial(**opts, &block)
    subject { trial }
  end
end

RSpec.configure do |config|
  config.include TrailGuide::SpecDSL
  config.extend  TrailGuide::GroupDSL

  config.before(:example) do
    redis_keys = TrailGuide.redis.keys
    TrailGuide.redis.del(*redis_keys) if redis_keys.present?
    TrailGuide.catalog.instance_variable_set :@experiments, []
    TrailGuide.catalog.instance_variable_set :@combined, []
  end

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
