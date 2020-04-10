begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'TrailGuide'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

APP_RAKEFILE = File.expand_path("spec/dummy/Rakefile", __dir__)
load 'rails/tasks/engine.rake'

load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'

task :build do
  puts `gem build trailguide.gemspec`
end

task :push do
  require 'trail_guide/version'
  puts `gem push trailguide-#{TrailGuide::Version::VERSION}.gem`
end

task :yarn do
  require 'trail_guide/version'
  puts `yarn publish --no-git-tag-version --new-version #{TrailGuide::Version::VERSION} --message "bumps npm package to #{TrailGuide::Version::VERSION}"`
end

task release: [:build, :push] do
  puts `rm -f trailguide*.gem`
end
