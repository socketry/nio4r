require 'rake/extensiontask'
Rake::ExtensionTask.new('iobuffer_ext') do |ext|
  ext.ext_dir = 'ext'
end
