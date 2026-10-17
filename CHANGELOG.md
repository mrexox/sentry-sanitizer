# Changelog

## 0.10.1

- Sanitize `Sentry::TransactionEvent#spans` [#27](https://github.com/mrexox/sentry-sanitizer/pull/27)

## 0.10.0

- Sanitize transaction events (`before_send_transaction`) and check-in events (`before_send_check_in`). Only `request` and `extra` are sanitized; span data is not
- Allow multiple `before_send_transaction` and `before_send_check_in` hooks
- Stop the `before_send` hook chain when a hook returns `nil`, so next hooks do not get `nil`

## 0.9.0

- Add `filter` option to pass a custom filter, e.g. `ActiveSupport::ParameterFilter` [#25](https://github.com/mrexox/sentry-sanitizer/pull/25)
- `filter` can't be combined with `fields` or `mask`

## 0.8.3

- Add Sentry 7 support [#24](https://github.com/mrexox/sentry-sanitizer/pull/24)

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
