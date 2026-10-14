# frozen_string_literal: true

module Sentry
  module Sanitizer
    module ConfigurationMixin
      # Allow adding multiple hooks to `before_send`, so user hooks are not ignored.
      # Available since sentry-ruby 4.5.0
      #
      # @param [nil, #call] value
      #
      def before_send=(value)
        _check_callable!("before_send", value)

        return unless value

        @before_send_hook_list ||= []
        @before_send_hook_list << value

        @before_send = lambda { |event, hint|
          @before_send_hook_list.each do |hook|
            event = hook.call(event, hint)
            break unless event
          end

          event
        }
      end

      # Allow adding multiple hooks to `before_send_transaction`, so user hooks are not ignored.
      # Available since sentry-ruby 5.8.0
      #
      # @param [nil, #call] value
      #
      def before_send_transaction=(value)
        _check_callable!("before_send_transaction", value)

        return unless value

        @before_send_transaction_hook_list ||= []
        @before_send_transaction_hook_list << value

        @before_send_transaction = lambda { |event, hint|
          @before_send_transaction_hook_list.each do |hook|
            event = hook.call(event, hint)
            break unless event
          end

          event
        }
      end

      # Allow adding multiple hooks to `before_send_check_in`, so user hooks are not ignored.
      # Available since sentry-ruby 6.0.0
      #
      # @param [nil, #call] value
      #
      def before_send_check_in=(value)
        _check_callable!("before_send_check_in", value)

        return unless value

        @before_send_check_in_hook_list ||= []
        @before_send_check_in_hook_list << value

        @before_send_check_in = lambda { |event, hint|
          @before_send_check_in_hook_list.each do |hook|
            event = hook.call(event, hint)
            break unless event
          end

          event
        }
      end

      # Allow adding multiple hooks to `before_breadcrumb`, so user hooks are not ignored.
      # Available since sentry-ruby 4.5.0
      #
      # @param [nil, #call] value
      #
      def before_breadcrumb=(value)
        _check_callable!("before_breadcrumb", value)

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

      private

      def _check_callable!(hook, value)
        raise ArgumentError, "#{hook} must be callable (or nil to disable)" unless value.nil? || value == false || value.respond_to?(:call)
      end
    end
  end
end
