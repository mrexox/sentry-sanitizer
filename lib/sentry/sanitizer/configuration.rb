require 'sentry/configuration'
require 'sentry/sanitizer/cleaner'
require 'sentry/sanitizer/configuration_mixin'

module Sentry
  # Monkey-patching Sentry::Configuration
  class Configuration
    # Add sanitizing configuration
    attr_reader :sanitize

    # Patch before_send method so it could support more than one call
    prepend Sentry::Sanitizer::ConfigurationMixin

    add_post_initialization_callback do
      @sanitize ||= Sentry::Sanitizer::Configuration.new

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

      def fields=(fields)
        unless fields.is_a? Array
          raise ArgumentError, 'sanitize_fields must be array'
        end

        @fields = fields
      end

      def http_headers=(headers)
        unless [Array, TrueClass, FalseClass].include?(headers.class)
          raise ArgumentError, 'sanitize_http_headers must be array'
        end

        @http_headers = headers
      end

      def cookies=(cookies)
        unless [TrueClass, FalseClass].include?(cookies.class)
          raise ArgumentError, 'sanitize_cookies must be boolean'
        end

        @cookies = cookies
      end
    end
  end
end
