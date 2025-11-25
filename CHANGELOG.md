# Changelog

## 0.8.2

- Sanitize breadcrumb data only if it's a Hash [#22](https://github.com/mrexox/sentry-sanitizer/pull/22)

## 0.8.1

- Fix breadcrumb data[:body] == nil handling [#20](https://github.com/mrexox/sentry-sanitizer/pull/20)

## 0.8.0

- Add `breadcrumbs.json_data_fields` configuration option [#18](https://github.com/mrexox/sentry-sanitizer/pull/18)

## 0.7.0

- fix: filter extra even without request [#14](https://github.com/mrexox/sentry-sanitizer/pull/14)

## 0.5.0

- Bump `sentry-ruby` till the latest version

## 0.4.0

- Support `nil` instead of `false` in `before_send=` setting

## 0.3.0
- Update compatibility with sentry-rails 4.3 releases [#3](https://github.com/mrexox/sentry-sanitizer/pull/3)

## 0.2.1
- Rework header cleaning to adhere to documentation in readme and not crash without configuration [#1](https://github.com/mrexox/sentry-sanitizer/pull/1)
