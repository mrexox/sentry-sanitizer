# frozen_string_literal: true

require "json"
require "sentry/sanitizer/filter"

module Sentry
  module Sanitizer
    class Cleaner
      DEFAULT_SENSITIVE_HEADERS = %w[
        Authorization
        X-Xsrf-Token
      ].freeze

      private_constant :DEFAULT_SENSITIVE_HEADERS

      def initialize(config)
        @filter = config.filter || Filter.new(config.fields, mask: config.mask)

        @http_headers = config.http_headers || DEFAULT_SENSITIVE_HEADERS
        @headers_filter = Filter.new(@http_headers, mask: config.mask) if @http_headers.is_a?(Array)

        @do_cookies = config.cookies || false
        @do_query_string = config.query_string || false

        @mask = config.mask || Filter::DEFAULT_MASK

        @breadcrumbs_json_data_fields = config.breadcrumbs.json_data_fields || []
      end

      def call(event)
        case event
        when Sentry::Event
          sanitize_event!(event)
        when Hash
          sanitize_hash!(event)
        when Sentry::Breadcrumb
          sanitize_breadcrumb!(event)
        end
      end

      def sanitize_event!(event)
        if event.request
          event.request.data = sanitize_data(event.request.data)
          event.request.headers = sanitize_headers(event.request.headers)
          event.request.cookies = sanitize_cookies(event.request.cookies)
          event.request.query_string = sanitize_query_string(event.request.query_string)
        end
        event.extra = sanitize_data(event.extra)
      end

      def sanitize_hash!(event)
        if event["request"]
          event["request"]["data"] = sanitize_data(event["request"]["data"])
          event["request"]["headers"] = sanitize_headers(event["request"]["headers"])
          event["request"]["cookies"] = sanitize_cookies(event["request"]["cookies"])
          event["request"]["query_string"] = sanitize_query_string(event["request"]["query_string"])
        elsif event[:request]
          event[:request][:data] = sanitize_data(event[:request][:data])
          event[:request][:headers] = sanitize_headers(event[:request][:headers])
          event[:request][:cookies] = sanitize_cookies(event[:request][:cookies])
          event[:request][:query_string] = sanitize_query_string(event[:request][:query_string])
        end

        if event["extra"]
          event["extra"] = sanitize_data(event["extra"])
        elsif event[:extra]
          event[:extra] = sanitize_data(event[:extra])
        end
      end

      def sanitize_breadcrumb!(breadcrumb)
        return unless breadcrumbs_json_data_fields.size.positive?
        return unless breadcrumb.data.is_a? Hash

        breadcrumbs_json_data_fields.each do |field|
          next unless breadcrumb.data.key?(field)
          next if breadcrumb.data[field].nil?

          json_data = JSON.parse(breadcrumb.data[field])

          breadcrumb.data[field] = JSON.dump(sanitize_data(json_data))
        end
      rescue JSON::ParserError
        # ignore
      end

      def sanitize_data(hash)
        filter.filter(hash)
      end

      private

      attr_reader :filter,
                  :headers_filter,
                  :mask,
                  :http_headers,
                  :do_cookies,
                  :do_query_string,
                  :breadcrumbs_json_data_fields

      # Sanitize specified headers
      def sanitize_headers(headers)
        case http_headers
        when TrueClass
          headers.transform_values { mask }
        when Array
          headers_filter.filter(headers)
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

        case query_string
        when String
          sanitize_query_string_from_string(query_string)
        when Hash
          sanitize_data(query_string)
        else
          query_string
        end
      end

      # sentry-ruby >= 7 populates Request#query_string as a Hash (from Rack's
      # parsed request.GET) instead of the raw query string.
      def sanitize_query_string_from_string(query_string)
        sanitized_array = query_string.split("&").map do |kv_pair|
          k, v = kv_pair.split("=")
          new_v = filter.filter_param(k, v)

          "#{k}=#{new_v}"
        end

        sanitized_array.join("&")
      end
    end
  end
end
