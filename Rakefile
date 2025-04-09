# frozen_string_literal: true

require "bundler/gem_tasks"
desc "Run tests"
task :test do
  sh "bin/test"
end

require "standard/rake"

task default: %i[test standard]
