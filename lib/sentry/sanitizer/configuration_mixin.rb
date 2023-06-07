# frozen_string_literal: true

module Sentry
  module Sanitizer
    module ConfigurationMixin
      # Allow adding multiple hooks for this extension
      #
      # @param [nil, false, #call] value
      #
      def before_send=(value)
        raise ArgumentError, "before_send must be callable (or false to disable)" unless value.nil? || value == false || value.respond_to?(:call)

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
    end
  end
end
