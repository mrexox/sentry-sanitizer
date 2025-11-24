[![CI](https://github.com/mrexox/sentry-sanitizer/actions/workflows/ci-linux.yml/badge.svg)](https://github.com/mrexox/sentry-sanitizer/actions/workflows/ci-linux.yml)
[![Gem Version](https://badge.fury.io/rb/sentry-sanitizer.svg)](https://badge.fury.io/rb/sentry-sanitizer)
[![Coverage Status](https://coveralls.io/repos/github/mrexox/sentry-sanitizer/badge.svg?branch=master)](https://coveralls.io/github/mrexox/sentry-sanitizer?branch=master)

# sentry-sanitizer: sanitizing extension for sentry-ruby

This gem aimed to add sanitizing support to [sentry-ruby](https://rubygems.org/gems/sentry-ruby) gem.

[sentry-raven](https://rubygems.org/gems/sentry-raven) gem had this apportunity but it is no longer supported. Moving from `sentry-raven` to `sentry-ruby` can surprise you with missing this ability. But you can still use `sentry-sanitizer` (with a little change to configuration).

Currently this gem provides following features
- [x] Sanitizing POST params
- [x] Sanitizing HTTP headers
- [x] Sanitizing cookies
- [x] Sanitizing query string
- [x] Sanitizing extras ([see](https://docs.sentry.io/platforms/ruby/enriching-events/context/#additional-data) `Sentry.set_extras`)
- [x] Sanitizing breadcrumb data fields

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sentry-sanitizer', '>= 0.2.0'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sentry-sanitizer

## Usage

Add following lines to your Sentry configuration:

```ruby
Sentry.init do |config|
  # ... your configuration

  # If using Rails
  config.sanitize.fields = Rails.application.config.filter_parameters

  # You can also pass custom array
  config.sanitize.fields = %w[password super_secret_token]

  # HTTP headers can be sanitized too (it is case insensitive)
  config.sanitize.http_headers = %w[Authorization X-Xsrf-Token]

  # You can sanitize all HTTP headers with setting `true` value
  config.sanitize.http_headers = true

  # You can sanitize all cookies with this setting
  config.sanitize.cookies = true

  # You can sanitize query string params for GET requests
  config.sanitize.query_string = true

  # Sanitize breadcrumbs data[:body] payload (Setry::Net:HTTP)
  config.sanitize.breadcrumbs.json_data_fields = [:body]

  # ...
end
```

## Development hints

Install dependencies

    $ bin/setup

Experiment with the code in IRB

    $ bin/console

Run tests

    $ bin/rake test

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mrexox/sentry-sanitizer/issues.

## License

The gem is available as open source under the terms of the [BSD-3-Clause License](https://opensource.org/licenses/BSD-3-Clause).
