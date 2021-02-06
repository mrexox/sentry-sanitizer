module Sentry
  module Sanitizer
    class Cleaner
      DEFAULT_MASK = '[FILTERED]'.freeze
      DEFAULT_SENSITIVE_HEADERS = %w[
        Authorization
        X-Xsrf-Token
      ].freeze

      private_constant :DEFAULT_SENSITIVE_HEADERS

      def initialize(config)
        @fields = config.fields || []
        @http_headers = config.http_headers || false
        @do_cookies = config.cookies || false
      end

      def call(event)
        if event.is_a?(Sentry::Event)
          sanitize_request(event, :object) if event.request
          event.extra = sanitize_data(event.extra)
        elsif event.is_a?(Hash)
          sanitize_request(event, :stringified_hash) if event['request']
          sanitize_request(event, :symbolized_hash) if event[:request]
          event['extra'] = sanitize_data(event['extra']) if event['extra']
          event[:extra] = sanitize_data(event[:extra]) if event[:extra]
        end
      end

      def sanitize_request(event, type)
        case type
        when :object
          event.request.data = sanitize_data(event.request.data)
          event.request.headers = sanitize_headers(event.request.headers)
          event.request.cookies = sanitize_cookies(event.request.cookies)
        when :stringified_hash
          event['request']['data'] = sanitize_data(event['request']['data'])
          event['request']['headers'] = sanitize_headers(event['request']['headers'])
          event['request']['cookies'] = sanitize_cookies(event['request']['cookies'])
        when :symbolized_hash
          event[:request][:data] = sanitize_data(event[:request][:data])
          event[:request][:headers] = sanitize_headers(event[:request][:headers])
          event[:request][:cookies] = sanitize_cookies(event[:request][:cookies])
        end
      end

      def sanitize_data(hash)
        return hash unless hash.is_a? Hash
        return hash unless fields.size.positive?

        sanitize_value(hash, nil)
      end

      private

      attr_reader :fields, :http_headers, :do_cookies

      # Sanitize specified headers
      def sanitize_headers(headers)
        case headers
        when TrueClass
          headers.transform_values { DEFAULT_MASK }
        when Hash
          return headers unless http_headers.size.positive?

          headers.keys.select { |key| key.match?(sensitive_headers) }.each do |key|
            headers[key] = DEFAULT_MASK
          end

          headers
        else
          headers
        end
      end

      # Sanitize all cookies
      def sanitize_cookies(cookies)
        return cookies unless cookies.is_a? Hash
        return cookies unless do_cookies

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
