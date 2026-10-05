import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../models/campus_location.dart';
import '../../../models/enums/location_enums.dart';
import '../../../repositories/location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(ref.watch(firestoreProvider)),
);

/// Every active campus location. Kept alive (not autoDispose) because the whole
/// app links into locations and re-fetching on every visit would be wasteful.
final allLocationsProvider = StreamProvider<List<CampusLocation>>(
  (ref) => ref.watch(locationRepositoryProvider).watchAll(),
);

final locationDetailProvider = StreamProvider.autoDispose.family<CampusLocation?, String>(
  (ref, id) => ref.watch(locationRepositoryProvider).watchOne(id),
);

final locationSearchProvider = StateProvider<String>((_) => '');
final locationCategoryFilterProvider = StateProvider<LocationCategory?>((_) => null);

/// Search + category applied in memory — see [LocationRepository] for why.
final filteredLocationsProvider = Provider<AsyncValue<List<CampusLocation>>>((ref) {
  final all = ref.watch(allLocationsProvider);
  final query = ref.watch(locationSearchProvider);
  final category = ref.watch(locationCategoryFilterProvider);

  return all.whenData((locations) {
    final results = locations
        .where((l) => category == null || l.category == category)
        .where((l) => l.matches(query))
        .toList();

    // With a query, rank prefix matches first — typing "lib" should put
    // "Library" above "Digital Library Annexe".
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      results.sort((a, b) {
        final aStarts = a.name.toLowerCase().startsWith(q);
        final bStarts = b.name.toLowerCase().startsWith(q);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    }
    return results;
  });
});

final locationFilterActiveProvider = Provider<bool>((ref) =>
    ref.watch(locationCategoryFilterProvider) != null ||
    ref.watch(locationSearchProvider).trim().isNotEmpty);

/// Only the categories that actually exist in the data, so the filter row
/// doesn't offer chips that always return nothing.
final availableLocationCategoriesProvider = Provider<List<LocationCategory>>((ref) {
  final locations = ref.watch(allLocationsProvider).valueOrNull ?? const [];
  final present = locations.map((l) => l.category).toSet();
  return LocationCategory.filterOrder.where(present.contains).toList();
});
