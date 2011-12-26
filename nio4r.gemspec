# -*- encoding: utf-8 -*-
require File.expand_path('../lib/nio/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri"]
  gem.email         = ["tony.arcieri@gmail.com"]
  gem.description   = "New IO for Ruby"
  gem.summary       = "NIO provides a high performance selector API for monitoring IO objects"
  gem.homepage      = "https://github.com/tarcieri/nio4r"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "nio4r"
  gem.require_paths = ["lib"]
  gem.version       = NIO::VERSION
  gem.extensions = ["ext/nio4r/extconf.rb"] unless defined?(JRUBY_VERSION)

  gem.add_development_dependency "rake-compiler", "~> 0.7.9"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", ">= 2.7.0"
end
