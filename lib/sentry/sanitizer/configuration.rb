require 'sentry/configuration'
require 'sentry/sanitizer/cleaner'
require 'sentry/sanitizer/configuration_mixin'

module Sentry
  # Monkey-patching Sentry::Configuration
  class Configuration
    prepend Sentry::Sanitizer::ConfigurationMixin

    add_post_initialization_callback do
      self.before_send = ->(event, hint) do
        Sentry::Sanitizer::Cleaner.new(Sentry.configuration.sanitize).call(event)

        event
      end
    end
  end

  module Sanitizer
    class Configuration
      attr_accessor :fields, :http_headers, :cookies

      def configured?
        [fields, http_headers, cookies].any? { |setting| !setting.nil? }
      end
    end
  end
end
