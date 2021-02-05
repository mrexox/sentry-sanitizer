require 'sentry/configuration'
require 'sentry/sanitizer/cleaner'

module Sentry
  # Monkey-patching Sentry::Configuration
  class Configuration
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
      }
    end

    def sanitize
      @sanitize ||= Sentry::Sanitizer::Configuration.new
    end

    def sanitize_fields=(fields)
      unless fields.is_a? Array
        raise ArgumentError, 'sanitize_fields must be array'
      end

      sanitize.fields = fields
    end

    def sanitize_http_headers=(headers)
      unless headers.is_a? Array
        raise ArgumentError, 'sanitize_http_headers must be array'
      end

      sanitize.http_headers = headers
    end

    def sanitize_cookies=(cookies)
      unless [TrueClass, FalseClass].include?(cookies.class)
        raise ArgumentError, 'sanitize_cookies must be boolean'
      end

      sanitize.cookies = cookies
    end

    add_post_initialization_callback do
      self.before_send = Sentry::Sanitizer::Cleaner::HOOK if sanitize.configured?
    end
  end

  module Sanitizer
    class Configuration
      attr_accessor :fields, :http_headers, :cookies

      def configured?
        [fields, http_headers, cookies].any? { |setting| !setting.nil? }
      end
    end
  end
end
