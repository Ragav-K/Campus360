# Lost & Found

Screens: `lib/features/lost_found/screens/{lost_found_home_screen,report_item_screen,found_item_detail_screen,my_reports_screen}.dart`
Widgets: `lib/features/lost_found/widgets/{found_item_card,match_card}.dart`
Providers: `lib/features/lost_found/providers/lost_found_providers.dart`
Matching: `lib/features/lost_found/matching.dart` (`ItemMatcher`, `ItemMatch`, `MatchSignals`)
Repository: `lib/repositories/lost_found_repository.dart`
Models: `lib/models/{lost_item,found_item,claim}.dart`, `lib/models/enums/lost_found_enums.dart`
Firestore: `lostItems/{id}` (+ `private/secret` subcollection), `foundItems/{id}`, `claims/{id}`

Lost & Found is the third tab (`Routes.lostFound`, `/lostfound`).

## Reporting a lost item

1. `ReportItemScreen(isLost: true)` (`Routes.reportLost`) collects category,
   description/keywords, optional location/time lost, an optional photo, and
   an **identifying detail** the real owner would know.
2. `LostFoundRepository.reportLost(item, identifyingDetails, photo)` uploads
   the photo (if any) to `StoragePaths.lostItemPhoto(uid, itemId)`, writes
   `lostItems/{id}`, and — only if identifying details were given — writes
   them into a `private/secret` subdocument that only the owner can read.
   This secret is later shown to the *finder* when judging a claim, so a
   claimant has to prove ownership rather than just click a button.

## Reporting a found item

3. `ReportItemScreen(isLost: false)` (`Routes.reportFound`) collects the same
   shape of data from the finder's side. `LostFoundRepository.reportFound`
   uploads the photo to `StoragePaths.foundItemPhoto(uid, itemId)` and
   writes `foundItems/{id}` with status `active`.
4. Found items are publicly browsable to all signed-in students via
   `openFoundItemsProvider` (`LostFoundRepository.watchOpenFoundItems()`,
   filtered to `active`/`claimPending`).

## Matching

5. Matching runs **entirely on the device**, not in a Cloud Function — the
   code comment in `matching.dart` explains why: server-side matching would
   need the Firebase Blaze plan, which this project doesn't have, and
   computing over found items client-side leaks nothing beyond what browsing
   the found-items list already exposes.
6. `ItemMatcher.matchesFor(lostItem, candidates)` scores every open found
   item (excluding the finder's own loss, and items that are not `isOpen`)
   via `ItemMatcher.score`:
   - **Category** is a *gate*: a mismatch other than the `other` escape
     -hatch category scores 0 outright (a lost wallet is never a found
     umbrella), rather than being outvoted by other weak agreements.
   - Among items that pass the gate, the total is a weighted sum of:
     **keyword overlap** (`jaccard` of description keywords, weight 0.5 —
     the strongest signal), **location match** (weight 0.3), **time
     proximity** (weight 0.2, decaying over 3 weeks — deliberately the
     weakest signal, since students often report things days late).
   - `MatchSignals.reasons` turns the per-signal scores into human-readable
     reasons ("Same category", "Description matches closely", "Same place",
     "Around the same time") so a student can judge the suggestion rather
     than trust an opaque number.
   - Matches below `ItemMatcher.minimumScore` (0.25) are not shown at all.
7. `matchesForLostItemProvider.family(lostItem)` computes suggestions for
   one report; `myMatchesProvider` aggregates the best suggestions across
   all of the user's open lost reports (top 5 each) — this is what the Lost
   & Found home screen leads with.

## Claiming a match

8. From a found-item detail or a match suggestion, a student calls
   `LostFoundRepository.claimFoundItem(foundItem, claimantId, proof, ...)`,
   writing a `claims/{id}` document with status `pending` and a `proof`
   string — what only the real owner would know, which the finder reads to
   judge the claim.
9. The finder approves or rejects via `LostFoundRepository.decideClaim(claimId,
   approve, rejectionReason)`. The claimant can withdraw via `withdrawClaim`.
10. **Handover confirmation.** Rather than a server-generated pickup OTP
    (which `matching.dart`'s sibling note in the repository explains would
    need Cloud Functions, and would be security theatre anyway since the
    claimant could just read and "verify" their own code), the item is only
    marked returned once **both sides** call
    `LostFoundRepository.confirmHandover(claim, uid)`. Each side can only set
    their own `claimantConfirmedHandover`/`finderConfirmedHandover` flag;
    once both are true the claim status flips to `returned` and a batch
    write closes the underlying `foundItems`/`lostItems` documents
    (`FoundItemStatus.returned`, `LostItemStatus.resolved`) so they drop off
    the public board.
11. `myClaimsProvider` streams every claim where the user is either
    claimant or finder (two separate Firestore queries merged client-side,
    since Firestore can't express an OR across different fields).

## My reports

12. `MyReportsScreen` (`Routes.myReports`) shows `myLostItemsProvider` and
    `myFoundItemsProvider`, each scoped to the signed-in uid, with controls
    to close a report (`closeLostItem`/`closeFoundItem`) once resolved
    outside the claim flow.
