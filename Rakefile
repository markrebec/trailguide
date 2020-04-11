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

task :bump do
  TrailGuide.send(:remove_const, :Version)
  load 'lib/trail_guide/version.rb'
  major = ENV.fetch('MAJOR', TrailGuide::Version::MAJOR)
  minor = ENV.fetch('MINOR', TrailGuide::Version::MINOR)
  patch = ENV.fetch('PATCH', 'true')
  major = TrailGuide::Version::MAJOR + 1 if major == 'true'
  minor = TrailGuide::Version::MINOR + 1 if minor == 'true'
  patch = TrailGuide::Version::PATCH + 1 if patch == 'true'
  version = "#{major}.#{minor}.#{patch}"

  File.write('package.json', File.read('package.json').gsub(/"version": "[\d\.]*"/, "\"version\": \"#{version}\""))

  File.write('lib/trail_guide/version.rb', File.read('lib/trail_guide/version.rb').gsub(/MAJOR = \d*/, "MAJOR = #{major}").gsub(/MINOR = \d*/, "MINOR = #{minor}").gsub(/PATCH = \d*/, "PATCH = #{patch}"))

  system "git commit -am '#{version}'"
end

task :build do
  system 'yarn build:rails'
  system 'yarn build:node'
end

task :release do
  system "yarn publish --no-git-tag-version --new-version #{TrailGuide::Version::VERSION} --non-interactive"
end
