source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Declare your gem's dependencies in trailguide.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# debugging
gem 'byebug', group: [:development, :test]
gem 'awesome_print', group: [:development, :test]

# coverage
gem 'simplecov', group: [:development, :test], require: false
gem 'simplecov-lcov', group: [:development, :test], require: false

# development
gem 'solargraph', group: [:development, :test], require: false

# testing / dummy app

rails_version = ENV['RAILS_VERSION'] || 'default'
rails = case rails_version
when 'master'
  { github: 'rails/rails' }
when 'default'
  '~> 5'
else
  "~> #{rails_version}"
end

gem 'rails', rails
gem 'sqlite3', group: [:development, :test]