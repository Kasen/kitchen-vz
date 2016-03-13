require 'bundler/gem_tasks'
require 'rubocop/rake_task'

desc 'Run Ruby style checks'
RuboCop::RakeTask.new(:rubocop)

desc 'Run all quality tasks'
task quality: [:rubocop]

task default: [:quality]
