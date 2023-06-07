# frozen_string_literal: true

RSpec.describe Sentry::Sanitizer do
  it "has a version number" do
    expect(Sentry::Sanitizer::VERSION).not_to be nil
  end
end
