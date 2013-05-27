# -*- encoding: utf-8 -*-
require File.expand_path('../lib/nio/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri"]
  gem.email         = ["tony.arcieri@gmail.com"]
  gem.description   = "New IO for Ruby"
  gem.summary       = "NIO provides a high performance selector API for monitoring IO objects"
  gem.homepage      = "https://github.com/celluloid/nio4r"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "nio4r"
  gem.require_paths = ["lib"]
  gem.version       = NIO::VERSION

  if defined? JRUBY_VERSION
    gem.files << "lib/nio4r_ext.jar"
    gem.platform = "java"
  else
    gem.extensions = ["ext/nio4r/extconf.rb"]
  end

  gem.add_development_dependency "rake-compiler"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
end
