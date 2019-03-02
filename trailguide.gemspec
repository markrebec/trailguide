$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "trail_guide/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "trailguide"
  spec.version     = TrailGuide::Version::VERSION
  spec.authors     = ["Mark Rebec"]
  spec.email       = ["mark@markrebec.com"]
  spec.homepage    = "https://github.com/markrebec/trailguide"
  spec.summary     = "User experiments for rails"
  spec.description = "Perform user experiments and A/B tests in your rails apps"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 5.2.2"
  spec.add_dependency "canfig"
  spec.add_dependency "redis"

  spec.add_development_dependency "sqlite3", "~> 1.3.6"
  spec.add_development_dependency "rspec-rails"
end
