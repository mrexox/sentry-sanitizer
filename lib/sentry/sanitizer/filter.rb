# frozen_string_literal: true

module Sentry
  module Sanitizer
    class Filter
      DEFAULT_MASK = "[FILTERED]"

      def initialize(fields, mask: nil)
        @filters = compile_filters(fields || [])
        @mask = mask || DEFAULT_MASK
      end

      def filter(params)
        filters.nil? ? params : sanitize_value(nil, params)
      end

      def filter_param(key, value)
        filters.nil? ? value : sanitize_value(key, value)
      end

      private

      attr_reader :mask, :filters

      def compile_filters(fields)
        return nil if fields.size.zero?

        Regexp.new(fields.map { |field| "\\b#{field}\\b" }.join("|"), "i")
      end

      def sanitize_value(key, value)
        return mask if key&.match?(filters)

        case value
        when Hash
          if value.frozen?
            value.merge(value) { |k, v| sanitize_value(k, v) }
          else
            value.merge!(value) { |k, v| sanitize_value(k, v) }
          end
        when Array
          if value.frozen?
            value.map { |v| sanitize_value(key, v) }
          else
            value.map! { |v| sanitize_value(key, v) }
          end
        when String
          value
        else
          mask
        end
      end
    end
  end
end
