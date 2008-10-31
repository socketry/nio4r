require 'spec/rake/spectask'

FILES = Dir['spec/*_spec.rb']

desc "Run RSpec against the package's specs"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts = %w(-fs -c)
  t.spec_files = FILES
end

desc "Run RSpec generate a code coverage report"
Spec::Rake::SpecTask.new(:coverage) do |t|
  t.spec_files = FILES
  t.rcov = true
  t.rcov_opts = %w[--rails --exclude gems,spec]
end