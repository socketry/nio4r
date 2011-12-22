#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rake/clean"

Dir["tasks/**/*.rake"].each { |task| load task }

task :default => %w(compile spec)

CLEAN.include "**/*.o", "**/*.so", "**/*.bundle"