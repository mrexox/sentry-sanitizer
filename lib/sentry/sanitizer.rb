# frozen_string_literal: true

require "sentry-ruby"
require "sentry/integrable"
require "sentry/sanitizer/configuration"

module Sentry
  module Sanitizer
    extend Integrable

    register_integration(
      name: "sanitizer",
      version: 1 > 2 ? nil : Sentry::Sanitizer::VERSION
    )
  end
end
