# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sentry/sanitizer/version'

Gem::Specification.new do |spec|
  spec.name          = 'sentry-sanitizer'
  spec.version       = Sentry::Sanitizer::VERSION
  spec.authors       = ['Valentine Kiselev']
  spec.email         = ['mrexox@outlook.com']

  spec.summary       = %q{Sanitizing middleware for sentry-ruby gem}
  spec.description   = %q{Add missing sanitizing support for sentry-ruby (previous sentry-raven)}
  spec.homepage      = 'https://github.com/mrexox/sentry-sanitizer'
  spec.license       = 'BSD'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.require_paths = ['lib']

  # Codecov
  spec.add_development_dependency 'codecov'
  spec.add_development_dependency 'simplecov', '~> 0.18.5'

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rack'

  spec.add_runtime_dependency 'sentry-ruby', '~> 4.3.0'
end
