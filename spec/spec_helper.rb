if ENV['CI'] == 'true'
  require 'simplecov'
  require 'simplecov-lcov'
  SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
  SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
  SimpleCov.start do
    add_filter '/spec/'
    enable_coverage :branch
  end

  # require 'simplecov'
  # require 'codecov'

  # SimpleCov.start
  # SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require 'bundler/setup'
require 'sentry/sanitizer'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
