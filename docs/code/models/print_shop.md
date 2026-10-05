# lib/models/print_shop.dart

## Purpose
Models a print shop's profile: capabilities, pricing, open status, and queue length.

## Key members
- `PrintShop` class — fields `id`, `name`, `locationId`, `locationName`, `isOpen`, `estimatedWaitMinutes` (nullable), `supportsColour`, `supportsDuplex`, `paperSizes`, `bwPerPage`, `colourPerPage`, `currency`, `staffIds`, `queueCount`.
- `hasPricing`, `tone` (`StatusTone`), `statusLabel` getters.
- `PrintShop.fromMap(id, d)` factory — reads nested `services` and `pricing` maps from the document.

## Dependencies & relationships
Imports `enums/pulse_enums.dart` (`StatusTone`). Maps to the `printShops/{id}` Firestore collection. Used by `print_order.dart`'s `estimateCost` (via `bwPerPage`/`colourPerPage`) and the Printout feature's shop list/detail screens.

## Notable behavior / gotchas
`estimatedWaitMinutes` is null when the shop hasn't published a wait estimate — UI should show nothing rather than inventing a number. No `toMap`/`toCreateMap` present — this model appears read-only on the client (shop profiles likely managed by staff/admin tooling elsewhere).
