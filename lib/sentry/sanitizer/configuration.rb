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
      attr_accessor :fields,
                    :http_headers,
                    :cookies,
                    :query_string,
                    :mask

      def configured?
        [
          fields,
          http_headers,
          cookies,
          query_string
        ].any? { |setting| !setting.nil? }
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
          raise ArgumentError, 'cookies must be boolean'
        end

        @cookies = cookies
      end

      def query_string=(query_string)
        unless [TrueClass, FalseClass].include?(query_string.class)
          raise ArgumentError, 'query_string must be boolean'
        end

        @query_string = query_string
      end

      def mask=(mask)
        unless mask.is_a?(String)
          raise ArgumentError, 'mask must be string'
        end

        @mask = mask
      end
    end
  end
end
