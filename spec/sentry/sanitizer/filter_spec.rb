# frozen_string_literal: true

RSpec.describe Sentry::Sanitizer::Filter do
  let(:filter) { described_class.new(fields) }
  let(:fields) { [:password, "token"] }

  describe "#filter" do
    subject { filter.filter(params) }

    let(:params) do
      {
        "password" => "SECRET",
        "Token" => "SECRET",
        "login" => "LOGIN",
        "confirmation_password" => "SECRET",
        "nested" => {
          "password" => "SECRET",
          "list" => [{ "token" => "SECRET", "name" => "NAME" }]
        }
      }
    end

    it "masks matching keys deeply and case-insensitively" do
      expect(subject).to eq(
        "password" => described_class::DEFAULT_MASK,
        "Token" => described_class::DEFAULT_MASK,
        "login" => "LOGIN",
        "confirmation_password" => "SECRET",
        "nested" => {
          "password" => described_class::DEFAULT_MASK,
          "list" => [{ "token" => described_class::DEFAULT_MASK, "name" => "NAME" }]
        }
      )
    end

    it "modifies params in place" do
      expect(subject).to equal(params)
    end

    context "with symbol keys" do
      let(:params) { { password: "SECRET", login: "LOGIN" } }

      it "masks matching keys" do
        expect(subject).to eq(password: described_class::DEFAULT_MASK, login: "LOGIN")
      end
    end

    context "with frozen params" do
      let(:params) { { "password" => "SECRET", "list" => [{ "token" => "SECRET" }].freeze }.freeze }

      it "returns a new masked copy" do
        expect(subject).to eq(
          "password" => described_class::DEFAULT_MASK,
          "list" => [{ "token" => described_class::DEFAULT_MASK }]
        )
        expect(subject).not_to equal(params)
        expect(params["password"]).to eq "SECRET"
      end
    end

    context "with non-string values" do
      let(:params) { { "age" => 5, "login" => "LOGIN" } }

      it "masks them" do
        expect(subject).to eq("age" => described_class::DEFAULT_MASK, "login" => "LOGIN")
      end
    end

    context "with custom mask" do
      let(:filter) { described_class.new(fields, mask: "<<SECRET>>") }

      it "uses given mask" do
        expect(subject).to include("password" => "<<SECRET>>", "Token" => "<<SECRET>>", "login" => "LOGIN")
      end
    end

    context "with empty fields" do
      let(:fields) { [] }

      it "returns params as is" do
        expect { subject }.not_to(change { params.dup })
        expect(subject).to equal(params)
      end
    end

    context "with nil fields" do
      let(:fields) { nil }

      it "returns params as is" do
        expect { subject }.not_to(change { params.dup })
        expect(subject).to equal(params)
      end
    end
  end

  describe "#filter_param" do
    subject { filter.filter_param(key, value) }

    let(:value) { "SECRET" }

    context "with matching key" do
      let(:key) { "password" }

      it { is_expected.to eq described_class::DEFAULT_MASK }
    end

    context "with not matching key" do
      let(:key) { "login" }

      it { is_expected.to eq "SECRET" }
    end

    context "with nested value" do
      let(:key) { "nested" }
      let(:value) { { "token" => "SECRET", "login" => "LOGIN" } }

      it { is_expected.to eq("token" => described_class::DEFAULT_MASK, "login" => "LOGIN") }
    end

    context "with empty fields" do
      let(:fields) { [] }
      let(:key) { "password" }

      it { is_expected.to eq "SECRET" }
    end
  end
end
