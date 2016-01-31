source "https://rubygems.org"

gemspec

gem "jruby-openssl" if defined? JRUBY_VERSION

group :development do
  gem "rake-compiler"
end

group :test do
  gem "rspec",     "~> 3.0"
  gem "rubocop",   "0.36.0"
  gem "coveralls", require: false
end
