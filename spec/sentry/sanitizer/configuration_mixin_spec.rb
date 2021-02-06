RSpec.describe Sentry::Sanitizer::ConfigurationMixin do
  let(:i1) { double('check') }
  let(:i2) { double('check') }
  let(:i3) { double('check') }

  it 'makes before_send summing up the hooks' do
    Sentry.init do |config|
      config.before_send = ->(_, _) { i1.check }
      config.before_send = ->(_, _) { i2.check }
      config.before_send = ->(_, _) { i3.check }
    end

    expect(i1).to receive(:check)
    expect(i2).to receive(:check)
    expect(i3).to receive(:check)

    Sentry.configuration.before_send.call(nil, nil)
  end

  it 'raises ArgumentError if non-proc assigned' do
    expect { Sentry.init { |c| c.before_send = 1 } }.to raise_error(ArgumentError)
  end
end
