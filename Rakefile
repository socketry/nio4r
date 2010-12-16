require 'rubygems'
require 'bundler'
require 'rake/clean'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "iobuffer"
  gem.homepage = "http://github.com/tarcieri/iobuffer"
  gem.license = "MIT"
  gem.summary = "Fast C-based I/O buffering"
  gem.description = "iobuffer is a fast, C-based byte queue for storing arbitrary amounts of data until it can be written to the network"
  gem.email = "tony@medioh.com"
  gem.authors = ["Tony Arcieri"]
  
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  
  gem.add_development_dependency 'rspec', '>= 2.1.0'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.rspec_opts = %w(-fs -c)
end

task :default => [:compile, :spec]

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "iobuffer #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

ext_so = "ext/iobuffer.#{Config::MAKEFILE_CONFIG['DLEXT']}"
ext_files = FileList[
  "ext/*.c",
  "ext/*.h",
  "ext/extconf.rb",
  "ext/Makefile",
  "lib"
]

desc "Compile the IO::Buffer extension"
task :compile => ["ext/Makefile", ext_so ]

file "ext/Makefile" => %w[ext/extconf.rb] do
  Dir.chdir('ext') { ruby "extconf.rb" }
end

file ext_so => ext_files do
  Dir.chdir('ext') { sh 'make' }
  cp ext_so, "lib"
end

CLEAN.include ["**/*.o", "**/*.log", "pkg"]
CLEAN.include ["ext/Makefile", "**/iobuffer.#{Config::MAKEFILE_CONFIG['DLEXT']}"]
