# -*- encoding: utf-8 -*-
require File.expand_path('../lib/nio/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri"]
  gem.email         = ["tony.arcieri@gmail.com"]
  gem.description   = "New IO for Ruby"
  gem.summary       = "NIO exposes a set of high performance IO operations on sockets, files, and other Ruby IO objects"
  gem.homepage      = "https://github.com/tarcieri/nio4r"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "nio4r"
  gem.require_paths = ["lib"]
  gem.version       = NIO::VERSION

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", ">= 2.7.0"
end
