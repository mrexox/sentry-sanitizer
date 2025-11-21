# frozen_string_literal: true

RSpec.describe Sentry::Sanitizer::Configuration do
  subject(:config) { described_class.new }

  it { is_expected.not_to be_configured }

  it "adds #sanitize option to Sentry::Configuration" do
    sentry_config = Sentry::Configuration.new

    expect(sentry_config.sanitize).to be_a(described_class)
  end

  context "fields" do
    it "is properly configured" do
      config.fields = %i[a b]

      is_expected.to be_configured
      expect(config.fields).to match_array(%i[a b])
    end

    it "raises error on mistake" do
      expect { config.fields = :a }.to raise_error(ArgumentError)
    end
  end

  context "http_headers" do
    it "is properly configured" do
      config.http_headers = %w[HEADER1 HEADER2]

      is_expected.to be_configured
      expect(config.http_headers).to match_array(%w[HEADER1 HEADER2])

      config.http_headers = true

      is_expected.to be_configured
      expect(config.http_headers).to eq true
    end

    it "raises error on mistake" do
      expect { config.http_headers = :a }.to raise_error(ArgumentError)
    end
  end

  context "cookies" do
    it "is property configured" do
      config.cookies = true

      is_expected.to be_configured
      expect(config.cookies).to eq true
    end

    it "raises error on mistake" do
      expect { config.cookies = :a }.to raise_error(ArgumentError)
    end
  end

  context "query_string" do
    it "is property configured" do
      config.query_string = true

      is_expected.to be_configured
      expect(config.query_string).to eq true
    end

    it "raises error on mistake" do
      expect { config.query_string = :a }.to raise_error(ArgumentError)
    end
  end

  context "breadcrumbs.json_data_fields" do
    it "is property configured" do
      config.breadcrumbs.json_data_fields = [:body]

      is_expected.to be_configured
      expect(config.breadcrumbs.json_data_fields).to eq [:body]
    end

    it "raises error on mistake" do
      expect { config.breadcrumbs.json_data_fields = :a }.to raise_error(ArgumentError)
    end
  end
end
