source "https://rubygems.org"

gemspec

gem "jruby-openssl" if defined? JRUBY_VERSION

group :development, :test do
  gem "coveralls",         require: false
  gem "rake-compiler",     require: false
  gem "rspec",   "~> 3",   require: false
  gem "rubocop", "0.46.0", require: false
end
