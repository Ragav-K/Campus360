# lib/core/utils/formatters.dart

## Purpose
Shared text-formatting helpers for dates/times, relative time, countdowns, greetings, name display, and file sizes.

## Key members
- `Fmt` (abstract final class):
  - `relative(DateTime, {now})` — human-friendly relative time ("just now", "12 min ago", "3 h ago", "Yesterday", "3 days ago", or a date).
  - `expiresIn(Duration)` — countdown text for expiries.
  - `dateTime`/`date`/`time` — `intl`-based formatted strings.
  - `greeting([now])` — time-of-day greeting ("Good morning/afternoon/evening").
  - `firstName(String)` — extracts first name from a full display name.
  - `fileSize(int)` — bytes formatted as B/KB/MB.

## Dependencies & relationships
Imports `intl`. Used broadly across UI (Pulse feed timestamps, Printout expiry/OTP countdowns, home greeting, profile display, document size display).

## Notable behavior / gotchas
`relative()` treats negative diffs (clock skew / server timestamp ahead of local clock) as "just now" rather than showing a negative duration.
