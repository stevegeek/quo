# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov_small_badge"

  SimpleCov.start do
    add_filter "/test/"

    add_group "Core", "lib/quo"
    
    SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCovSmallBadge::Formatter
    ])
  end

  SimpleCovSmallBadge.configure do |config|
    config.rounded_border = true
    config.background = "#ffffcc"
    config.output_path = "badges/"
  end

  puts "SimpleCov enabled with badge generation"
end

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end
