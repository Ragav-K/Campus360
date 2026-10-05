# lib/core/utils/validators.dart

## Purpose
Form field validators following Flutter's convention (return `null` when valid, else an error string) for use in `TextFormField.validator`.

## Key members
- `Validators` (abstract final class):
  - `required(String?, {field})` — non-empty check.
  - `email(String?, {allowedDomains})` — format check plus optional college-domain restriction (domains sourced from runtime `config/app`).
  - `password(String?)` — minimum 8 chars, requires a letter and a number.
  - `confirmPassword(String?, String original)` — equality check.
  - `name(String?)` — non-empty, minimum length 2.
  - `pageRange(String?, {maxPage})` — validates print page-range syntax like "2-7" or "1,3,5-9".
  - `otp(String?)` — exactly 6 digits.

## Dependencies & relationships
No imports besides core Dart. Used by auth screens (login/register forms), printout's new-order screen (`pageRange`), and OTP entry (`otp`). `allowedDomains` parameter is typically populated from `RemoteConfig`/`AppConfig` fallback.

## Notable behavior / gotchas
`email()` domain matching allows exact match or subdomain match (`domain == clean || domain.endsWith('.$clean')`) and tailors its error message singular vs plural depending on how many allowed domains exist.
