# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "jruby-openssl" if defined? JRUBY_VERSION

group :maintenance, optional: true do
  unless defined? JRUBY_VERSION
    gem "bake"
    gem "bake-gem"
    gem "bake-modernize"
  end

  gem "rake"
end

group :development, :test do
  gem "rake-compiler", "~> 1.2", require: false
  gem "rspec", "~> 3.7", require: false
  gem "rubocop", "0.82.0", require: false
end
