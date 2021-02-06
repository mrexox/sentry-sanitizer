module Sentry
  module Sanitizer
    module ConfigurationMixin
      # Allow adding multiple hooks for this extension
      def before_send=(value)
        unless value == false || value.respond_to?(:call)
          raise ArgumentError, "before_send must be callable (or false to disable)"
        end

        return value if value == false

        @before_send_hook_list ||= []
        @before_send_hook_list << value

        @before_send = ->(event, hint) {
          @before_send_hook_list.each do |hook|
            event = hook.call(event, hint)
          end

          event
        }
      end
    end
  end
end
