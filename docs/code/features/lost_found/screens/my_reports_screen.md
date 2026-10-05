# lib/features/lost_found/screens/my_reports_screen.dart

## Purpose
Aggregates everything the student has reported (lost/found) plus every claim that concerns them, surfacing anything requiring action first.

## Key members
- `MyReportsScreen` (ConsumerWidget) — reads `myClaimsProvider`, `myLostItemsProvider`, `myFoundItemsProvider`; partitions claims into `needsMyDecision` (pending claims on the user's finds), `mine` (the user's own unsettled claims), and `handovers` (approved claims awaiting mutual confirmation). Renders sections in priority order: Waiting for you → Handover → Your claims → Things you lost → Things you found.
- `_DecisionCard` (ConsumerStatefulWidget) — lets the finder approve or reject a claim; rejection opens `_RejectDialog` to collect a reason; calls `lostFoundRepository.decideClaim`.
- `_RejectDialog` — simple text-input dialog for a rejection reason (defaults to "No reason given").
- `_HandoverCard` (ConsumerWidget) — each side confirms the item physically changed hands via `confirmHandover`; shows a waiting state once the viewer has confirmed.
- `_ClaimStatusCard` — read-only status tile for the claimant's own claims (approved/rejected/pending), showing the rejection reason if declined.

## Dependencies & relationships
Uses `lost_found_providers.dart`, `Claim`/`ClaimStatus` models, `auth_providers.dart` for uid, `FoundItemCard` widget, and `Routes` for navigating into lost/found detail screens. Sits downstream of report and claim flows — this is where claim decisions and handovers are actually executed.

## Notable behavior / gotchas
Claims waiting on the user's decision are placed first because, per the file's doc comment, they're the only thing blocking someone else getting their item back. Handover confirmation (`_HandoverCard`) replaces a pickup OTP — see the referenced note on `LostFoundRepository.confirmHandover`. The screen shows a single "nothing reported" empty state only when claims, lost items, and found items are all empty.
