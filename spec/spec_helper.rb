require "coveralls"
Coveralls.wear!

require "rubygems"
require "bundler/setup"
require "nio"
require "support/selectable_examples"

RSpec.configure(&:disable_monkey_patching!)
