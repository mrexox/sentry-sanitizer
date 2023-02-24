require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
end

require 'bundler/setup'
require 'sentry/sanitizer'

if ENV['CI'] == 'true'
  require 'simplecov'
  require 'codecov'

  SimpleCov.start
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
