# frozen_string_literal: true

require "json"

RSpec.describe Sentry::Sanitizer::Cleaner do
  subject { described_class.new(configuration.sanitize) }

  let(:event) do
    Sentry::Event.new(configuration: configuration).tap do |e|
      e.extra = ({ password: "SECRET", not_password: "NOT SECRET" })
    end
  end

  let(:configuration) do
    Sentry.configuration
  end

  context "GET request" do
    before do
      Sentry.init do |config|
        config.sanitize.fields = [:password, "token"]
        config.sanitize.http_headers = ["Custom-Header"]
        config.sanitize.cookies = false
        config.sanitize.query_string = true
        config.send_default_pii = true
      end

      Sentry.get_current_scope.set_rack_env(
        Rack::MockRequest.env_for("/", {
                                    method: "GET",
                                    params: {
                                      "password" => "SECRET",
                                      "token" => "SECRET",
                                      "nonsecure" => "NONESECURE",
                                      "nested" => [{ "password" => "SECRET", "login" => "LOGIN" }]
                                    },
                                    "CONTENT_TYPE" => "application/json",
                                    "HTTP_CUSTOM-HEADER" => "secret1",
                                    "HTTP_CUSTOM-NONSECURE" => "NONSECURE",
                                    "HTTP_AUTHORIZATION" => "token",
                                    "HTTP_X_XSRF_TOKEN" => "xsrf=token",
                                    Rack::RACK_REQUEST_COOKIE_HASH => {
                                      "cookie1" => "wooo",
                                      "cookie2" => "weee",
                                      "cookie3" => "WoWoW"
                                    }
                                  })
      )

      Sentry.get_current_scope.apply_to_event(event)
    end
  end

  context "POST request" do
    before do
      Sentry.init do |config|
        config.sanitize.fields = [:password, "secret_token"]
        config.sanitize.http_headers = %w[H-1 H-2]
        config.sanitize.cookies = true
        config.send_default_pii = true
      end

      Sentry.get_current_scope.set_rack_env(
        Rack::MockRequest.env_for("/", {
                                    method: "POST",
                                    params: {
                                      "password" => "SECRET",
                                      "secret_token" => "SECRET",
                                      "oops" => "OOPS",
                                      "hmm" => [{ "password" => "SECRET", "array" => "too" }]
                                    },
                                    "CONTENT_TYPE" => "application/json",
                                    "HTTP_H-1" => "secret1",
                                    "HTTP_H-2" => "secret2",
                                    "HTTP_H-3" => "secret3",
                                    "HTTP_AUTHORIZATION" => "token",
                                    "HTTP_X_XSRF_TOKEN" => "xsrf=token",
                                    Rack::RACK_REQUEST_COOKIE_HASH => {
                                      "cookie1" => "wooo",
                                      "cookie2" => "weee",
                                      "cookie3" => "WoWoW"
                                    }
                                  })
      )

      Sentry.get_current_scope.apply_to_event(event)
    end

    context "cleaning all headers" do
      it "filters everything according to configuration" do
        Sentry.get_current_client.configuration.sanitize.http_headers = true
        subject.call(event)

        expect(event.request.headers).to match a_hash_including(
          "H-1" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "H-2" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "H-3" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "Authorization" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "X-Xsrf-Token" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK
        )
      end
    end
  end

  context "when special mask provided" do
    let(:mask) { "<<SECRET>>" }

    before do
      Sentry.init do |config|
        config.sanitize.fields = [:password, "token"]
        config.sanitize.http_headers = ["Custom-Header"]
        config.sanitize.cookies = true
        config.sanitize.query_string = true
        config.sanitize.mask = mask
        config.send_default_pii = true
      end

      Sentry.get_current_scope.set_rack_env(
        Rack::MockRequest.env_for("/", {
                                    method: "GET",
                                    params: {
                                      "password" => "SECRET",
                                      "token" => "SECRET",
                                      "nonsecure" => "NONESECURE",
                                      "nested" => [{ "password" => "SECRET", "login" => "LOGIN" }]
                                    },
                                    "CONTENT_TYPE" => "application/json",
                                    "HTTP_CUSTOM-HEADER" => "secret1",
                                    "HTTP_CUSTOM-NONSECURE" => "NONSECURE",
                                    "HTTP_AUTHORIZATION" => "token",
                                    "HTTP_X_XSRF_TOKEN" => "xsrf=token",
                                    Rack::RACK_REQUEST_COOKIE_HASH => {
                                      "cookie1" => "wooo",
                                      "cookie2" => "weee",
                                      "cookie3" => "WoWoW"
                                    }
                                  })
      )

      Sentry.get_current_scope.apply_to_event(event)
    end
  end
end
