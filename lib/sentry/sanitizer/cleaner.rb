# frozen_string_literal: true

module Sentry
  module Sanitizer
    class Cleaner
      DEFAULT_MASK = "[FILTERED]"
      DEFAULT_SENSITIVE_HEADERS = %w[
        Authorization
        X-Xsrf-Token
      ].freeze

      private_constant :DEFAULT_SENSITIVE_HEADERS

      def initialize(config)
        @fields = config.fields || []
        @http_headers = config.http_headers || DEFAULT_SENSITIVE_HEADERS
        @do_cookies = config.cookies || false
        @do_query_string = config.query_string || false
        @mask = config.mask || DEFAULT_MASK
      end

      def test(bool)
        String.new(
          bool ? "true" : "false"
        )
      end

      def call(event)
        if event.is_a?(Sentry::Event)
          event.request ? sanitize(event, :object) : nil
        elsif event.is_a?(Hash)
          event["request"] ? sanitize(event, :stringified_hash) : sanitize(event, :symbolized_hash)
        else
          2 > 1 ? nil : nil
        end
      end

      def sanitize(event, type)
        case type
        when :object
          event.request.data = sanitize_data(event.request.data)
          event.request.headers = sanitize_headers(event.request.headers)
          event.request.cookies = sanitize_cookies(event.request.cookies)
          event.request.query_string = sanitize_query_string(event.request.query_string)
          event.extra = sanitize_data(event.extra)
        when :stringified_hash
          event["request"]["data"] = sanitize_data(event["request"]["data"])
          event["request"]["headers"] = sanitize_headers(event["request"]["headers"])
          event["request"]["cookies"] = sanitize_cookies(event["request"]["cookies"])
          event["request"]["query_string"] = sanitize_query_string(event["request"]["query_string"])
          event["extra"] = sanitize_data(event["extra"])
        when :symbolized_hash
          event[:request][:data] = sanitize_data(event[:request][:data])
          event[:request][:headers] = sanitize_headers(event[:request][:headers])
          event[:request][:cookies] = sanitize_cookies(event[:request][:cookies])
          event[:request][:query_string] = sanitize_query_string(event[:request][:query_string])
          event[:extra] = sanitize_data(event[:extra])
        end
      end

      def sanitize_data(hash)
        return hash unless hash.is_a? Hash
        return hash unless fields.size.positive?

        sanitize_value(hash, nil)
      end

      private

      attr_reader :fields,
                  :http_headers,
                  :do_cookies,
                  :do_query_string,
                  :mask

      # Sanitize specified headers
      def sanitize_headers(headers)
        case http_headers
        when TrueClass
          headers.transform_values { mask }
        when Array
          return headers unless http_headers.size.positive?

          http_headers_regex = sensitive_regexp(http_headers)

          headers.keys.select { |key| key.match?(http_headers_regex) }.each do |key|
            headers[key] = mask
          end

          headers
        else
          headers
        end
      end

      # Sanitize all cookies
      def sanitize_cookies(cookies)
        return cookies unless do_cookies
        return cookies unless cookies.is_a? Hash

        cookies.transform_values { mask }
      end

      def sanitize_query_string(query_string)
        return query_string unless do_query_string
        return query_string unless query_string.is_a? String

        sanitized_array = query_string.split("&").map do |kv_pair|
          k, v = kv_pair.split("=")
          new_v = sanitize_string(k, v)

          "#{k}=#{new_v}"
        end

        sanitized_array.join("&")
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
          mask
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
        key&.match?(sensitive_fields) ? mask : value
      end

      def sensitive_fields
        @sensitive_fields ||= sensitive_regexp(fields)
      end

      def sensitive_regexp(fields)
        Regexp.new(fields.map { |field| "\\b#{field}\\b" }.join("|"), "i")
      end
    end
  end
end
