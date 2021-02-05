module Sentry
  module Sanitizer
    class Cleaner
      HOOK = ->(event, hint) do
        Sentry::Sanitizer::Cleaner.new(Sentry.configuration.sanitize).call(event)

        event
      end.freeze

      DEFAULT_MASK = '[FILTERED]'.freeze
      DEFAULT_SENSITIVE_HEADERS = %w[
        Authorization
        X-Xsrf-Token
      ].freeze

      private_constant :DEFAULT_SENSITIVE_HEADERS

      def initialize(config)
        @fields = config.fields || []
        @http_headers = config.http_headers || []
        @cookies = config.cookies || false
      end

      def call(event)
        if event.is_a?(Sentry::Event)
          event.request = sanitize_request(event.request) if event.request
          event.extra = sanitize_hash(event.extra) if event.extra
        end
      end

      def sanitize_request(request)
        request.data = sanitize_hash(request.data) unless fields.size.zero?
        request.headers = sanitize_headers(request.headers) unless http_headers.size.zero?
        request.cookies = sanitize_cookies(request.cookies) if cookies
      end

      def sanitize_hash(hash)
        return if hash.blank?

        sanitize_value(hash, nil)
      end

      private

      attr_reader :fields, :http_headers, :cookies

      # Sanitize specified headers
      def sanitize_headers(headers)
        headers.keys.select { |key| key.match?(sensitive_headers) }.each do |key|
          headers[key] = DEFAULT_MASK
        end

        headers
      end

      # Sanitize all cookies
      def sanitize_cookies(cookies)
        cookies.transform_values { DEFAULT_MASK }
      end

      def sanitize_value(value, key)
        case value
        when Hash
          sanitize_hash(key, value)
        when Array
          sanitize_array(key, value)
        when String
          sanitize_string(key, value)
        else
          value
        end
      end

      def sanitize_hash(key, value)
        if key&.match?(sensitive_fields)
          DEFAULT_MASK
        elsif value.frozen?
          value.merge(value) { |k, v| sanitize_value(v, k) }
        else
          value.merge!(value) { |k, v| sanitize_value(v, k) }
        end
      end

      def sanitize_array(key, value)
        if value.frozen?
          value.map { |val| sanitize_value(val, key) }
        else
          value.map! { |val| sanitize_value(val, key) }
        end
      end

      def sanitize_string(key, value)
        key&.match?(sensitive_fields) ? DEFAULT_MASK : value
      end

      def sensitive_fields
        @sensitive_fields ||= sensitive_regexp(fields)
      end

      def sensitive_headers
        @sensitive_headers ||= sensitive_regexp(DEFAULT_SENSITIVE_HEADERS | http_headers)
      end

      def sensitive_regexp(fields)
        Regexp.new(fields.map { |field| "\\b#{field}\\b" }.join('|'), 'i')
      end
    end
  end
end
