# frozen_string_literal: true

RSpec.describe Sentry::Sanitizer do
  describe "VERSION" do
    subject { Sentry::Sanitizer::VERSION }

    it { is_expected.not_to be_nil }
  end
end
