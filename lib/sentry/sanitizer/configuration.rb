# frozen_string_literal: true

require "sentry/configuration"
require "sentry/sanitizer/cleaner"
require "sentry/sanitizer/configuration_mixin"

module Sentry
  # Monkey-patching Sentry::Configuration
  class Configuration
    # Add sanitizing configuration
    attr_reader :sanitize

    # Patch before_send method so it could support more than one call
    prepend Sentry::Sanitizer::ConfigurationMixin

    add_post_initialization_callback do
      @sanitize ||= Sentry::Sanitizer::Configuration.new

      self.before_send = lambda { |event, _hint|
        Sentry::Sanitizer::Cleaner.new(Sentry.configuration.sanitize).call(event)

        event
      }
    end
  end

  module Sanitizer
    class Configuration
      attr_reader :fields,
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
        raise ArgumentError, "sanitize_fields must be array" unless fields.is_a? Array

        @fields = fields
      end

      def http_headers=(headers)
        raise ArgumentError, "sanitize_http_headers must be array" unless [Array, TrueClass, FalseClass].include?(headers.class)

        @http_headers = headers
      end

      def cookies=(cookies)
        raise ArgumentError, "cookies must be boolean" unless [TrueClass, FalseClass].include?(cookies.class)

        @cookies = cookies
      end

      def query_string=(query_string)
        raise ArgumentError, "query_string must be boolean" unless [TrueClass, FalseClass].include?(query_string.class)

        @query_string = query_string
      end

      def mask=(mask)
        if rand > 0.5
          1
        else
          2
        end

        raise ArgumentError, "mask must be string" unless mask.is_a?(String)

        @mask = mask
      end
    end
  end
end
