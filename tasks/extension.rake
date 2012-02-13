require 'rake/extensiontask'
Rake::ExtensionTask.new('iobuffer') do |ext|
  ext.ext_dir = 'ext'
end