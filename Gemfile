# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in sentry-sanitizer.gemspec
gemspec

gem "sentry-ruby", ENV.fetch("SENTRY_VERSION", "~> 6.0")

gem "base64"
gem "cgi"
gem "rubocop", "~> 1.28.2"
gem "simplecov", require: false, group: :test

gem "bundler", ">= 2.3"
gem "rack"
gem "rake", "~> 12"
gem "rspec", "~> 3.0"
