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

  spec.files = Dir["{app,config,lib}/**/*", "MIT-LICENSE", "README.md"]

  spec.add_dependency "rails", "~> 5"
  spec.add_dependency "canfig", ">= 0.0.7"
  spec.add_dependency "redis"
  spec.add_dependency "simple-random", ">= 0.9.3"

  # TODO sort all this out once calculations are done
  spec.add_development_dependency "gsl", ">= 2.1.0"
  spec.add_development_dependency "integration", ">= 0.1.4"
  spec.add_development_dependency "distribution", ">= 0.7.3"
  spec.add_development_dependency "rubystats", ">= 0.3.0"
  spec.add_development_dependency "abanalyzer"

  spec.add_development_dependency "sqlite3", "~> 1.3.6"
  spec.add_development_dependency "redis-namespace"
  spec.add_development_dependency "rspec-rails"
end
