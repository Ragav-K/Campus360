import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../models/enums/pulse_enums.dart';
import '../../../models/pulse_update.dart';
import '../../../repositories/pulse_repository.dart';

final pulseRepositoryProvider = Provider<PulseRepository>(
  (ref) => PulseRepository(ref.watch(firestoreProvider)),
);

/// All live updates, priority-ordered. Single source for the Pulse tab.
final activePulseProvider = StreamProvider<List<PulseUpdate>>(
  (ref) => ref.watch(pulseRepositoryProvider).watchActive(),
);

final pulseDetailProvider = StreamProvider.autoDispose.family<PulseUpdate?, String>(
  (ref, id) => ref.watch(pulseRepositoryProvider).watchOne(id),
);

/// Most recent live update for a location — powers the status shown on map
/// markers and location detail (§8).
final locationPulseProvider = StreamProvider.autoDispose.family<PulseUpdate?, String>(
  (ref, locationId) => ref.watch(pulseRepositoryProvider).watchForLocation(locationId),
);

// ---- filtering ------------------------------------------------------------

/// Selected category chip; null means "All".
final pulseCategoryFilterProvider = StateProvider<PulseCategory?>((_) => null);

/// Live search text.
final pulseSearchProvider = StateProvider<String>((_) => '');

/// The list actually rendered: active updates, narrowed by chip and search.
///
/// Filtering in memory rather than re-querying keeps typing instant and avoids
/// a Firestore read per keystroke.
final filteredPulseProvider = Provider<AsyncValue<List<PulseUpdate>>>((ref) {
  final all = ref.watch(activePulseProvider);
  final category = ref.watch(pulseCategoryFilterProvider);
  final query = ref.watch(pulseSearchProvider);

  return all.whenData((updates) => updates
      .where((u) => category == null || u.category == category)
      .where((u) => u.matches(query))
      .toList());
});

/// True when a filter or search is narrowing the list — lets the empty state
/// say "no results for that filter" instead of "nothing is happening".
final pulseFilterActiveProvider = Provider<bool>((ref) =>
    ref.watch(pulseCategoryFilterProvider) != null || ref.watch(pulseSearchProvider).trim().isNotEmpty);

/// Cards for the home carousel (§36): highest priority first, and only ones
/// attached to a location, since each card leads with the place name.
///
/// Capped at 6 — enough to be worth swiping, few enough that the dots stay
/// readable and nobody has to swipe through the whole feed.
final homePulseHighlightsProvider = Provider<AsyncValue<List<PulseUpdate>>>((ref) {
  return ref.watch(activePulseProvider).whenData((updates) {
    final located = updates.where((u) => (u.locationName ?? '').isNotEmpty).toList();
    return located.take(6).toList();
  });
});

/// Ticks once a minute so relative timestamps ("12 min ago") and expiry
/// countdowns stay truthful without the caller rebuilding constantly.
final clockTickProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});
