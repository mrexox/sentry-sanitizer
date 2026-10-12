# frozen_string_literal: true

RSpec.describe Sentry::Sanitizer::ConfigurationMixin do
  let(:callback) { double("callback") }

  before do
    allow(callback).to receive(:check)
  end

  describe "before_send=" do
    subject { Sentry.configuration.before_send.call(nil, nil) }

    context "with several hooks" do
      before do
        Sentry.init do |config|
          config.before_send = ->(_, _) { callback.check }
          config.before_send = ->(_, _) { callback.check }
          config.before_send = ->(_, _) { callback.check }
        end
      end

      it "joins before_send hooks" do
        subject

        expect(callback).to have_received(:check).exactly(3).times
      end
    end

    context "with non-proc" do
      subject { Sentry.init { |c| c.before_send = 1 } }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "before_breadcrumb=" do
    subject { Sentry.configuration.before_breadcrumb.call(breadcrumb, nil) }

    let(:breadcrumb) { instance_double(Sentry::Breadcrumb) }

    context "with several hooks" do
      before do
        Sentry.init do |config|
          config.before_breadcrumb = lambda { |b, _|
            callback.check
            b
          }
          config.before_breadcrumb = lambda { |b, _|
            callback.check
            b
          }
          config.before_breadcrumb = lambda { |b, _|
            callback.check
            b
          }
        end
      end

      it "joins before_breadcrumb hooks" do
        subject

        expect(callback).to have_received(:check).exactly(3).times
      end
    end

    context "when hook returns nil" do
      before do
        Sentry.init do |config|
          config.before_breadcrumb = lambda { |b, _|
            callback.check
            b
          }
          config.before_breadcrumb = lambda { |_b, _|
            callback.check
            nil
          }
          # Not going to be called
          config.before_breadcrumb = lambda { |b, _|
            callback.check
            b
          }
          config.before_breadcrumb = lambda { |b, _|
            callback.check
            b
          }
          config.before_breadcrumb = lambda { |b, _|
            callback.check
            b
          }
          config.before_breadcrumb = lambda { |b, _|
            callback.check
            b
          }
        end
      end

      it "stops before_breadcrumb hooks" do
        subject

        expect(callback).to have_received(:check).exactly(2).times
      end
    end

    context "with non-proc" do
      subject { Sentry.init { |c| c.before_breadcrumb = 1 } }

      it "raises ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end
end
