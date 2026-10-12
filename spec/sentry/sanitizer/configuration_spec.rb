# frozen_string_literal: true

RSpec.describe Sentry::Sanitizer::Configuration do
  let(:config) { described_class.new }

  describe "#configured?" do
    subject { config }

    it { is_expected.not_to be_configured }
  end

  describe "Sentry::Configuration#sanitize" do
    subject { Sentry::Configuration.new.sanitize }

    it { is_expected.to be_a(described_class) }
  end

  describe "#fields=" do
    subject { config.fields = value }

    context "with array" do
      let(:value) { %i[a b] }

      it "is properly configured" do
        subject

        expect(config).to be_configured
        expect(config.fields).to match_array(%i[a b])
      end
    end

    context "with non-array" do
      let(:value) { :a }

      it "raises error" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end

    context "when filter already set" do
      let(:value) { [:password] }

      before do
        config.filter = ActiveSupport::ParameterFilter.new(%i[passw])
      end

      it "raises error" do
        expect { subject }.to raise_error(ArgumentError, /either 'fields' or 'filter'/)
      end
    end
  end

  describe "#filter=" do
    subject { config.filter = value }

    context "with ActiveSupport::ParameterFilter" do
      let(:value) { ActiveSupport::ParameterFilter.new(%i[passw token code]) }

      it "is properly configured" do
        subject

        expect(config).to be_configured
        expect(config.filter).to equal(value)
      end
    end

    context "with Sentry::Sanitizer::Filter" do
      let(:value) { Sentry::Sanitizer::Filter.new([:password]) }

      it "is properly configured" do
        subject

        expect(config).to be_configured
        expect(config.filter).to equal(value)
      end
    end

    context "with object missing filter methods" do
      let(:value) { Object.new }

      it "raises error" do
        expect { subject }.to raise_error(ArgumentError, /filter must implement/)
      end
    end

    context "when fields already set" do
      let(:value) { ActiveSupport::ParameterFilter.new(%i[passw]) }

      before do
        config.fields = [:password]
      end

      it "raises error" do
        expect { subject }.to raise_error(ArgumentError, /either 'fields' or 'filter'/)
      end
    end
  end

  describe "#http_headers=" do
    subject { config.http_headers = value }

    context "with array" do
      let(:value) { %w[HEADER1 HEADER2] }

      it "is properly configured" do
        subject

        expect(config).to be_configured
        expect(config.http_headers).to match_array(%w[HEADER1 HEADER2])
      end
    end

    context "with true" do
      let(:value) { true }

      it "is properly configured" do
        subject

        expect(config).to be_configured
        expect(config.http_headers).to eq true
      end
    end

    context "with invalid value" do
      let(:value) { :a }

      it "raises error" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#cookies=" do
    subject { config.cookies = value }

    context "with true" do
      let(:value) { true }

      it "is properly configured" do
        subject

        expect(config).to be_configured
        expect(config.cookies).to eq true
      end
    end

    context "with invalid value" do
      let(:value) { :a }

      it "raises error" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#query_string=" do
    subject { config.query_string = value }

    context "with true" do
      let(:value) { true }

      it "is properly configured" do
        subject

        expect(config).to be_configured
        expect(config.query_string).to eq true
      end
    end

    context "with invalid value" do
      let(:value) { :a }

      it "raises error" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#breadcrumbs.json_data_fields=" do
    subject { config.breadcrumbs.json_data_fields = value }

    context "with array" do
      let(:value) { [:body] }

      it "is properly configured" do
        subject

        expect(config).to be_configured
        expect(config.breadcrumbs.json_data_fields).to eq [:body]
      end
    end

    context "with invalid value" do
      let(:value) { :a }

      it "raises error" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end
end
