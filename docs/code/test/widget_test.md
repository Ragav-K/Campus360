# test/widget_test.dart

## Purpose
Tests `lib/core/utils/validators.dart` (`Validators`) and `lib/core/errors/app_failure.dart` (`AppFailure`) — pure validation logic for email, password, page-range, and OTP input, plus the retryability flag on app failures. Despite the filename (the default Flutter widget-test name), this file contains no widget tests; a comment notes real widget tests arrive later with a fake-Firebase harness.

## Test cases
- **Validators.email**
  - rejects malformed addresses (empty, no `@`, no TLD); accepts a well-formed address.
  - enforces an `allowedDomains` allowlist, including subdomains (`cs.college.edu` matches `college.edu`).
  - accepts any domain when none are configured.
  - `kpriet.ac.in lock` subgroup: accepts college addresses and departmental subdomains; rejects outside addresses; rejects lookalike domains (`kpriet.ac.in.evil.com`, `notkpriet.ac.in`, `xkpriet.ac.in`) that a naive `contains`/`endsWith` check would wrongly accept; is case-insensitive; error message names the required domain.
- **Validators.password**: requires minimum length plus at least one letter and one digit.
- **Validators.pageRange**: accepts single pages, ranges, and comma lists; rejects reversed ranges, zero, out-of-bounds (`maxPage`), and non-numeric input.
- **Validators.otp**: requires exactly six digits; rejects shorter/longer/non-digit input.
- **AppFailure**: `permission` and `notFound` are marked non-retryable (hides "Try again" in UI); `offline` is retryable.

## Dependencies & relationships
Exercises `Validators` (static methods) and `AppFailure` directly. No mocks, fakes, or widget rendering despite the `flutter_test` import.

## Notable behavior / gotchas
The domain allowlist check is specifically guarded against lookalike-domain bypass (e.g. appending the real domain as a subdomain of an attacker domain, or prefixing/suffixing it) — a security-relevant edge case called out explicitly in the test comments.
