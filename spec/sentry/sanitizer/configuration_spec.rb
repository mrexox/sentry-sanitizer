RSpec.describe Sentry::Sanitizer::Configuration do
  subject { described_class.new }

  it { is_expected.not_to be_configured }

  it 'adds #sanitize option to Sentry::Configuration' do
    config = Sentry::Configuration.new

    expect(config.sanitize).to be_a(described_class)
  end

  context 'configured fields' do
    it 'is properly configured' do
      subject.fields = [:a, :b]

      is_expected.to be_configured
      expect(subject.fields).to match_array([:a, :b])
    end

    it 'raises error on mistake' do
      expect { subject.fields = :a }.to raise_error(ArgumentError)
    end
  end

  context 'configured http_headers' do
    it 'is properly configured' do
      subject.http_headers = ['HEADER1', 'HEADER2']

      is_expected.to be_configured
      expect(subject.http_headers).to match_array(['HEADER1', 'HEADER2'])

      subject.http_headers = true

      is_expected.to be_configured
      expect(subject.http_headers).to eq true
    end

    it 'raises error on mistake' do
      expect { subject.http_headers = :a }.to raise_error(ArgumentError)
    end
  end

  context 'configured cookies' do
    it 'is property configured' do
      subject.cookies = true

      is_expected.to be_configured
      expect(subject.cookies).to eq true
    end

    it 'raises error on mistake' do
      expect { subject.cookies = :a }.to raise_error(ArgumentError)
    end
  end
end
