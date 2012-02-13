# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require "iobuffer/version"

Gem::Specification.new do |gem|
  gem.name        = "iobuffer"
  gem.version     = IO::Buffer::VERSION
  gem.platform    = Gem::Platform::RUBY
  gem.summary     = "fast buffers for non-blocking IO"
  gem.description = gem.summary
  gem.licenses    = ['MIT']

  gem.authors     = ['Tony Arcieri']
  gem.email       = ['tony.arcieri@gmail.com']
  gem.homepage    = 'https://github.com/tarcieri/iobuffer'

  gem.required_rubygems_version = '>= 1.3.6'

  gem.files        = Dir['README.md', 'lib/iobuffer', 'lib/**/*', 'ext/**/*.{c,rb}']
  gem.require_path = 'lib'

  gem.extensions = ["ext/extconf.rb"]

  gem.add_development_dependency 'rake-compiler'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
end
