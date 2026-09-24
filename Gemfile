# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in sentry-sanitizer.gemspec
gemspec

gem "sentry-ruby", ENV.fetch("SENTRY_VERSION", "~> 6.0")
# sentry-ruby requires "logger" internally but only declares it as a dependency
# itself from ~6.3.1/7.0 onwards; older sentry-ruby versions rely on it being a
# stdlib default gem, which Ruby 4.0 no longer bundles by default.
gem "logger"

gem "base64"
gem "cgi"
gem "rubocop", "~> 1.28.2"
gem "simplecov", require: false, group: :test

gem "bundler", ">= 2.3"
gem "rack"
gem "rake", "~> 12"
gem "rspec", "~> 3.0"
