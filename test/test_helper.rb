require "fileutils"

if ENV["SONAR"] == "1"
  require "simplecov"
  require "simplecov_json_formatter"

  FileUtils.mkdir_p("coverage")
  SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
  SimpleCov.start "rails" do
    add_filter "/test/"
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

if ENV["SONAR"] == "1"
  require "minitest/reporters"

  FileUtils.mkdir_p("tmp/sonar/junit")
  Minitest::Reporters.use!(
    [Minitest::Reporters::JUnitReporter.new("tmp/sonar/junit", false)],
    ENV,
    Minitest.backtrace_filter
  )
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
