# Campus Pulse

Screens: `lib/features/campus_pulse/screens/{pulse_home_screen,pulse_detail_screen}.dart`
Widgets: `lib/features/campus_pulse/widgets/{pulse_card,home_header,pulse_deck}.dart`
Providers: `lib/features/campus_pulse/providers/pulse_providers.dart`
Repository: `lib/repositories/pulse_repository.dart`
Model: `lib/models/pulse_update.dart` (`PulseUpdate`, `Occupancy`), `lib/models/enums/pulse_enums.dart`
Firestore: `pulseUpdates/{id}` (+ `reports` subcollection per update)

Pulse is the first tab (`Routes.pulse`, `/pulse`) — a feed of live campus
information: notices, alerts, events, and crowd/availability status.

## Viewing (student / any signed-in role)

1. **Home feed.** `PulseHomeScreen` reads `activePulseProvider`, a
   `StreamProvider` over `PulseRepository.watchActive()` — a Firestore query
   on `pulseUpdates` filtered to `isActive == true`, ordered by `priority`
   desc then `createdAt` desc, limited to 60. The repository filters out
   anything already expired via `PulseUpdate.isLive` client-side, because
   the scheduled expiry function that flips `isActive` to false runs
   periodically and can lag behind `expiresAt`.
2. **Home carousel highlights.** `homePulseHighlightsProvider` takes the
   active feed, keeps only updates attached to a location (so each card can
   lead with a place name), and caps it at 6 for the swipeable carousel
   (`pulse_deck.dart`).
3. **Filtering.** `pulseCategoryFilterProvider` (a chip: Crowd, Availability,
   Notice, Alert, Event) and `pulseSearchProvider` (free text) narrow
   `filteredPulseProvider` — filtering happens in memory over the already
   -streamed list rather than re-querying Firestore per keystroke.
4. **Detail.** Tapping a card navigates to `Routes.pulseDetail(id)` →
   `PulseDetailScreen`, backed by `pulseDetailProvider.family(id)` (a single
   -document stream, `autoDispose` since it's only needed while the screen
   is open).
5. **Occupancy readings.** Some updates carry an `Occupancy` (crowd count or
   density level) written by a desk counter, an ID-card gate, or a camera —
   all treated identically by the UI via the `mode`/`source` contract in
   `Occupancy`. `locationPulseProvider.family(locationId)` surfaces the most
   recent live update for a location, which is what the Map screen's
   markers and location detail show as current status.
6. **Flag as stale.** A student can call `PulseRepository.reportStale(...)`,
   which writes one report document per `(pulseId, uid)` under
   `pulseUpdates/{id}/reports/{uid}` — re-reporting overwrites rather than
   spamming a moderation queue. `hasReported` checks whether this user
   already flagged it.
7. **Live countdowns.** `clockTickProvider` ticks once a minute so relative
   timestamps ("12 min ago") and expiry countdowns (`PulseUpdate.timeRemaining`)
   stay accurate without screens needing their own timers.

## Creating / managing (admin)

8. Writes (`PulseRepository.create`, `update`, `expireNow`, `delete`) are
   intended for admins only — enforced by Firestore rules, not by the
   repository itself. `create` takes title/description/category/status/
   priority/location/image/expiry and stamps `createdAt` server-side.
   `expireNow` is a soft delete: it flips `isActive` to false and stamps
   `expiresAt` to now, keeping the record for audit instead of destroying
   it; `delete` is the hard delete.
