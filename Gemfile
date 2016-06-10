source "https://rubygems.org"

gemspec

gem "jruby-openssl" if defined? JRUBY_VERSION

group :development, :test do
  gem "rake-compiler"
  gem "rspec",   "~> 3",   require: false
  gem "rubocop", "0.36.0", require: false
  gem "coveralls",         require: false
end
