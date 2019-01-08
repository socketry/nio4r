# frozen_string_literal: true

require "coveralls"
Coveralls.wear!

require "nio"
require "support/selectable_examples"

RSpec.configure do |config|
  config.disable_monkey_patching!
end
