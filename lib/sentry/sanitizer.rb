require 'sentry-ruby'
require 'sentry/integrable'
require 'sentry/sanitizer/configuration'

module Sentry
  module Sanitizer
    extend Integrable

    register_integration name: 'sanitizer', version: Sentry::Sanitizer::VERSION
  end
end
