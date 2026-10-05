# lib/features/lost_found/screens/found_item_detail_screen.dart

## Purpose
Detail view for a single found-item report, letting a non-owner student submit a claim with proof text.

## Key members
- `FoundItemDetailScreen` (ConsumerWidget) — loads the item via `foundItemProvider(itemId)`, shows photo, category, description, location, found date, handover note, and reporter name. Shows one of: a notice if the viewer is the reporter, a "returned" notice, an "already claimed" notice, or a "This might be mine" button that opens the claim sheet.
- `_ClaimSheet` (StatefulWidget) — modal bottom sheet asking the claimant to describe a detail not visible in the public photo; requires at least 10 characters before submitting.
- `_startClaim` — orchestrates showing the sheet and calling `lostFoundRepository.claimFoundItem`.
- `_Fact`, `_Notice` — small presentational row/banner widgets.

## Dependencies & relationships
Uses `lost_found_providers.dart` (`foundItemProvider`, `myClaimsProvider`, `lostFoundRepositoryProvider`), `auth_providers.dart` for uid/current user, `FoundItem`/`FoundItemStatus` models, and shared widgets `AsyncValueView`, `CButton`. Part of the flow: Lost & Found home → found item card/match card → this screen → claim → My Reports screen for status tracking.

## Notable behavior / gotchas
The claim-proof requirement (minimum 10 characters) is a deliberate anti-abuse check — described in a comment as the only verification available without a server, since anyone could otherwise tap a bare "claim" button. Errors from the repository call are surfaced via `describeFailure` in a snackbar.
