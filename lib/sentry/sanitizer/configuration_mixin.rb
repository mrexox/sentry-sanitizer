# frozen_string_literal: true

module Sentry
  module Sanitizer
    module ConfigurationMixin
      # Allow adding multiple hooks to `before_send`, so user hooks are not ignored.
      #
      # @param [nil, #call] value
      #
      def before_send=(value)
        raise ArgumentError, "before_send must be callable (or nil to disable)" unless value.nil? || value == false || value.respond_to?(:call)

        return unless value

        @before_send_hook_list ||= []
        @before_send_hook_list << value

        @before_send = lambda { |event, hint|
          @before_send_hook_list.each do |hook|
            event = hook.call(event, hint)
          end

          event
        }
      end

      # Allow adding multiple hooks to `before_breadcrumb`, so user hooks are not ignored.
      #
      # @param [nil, #call] value
      #
      def before_breadcrumb=(value) # rubocop:disable Metrics/CyclomaticComplexity
        raise ArgumentError, "before_breadcrumb must be callable (or nil to disable)" unless value.nil? || value == false || value.respond_to?(:call)

        return unless value

        @before_breadcrumb_hook_list ||= []
        @before_breadcrumb_hook_list << value

        @before_breadcrumb = lambda { |breadcrumb, hint|
          @before_breadcrumb_hook_list.each do |hook|
            breadcrumb = hook.call(breadcrumb, hint)
            break unless breadcrumb
          end

          breadcrumb
        }
      end
    end
  end
end
