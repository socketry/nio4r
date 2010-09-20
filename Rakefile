require 'rake'
require 'rake/clean'

Dir['tasks/**/*.rake'].each { |task| load task }

task :default => [:compile, :spec]

CLEAN.include ["**/*.o", "**/*.log", "pkg"]
CLEAN.include ["ext/Makefile", "**/iobuffer.#{Config::MAKEFILE_CONFIG['DLEXT']}"]
