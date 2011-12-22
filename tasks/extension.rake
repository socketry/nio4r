require 'rake/extensiontask'

if defined?(JRUBY_VERSION)
  # Don't build the native extension on JRuby since it uses native Java NIO
  task :compile
else
  Rake::ExtensionTask.new('nio4r_ext') do |ext|
    ext.ext_dir = 'ext/nio4r'
  end
end