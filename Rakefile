# frozen_string_literal: true

require "bundler/gem_tasks"
desc "Run tests"
task :test do
  sh "bin/test"
end

require "standard/rake"

task default: %i[test standard]

# Add RubyCritic task with badge generation
begin
  require "rubycritic_small_badge"
  require "rubycritic/rake_task"

  RubyCriticSmallBadge.configure do |config|
    config.minimum_score = 90
  end

  RubyCritic::RakeTask.new do |task|
    task.paths = FileList["lib/**/*.rb"]

    task.options = %(--custom-format RubyCriticSmallBadge::Report
      --minimum-score #{RubyCriticSmallBadge.config.minimum_score}
      --coverage-path coverage/.resultset.json
      --no-browser)
  end

  desc "Run tests with coverage and then RubyCritic"
  task rubycritic_with_coverage: [:coverage, :rubycritic]
rescue LoadError
  desc "Run RubyCritic (not available)"
  task :rubycritic do
    puts "RubyCritic is not available"
  end
end

desc "Run code coverage"
task :coverage do
  ENV["COVERAGE"] = "1"
  Rake::Task["test"].invoke
end

namespace :website do
  desc "Build the documentation website"
  task :build do
    Dir.chdir("website") do
      puts "Building documentation website..."
      system "bundle install"
      system "bundle exec jekyll build"
      puts "Website built in website/_site/"
    end
  end

  desc "Serve the documentation website locally"
  task :serve do
    Dir.chdir("website") do
      puts "Starting local documentation server..."
      puts "View the website at http://localhost:4000/"
      system "bundle install"
      system "bundle exec jekyll serve"
    end
  end

  desc "Clean the documentation website build"
  task :clean do
    Dir.chdir("website") do
      puts "Cleaning website build..."
      system "bundle exec jekyll clean"
    end
  end
end
