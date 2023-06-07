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

    it "cleans all fields including query string" do
      event_h = JSON.parse(event.to_hash.to_json)
      subject.call(event_h)

      expect(event_h).to match a_hash_including(
        "request" => a_hash_including(
          "headers" => a_hash_including(
            "Custom-header" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
            "Custom-nonsecure" => "NONSECURE",
            "Authorization" => "token",
            "X-Xsrf-Token" => "xsrf=token"
          ),
          "cookies" => a_hash_including(
            "cookie1" => "wooo",
            "cookie2" => "weee",
            "cookie3" => "WoWoW"
          ),
          "query_string" => "password=[FILTERED]&token=[FILTERED]&nonsecure=NONESECURE&nested[][password]=[FILTERED]&nested[][login]=LOGIN"
        ),
        "extra" => a_hash_including(
          "password" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "not_password" => "NOT SECRET"
        )
      )
    end

    context "when query_string set to false" do
      it "doesn't clean query_string" do
        Sentry.get_current_client.configuration.sanitize.query_string = false
        subject.call(event)

        expect(event.request.query_string)
          .to eq "password=SECRET&token=SECRET&nonsecure=NONESECURE" \
                 "&nested[][password]=SECRET&nested[][login]=LOGIN"
      end
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

    context "with event as stringified Hash" do
      it "filters everything according to configuration" do
        event_h = JSON.parse(event.to_hash.to_json)
        subject.call(event_h)

        expect(event_h).to match a_hash_including(
          "request" => a_hash_including(
            "data" => a_hash_including(
              "password" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "secret_token" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "oops" => "OOPS",
              "hmm" => [
                a_hash_including(
                  "password" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
                  "array" => "too"
                )
              ]
            ),
            "headers" => a_hash_including(
              "H-1" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "H-2" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "H-3" => "secret3",
              "Authorization" => "token",
              "X-Xsrf-Token" => "xsrf=token"
            ),
            "cookies" => a_hash_including(
              "cookie1" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "cookie2" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "cookie3" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK
            )
          ),
          "extra" => a_hash_including(
            "password" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
            "not_password" => "NOT SECRET"
          )
        )
      end
    end

    context "with event as symbolized Hash" do
      it "filters everything according to configuration" do
        event_h = event.to_hash
        subject.call(event_h)

        expect(event_h).to match a_hash_including(
          request: a_hash_including(
            data: a_hash_including(
              "password" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "secret_token" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "oops" => "OOPS",
              "hmm" => [
                a_hash_including(
                  "password" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
                  "array" => "too"
                )
              ]
            ),
            headers: a_hash_including(
              "H-1" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "H-2" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "H-3" => "secret3",
              "Authorization" => "token",
              "X-Xsrf-Token" => "xsrf=token"
            ),
            cookies: a_hash_including(
              "cookie1" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "cookie2" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "cookie3" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK
            )
          ),
          extra: a_hash_including(
            password: Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
            not_password: "NOT SECRET"
          )
        )
      end
    end

    context "with raw event" do
      it "filters everything according to configuration" do
        subject.call(event)

        expect(event.request.data).to match a_hash_including(
          "password" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "secret_token" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "oops" => "OOPS",
          "hmm" => [
            a_hash_including(
              "password" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "array" => "too"
            )
          ]
        )
        expect(event.request.headers).to match a_hash_including(
          "H-1" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "H-2" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "H-3" => "secret3",
          "Authorization" => "token",
          "X-Xsrf-Token" => "xsrf=token"
        )
        expect(event.request.cookies).to match a_hash_including(
          "cookie1" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "cookie2" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          "cookie3" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK
        )
        expect(event.extra).to match a_hash_including(
          password: Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
          not_password: "NOT SECRET"
        )
      end
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

    context "without configuration" do
      before do
        Sentry.get_current_client.configuration.instance_eval do
          @sanitize = Sentry::Sanitizer::Configuration.new
        end
      end

      it "should not filter anything" do
        event_h = event.to_hash
        subject.call(event_h)

        expect(event_h).to match a_hash_including(
          request: a_hash_including(
            data: a_hash_including(
              "password" => "SECRET",
              "secret_token" => "SECRET",
              "oops" => "OOPS",
              "hmm" => [
                a_hash_including(
                  "password" => "SECRET",
                  "array" => "too"
                )
              ]
            ),
            headers: a_hash_including(
              "H-1" => "secret1",
              "H-2" => "secret2",
              "H-3" => "secret3",
              "Authorization" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK,
              "X-Xsrf-Token" => Sentry::Sanitizer::Cleaner::DEFAULT_MASK
            ),
            cookies: a_hash_including(
              "cookie1" => "wooo",
              "cookie2" => "weee",
              "cookie3" => "WoWoW"
            )
          ),
          extra: a_hash_including(
            password: "SECRET",
            not_password: "NOT SECRET"
          )
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

    it "uses given mask" do
      event_h = JSON.parse(event.to_hash.to_json)
      subject.call(event_h)

      expect(event_h).to match a_hash_including(
        "request" => a_hash_including(
          "headers" => a_hash_including(
            "Custom-header" => mask,
            "Custom-nonsecure" => "NONSECURE",
            "Authorization" => "token",
            "X-Xsrf-Token" => "xsrf=token"
          ),
          "cookies" => a_hash_including(
            "cookie1" => mask,
            "cookie2" => mask,
            "cookie3" => mask
          ),
          "query_string" => "password=#{mask}&token=#{mask}&nonsecure=NONESECURE&nested[][password]=#{mask}&nested[][login]=LOGIN"
        ),
        "extra" => a_hash_including(
          "password" => mask,
          "not_password" => "NOT SECRET"
        )
      )
    end
  end
end
