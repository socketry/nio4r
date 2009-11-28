require 'rubygems'

GEMSPEC = Gem::Specification.new do |s|
  s.name = "iobuffer"
  s.version = "0.1.2"
  s.authors = "Tony Arcieri"
  s.email = "tony@medioh.com"
  s.date = "2009-08-28"
  s.summary = "Fast C-based buffer for non-blocking I/O"
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.8.6'

  # Gem contents
  s.files = Dir.glob("{lib,ext,spec,tasks}/**/*") + ['Rakefile', 'iobuffer.gemspec']

  # RubyForge info
  s.homepage = "http://rev.rubyforge.org"
  s.rubyforge_project = "rev"

  # RDoc settings
  s.has_rdoc = true
  s.rdoc_options = %w(--title IO::Buffer --main README --line-numbers)
  s.extra_rdoc_files = ["LICENSE", "README", "CHANGES"]

  # Extensions
  s.extensions = Dir["ext/**/extconf.rb"]
end
