# frozen_string_literal: true

require "json"

# sentry-ruby >= 7 introduced its own unconditional PII denylist that masks certain
# header/cookie/query keys (auth, token, secret, session, password, cookie, etc.) as
# "[Filtered]" before our before_send/before_breadcrumb hooks ever run. Fields this
# gem's own sanitize config targets are still masked deterministically with our own
# mask; values we're not asked to touch may now arrive already filtered by Sentry
# itself, so specs accept either the original raw value or Sentry's native marker.
SENTRY_7_OR_NEWER = Gem::Version.new(Sentry::VERSION) >= Gem::Version.new("7.0")
SENTRY_NATIVE_MASK = "[Filtered]"

RSpec.describe Sentry::Sanitizer::Cleaner do
  def raw_or_natively_filtered(value)
    return eq(value) unless SENTRY_7_OR_NEWER

    satisfy("be #{value.inspect} or natively filtered by sentry-ruby") do |actual|
      [value, SENTRY_NATIVE_MASK].include?(actual)
    end
  end

  let(:parameter_filter) { ActiveSupport::ParameterFilter.new(%i[passw token code]) }

  describe "event" do
    let(:event) do
      Sentry::Event.new(configuration: Sentry.configuration).tap do |e|
        e.extra = ({ password: "SECRET", not_password: "NOT SECRET" })
      end
    end

    shared_context "GET request" do
      let(:sanitize_filter) { nil }
      let(:extra_params) { {} }

      before do
        Sentry.init do |config|
          if sanitize_filter
            config.sanitize.filter = sanitize_filter
          else
            config.sanitize.fields = [:password, "token"]
          end
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
                                      }.merge(extra_params),
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

    shared_context "POST request" do
      let(:sanitize_filter) { nil }
      let(:extra_params) { {} }

      before do
        Sentry.init do |config|
          if sanitize_filter
            config.sanitize.filter = sanitize_filter
          else
            config.sanitize.fields = [:password, "secret_token"]
          end
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
                                      }.merge(extra_params),
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
    end

    describe "Sentry::Event" do
      subject { described_class.new(Sentry.configuration.sanitize).call(event) }

      context "without a request" do
        before do
          Sentry.init do |config|
            config.sanitize.fields = [:password]
          end
        end

        it "clears extra fields" do
          subject

          expect(event.extra).to match a_hash_including(
            password: Sentry::Sanitizer::Filter::DEFAULT_MASK,
            not_password: "NOT SECRET"
          )
        end
      end

      context "GET request" do
        include_context "GET request"

        context "when query_string set to false" do
          before do
            Sentry.get_current_client.configuration.sanitize.query_string = false
          end

          it "doesn't clean query_string" do
            subject

            if SENTRY_7_OR_NEWER
              # sentry-ruby >= 7 parses query_string into a Hash and applies its own
              # native denylist to top-level keys before our sanitizer would run.
              expect(event.request.query_string).to eq(
                "password" => SENTRY_NATIVE_MASK,
                "token" => SENTRY_NATIVE_MASK,
                "nonsecure" => "NONESECURE",
                "nested" => [{ "password" => "SECRET", "login" => "LOGIN" }]
              )
            else
              expect(event.request.query_string)
                .to eq "password=SECRET&token=SECRET&nonsecure=NONESECURE" \
                       "&nested[][password]=SECRET&nested[][login]=LOGIN"
            end
          end
        end
      end

      context "POST request" do
        include_context "POST request"

        it "filters everything according to configuration" do
          subject

          expect(event.request.data).to match a_hash_including(
            "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
            "secret_token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
            "oops" => "OOPS",
            "hmm" => [
              a_hash_including(
                "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "array" => "too"
              )
            ]
          )
          expect(event.request.headers).to match a_hash_including(
            "H-1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
            "H-2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
            "H-3" => "secret3",
            "Authorization" => raw_or_natively_filtered("token"),
            "X-Xsrf-Token" => raw_or_natively_filtered("xsrf=token")
          )
          expect(event.request.cookies).to match a_hash_including(
            "cookie1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
            "cookie2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
            "cookie3" => Sentry::Sanitizer::Filter::DEFAULT_MASK
          )
          expect(event.extra).to match a_hash_including(
            password: Sentry::Sanitizer::Filter::DEFAULT_MASK,
            not_password: "NOT SECRET"
          )
        end

        context "with Sentry::ErrorEvent" do
          let(:event) do
            Sentry::ErrorEvent.new(configuration: Sentry.configuration).tap do |e|
              e.extra = ({ password: "SECRET", not_password: "NOT SECRET" })
            end
          end

          it "filters everything according to configuration" do
            subject

            expect(event.request.data).to match a_hash_including(
              "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "secret_token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "oops" => "OOPS",
              "hmm" => [
                a_hash_including(
                  "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                  "array" => "too"
                )
              ]
            )
            expect(event.request.headers).to match a_hash_including(
              "H-1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "H-2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "H-3" => "secret3",
              "Authorization" => raw_or_natively_filtered("token"),
              "X-Xsrf-Token" => raw_or_natively_filtered("xsrf=token")
            )
            expect(event.request.cookies).to match a_hash_including(
              "cookie1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "cookie2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "cookie3" => Sentry::Sanitizer::Filter::DEFAULT_MASK
            )
            expect(event.extra).to match a_hash_including(
              password: Sentry::Sanitizer::Filter::DEFAULT_MASK,
              not_password: "NOT SECRET"
            )
          end
        end

        context "cleaning all headers" do
          before do
            Sentry.get_current_client.configuration.sanitize.http_headers = true
          end

          it "filters everything according to configuration" do
            subject

            expect(event.request.headers).to match a_hash_including(
              "H-1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "H-2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "H-3" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "Authorization" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "X-Xsrf-Token" => Sentry::Sanitizer::Filter::DEFAULT_MASK
            )
          end
        end

        context "with custom filter" do
          let(:sanitize_filter) { parameter_filter }
          let(:extra_params) { { "confirmation_password" => "SECRET", "access_token" => "SECRET" } }

          it "filters data with given filter" do
            subject

            expect(event.request.data).to match a_hash_including(
              "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "secret_token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "confirmation_password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "access_token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "oops" => "OOPS",
              "hmm" => [
                a_hash_including(
                  "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                  "array" => "too"
                )
              ]
            )
            expect(event.request.headers).to match a_hash_including(
              "H-1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "H-2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "H-3" => "secret3"
            )
            expect(event.request.cookies).to match a_hash_including(
              "cookie1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "cookie2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "cookie3" => Sentry::Sanitizer::Filter::DEFAULT_MASK
            )
            # ParameterFilter matches partially, so "not_password" is masked too
            expect(event.extra).to match a_hash_including(
              password: Sentry::Sanitizer::Filter::DEFAULT_MASK,
              not_password: Sentry::Sanitizer::Filter::DEFAULT_MASK
            )
          end
        end
      end
    end

    describe "Sentry::Event.to_h" do
      subject { described_class.new(Sentry.configuration.sanitize).call(event_h) }
      let(:event_h) { event.to_h }

      context "POST request" do
        include_context "POST request"

        it "filters everything according to configuration" do
          subject

          expect(event_h).to match a_hash_including(
            request: a_hash_including(
              data: a_hash_including(
                "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "secret_token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "oops" => "OOPS",
                "hmm" => [
                  a_hash_including(
                    "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                    "array" => "too"
                  )
                ]
              ),
              headers: a_hash_including(
                "H-1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "H-2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "H-3" => "secret3",
                "Authorization" => raw_or_natively_filtered("token"),
                "X-Xsrf-Token" => raw_or_natively_filtered("xsrf=token")
              ),
              cookies: a_hash_including(
                "cookie1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "cookie2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "cookie3" => Sentry::Sanitizer::Filter::DEFAULT_MASK
              )
            ),
            extra: a_hash_including(
              password: Sentry::Sanitizer::Filter::DEFAULT_MASK,
              not_password: "NOT SECRET"
            )
          )
        end

        context "without configuration" do
          before do
            Sentry.get_current_client.configuration.instance_eval do
              @sanitize = Sentry::Sanitizer::Configuration.new
            end
          end

          it "should not filter anything" do
            subject

            expect(event_h).to match a_hash_including(
              request: a_hash_including(
                data: a_hash_including(
                  "password" => raw_or_natively_filtered("SECRET"),
                  "secret_token" => raw_or_natively_filtered("SECRET"),
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
                  "Authorization" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                  "X-Xsrf-Token" => Sentry::Sanitizer::Filter::DEFAULT_MASK
                ),
                cookies: a_hash_including(
                  "cookie1" => raw_or_natively_filtered("wooo"),
                  "cookie2" => raw_or_natively_filtered("weee"),
                  "cookie3" => raw_or_natively_filtered("WoWoW")
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
    end

    describe "Sentry::Event.to_h (stringified keys)" do
      subject { described_class.new(Sentry.configuration.sanitize).call(event_h) }
      let(:event_h) { JSON.parse(event.to_h.to_json) }

      context "GET request" do
        include_context "GET request"

        it "cleans all fields including query string" do
          subject

          expected_query_string =
            if SENTRY_7_OR_NEWER
              # sentry-ruby >= 7 represents query_string as a Hash; our sanitizer
              # still masks it deeply by field name, same as the legacy string form.
              {
                "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "nonsecure" => "NONESECURE",
                "nested" => [{ "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK, "login" => "LOGIN" }]
              }
            else
              "password=[FILTERED]&token=[FILTERED]&nonsecure=NONESECURE&nested[][password]=[FILTERED]&nested[][login]=LOGIN"
            end

          expect(event_h).to match a_hash_including(
            "request" => a_hash_including(
              "headers" => a_hash_including(
                "Custom-header" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "Custom-nonsecure" => "NONSECURE",
                "Authorization" => raw_or_natively_filtered("token"),
                "X-Xsrf-Token" => raw_or_natively_filtered("xsrf=token")
              ),
              "cookies" => a_hash_including(
                "cookie1" => raw_or_natively_filtered("wooo"),
                "cookie2" => raw_or_natively_filtered("weee"),
                "cookie3" => raw_or_natively_filtered("WoWoW")
              ),
              "query_string" => expected_query_string
            ),
            "extra" => a_hash_including(
              "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "not_password" => "NOT SECRET"
            )
          )
        end

        context "with custom filter" do
          let(:sanitize_filter) { parameter_filter }
          let(:extra_params) { { "confirmation_password" => "SECRET", "access_token" => "SECRET", "code" => "SECRET" } }

          it "cleans query string with given filter" do
            subject

            expected_query_string =
              if SENTRY_7_OR_NEWER
                {
                  "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                  "token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                  "nonsecure" => "NONESECURE",
                  "nested" => [{ "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK, "login" => "LOGIN" }],
                  "confirmation_password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                  "access_token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                  "code" => Sentry::Sanitizer::Filter::DEFAULT_MASK
                }
              else
                "password=[FILTERED]&token=[FILTERED]&nonsecure=NONESECURE&nested[][password]=[FILTERED]&nested[][login]=LOGIN" \
                  "&confirmation_password=[FILTERED]&access_token=[FILTERED]&code=[FILTERED]"
              end

            expect(event_h).to match a_hash_including(
              "request" => a_hash_including(
                "headers" => a_hash_including(
                  "Custom-header" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                  "Custom-nonsecure" => "NONSECURE"
                ),
                "query_string" => expected_query_string
              ),
              "extra" => a_hash_including(
                "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "not_password" => Sentry::Sanitizer::Filter::DEFAULT_MASK
              )
            )
          end
        end
      end

      context "POST request" do
        include_context "POST request"

        it "filters everything according to configuration" do
          subject

          expect(event_h).to match a_hash_including(
            "request" => a_hash_including(
              "data" => a_hash_including(
                "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "secret_token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "oops" => "OOPS",
                "hmm" => [
                  a_hash_including(
                    "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                    "array" => "too"
                  )
                ]
              ),
              "headers" => a_hash_including(
                "H-1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "H-2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "H-3" => "secret3",
                "Authorization" => raw_or_natively_filtered("token"),
                "X-Xsrf-Token" => raw_or_natively_filtered("xsrf=token")
              ),
              "cookies" => a_hash_including(
                "cookie1" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "cookie2" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
                "cookie3" => Sentry::Sanitizer::Filter::DEFAULT_MASK
              )
            ),
            "extra" => a_hash_including(
              "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
              "not_password" => "NOT SECRET"
            )
          )
        end
      end

      context "when special mask provided" do
        include_context "GET request"

        let(:mask) { "<<SECRET>>" }

        before do
          Sentry.get_current_client.configuration.sanitize.tap do |sanitize|
            sanitize.cookies = true
            sanitize.mask = mask
          end
        end

        it "uses given mask" do
          subject

          expected_query_string =
            if SENTRY_7_OR_NEWER
              {
                "password" => mask,
                "token" => mask,
                "nonsecure" => "NONESECURE",
                "nested" => [{ "password" => mask, "login" => "LOGIN" }]
              }
            else
              "password=#{mask}&token=#{mask}&nonsecure=NONESECURE&nested[][password]=#{mask}&nested[][login]=LOGIN"
            end

          expect(event_h).to match a_hash_including(
            "request" => a_hash_including(
              "headers" => a_hash_including(
                "Custom-header" => mask,
                "Custom-nonsecure" => "NONSECURE",
                "Authorization" => raw_or_natively_filtered("token"),
                "X-Xsrf-Token" => raw_or_natively_filtered("xsrf=token")
              ),
              "cookies" => a_hash_including(
                "cookie1" => mask,
                "cookie2" => mask,
                "cookie3" => mask
              ),
              "query_string" => expected_query_string
            ),
            "extra" => a_hash_including(
              "password" => mask,
              "not_password" => "NOT SECRET"
            )
          )
        end
      end
    end
  end

  describe "transaction event" do
    let(:event) do
      transaction = Sentry::Transaction.new(name: "test", op: "test")
      span = transaction.start_child(op: "http.client")
      span.set_data("password", "SECRET")
      span.set_data("nested", { "token" => "SECRET", "login" => "LOGIN" })
      span.set_data("url", "http://example.com")
      span.finish
      transaction.set_timestamp(Time.now.to_f)

      Sentry::TransactionEvent.new(configuration: Sentry.configuration, transaction: transaction)
    end

    let(:expected_span_data) do
      {
        "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
        "nested" => { "token" => Sentry::Sanitizer::Filter::DEFAULT_MASK, "login" => "LOGIN" },
        "url" => "http://example.com"
      }
    end

    before do
      Sentry.init do |config|
        config.sanitize.fields = %w[password token]
      end
    end

    it "filters spans data" do
      described_class.new(Sentry.configuration.sanitize).call(event)

      expect(event.spans.size).to eq(1)
      expect(event.spans.first[:data]).to match a_hash_including(expected_span_data)
    end

    it "filters spans data in Hash" do
      hash = event.to_h
      described_class.new(Sentry.configuration.sanitize).call(hash)

      expect(hash[:spans].first[:data]).to match a_hash_including(expected_span_data)
    end

    it "filters spans data in Hash with stringified keys" do
      hash = JSON.parse(JSON.dump(event.to_h))
      described_class.new(Sentry.configuration.sanitize).call(hash)

      expect(hash["spans"].first["data"]).to match a_hash_including(expected_span_data)
    end
  end

  describe "breadcrumb" do
    subject { described_class.new(Sentry.configuration.sanitize).call(breadcrumb) }

    context "without any sanitize configuration set" do
      let(:breadcrumb) { Sentry::Breadcrumb.new(message: "test", data: { body: nil }) }

      it "doesn't change breadcrumb" do
        expect { subject }.not_to(change { breadcrumb.to_h })
      end
    end

    context "with only sanitize fields configuration set" do
      let(:breadcrumb) { Sentry::Breadcrumb.new(message: "test") }

      before do
        Sentry.init do |config|
          config.sanitize.fields = ["password"]
        end
      end

      it "doesn't change breadcrumb" do
        expect { subject }.not_to(change { breadcrumb.to_h })
      end
    end

    context "with sanitize fields and breadcrumbs configuration set" do
      before do
        Sentry.init do |config|
          config.sanitize.fields = ["password"]
          config.sanitize.breadcrumbs.json_data_fields = [:body]
        end
      end

      context "when the field has a nil value" do
        let(:breadcrumb) { Sentry::Breadcrumb.new(message: "test", data: { body: nil }) }

        it "returns the breadcrumb data as is" do
          subject

          expect(breadcrumb.data).to eq({ body: nil })
        end
      end

      context "when the field has parseable JSON" do
        let(:breadcrumb) { Sentry::Breadcrumb.new(message: "test", data: { body: JSON.dump(password: "PASSWORD") }) }

        it "sanitizes the breadcrumb data" do
          subject

          expect(breadcrumb.data[:body]).to eq(JSON.dump(password: Sentry::Sanitizer::Filter::DEFAULT_MASK))
        end
      end

      context "when the field is something that is not parseable JSON" do
        let(:breadcrumb) { Sentry::Breadcrumb.new(message: "test", data: { body: "not parseable JSON" }) }

        it "returns the breadcrumb data as is" do
          subject

          expect(breadcrumb.data).to eq({ body: "not parseable JSON" })
        end
      end

      context "when the breadcrumb data is not a Hash" do
        let(:breadcrumb) { Sentry::Breadcrumb.new(message: "test", data: "just a string") }

        it "returns the breadcrumb data as is" do
          subject

          expect(breadcrumb.data).to eq("just a string")
        end
      end
    end

    context "with custom filter and breadcrumbs configuration set" do
      let(:breadcrumb) do
        Sentry::Breadcrumb.new(
          message: "test",
          data: {
            body: JSON.dump(
              password: "SECRET",
              confirmation_password: "SECRET",
              access_token: "SECRET",
              code: "SECRET",
              login: "LOGIN"
            )
          }
        )
      end

      before do
        Sentry.init do |config|
          config.sanitize.filter = parameter_filter
          config.sanitize.breadcrumbs.json_data_fields = [:body]
        end
      end

      it "sanitizes the breadcrumb data with given filter" do
        subject

        expect(JSON.parse(breadcrumb.data[:body])).to eq(
          "password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
          "confirmation_password" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
          "access_token" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
          "code" => Sentry::Sanitizer::Filter::DEFAULT_MASK,
          "login" => "LOGIN"
        )
      end
    end
  end
end
