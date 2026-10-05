import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../models/claim.dart';
import '../../../models/found_item.dart';
import '../../../models/lost_item.dart';
import '../../../repositories/lost_found_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../matching.dart';

final lostFoundRepositoryProvider = Provider<LostFoundRepository>(
  (ref) => LostFoundRepository(ref.watch(firestoreProvider)),
);

final openFoundItemsProvider = StreamProvider<List<FoundItem>>(
  (ref) => ref.watch(lostFoundRepositoryProvider).watchOpenFoundItems(),
);

final openLostItemsProvider = StreamProvider<List<LostItem>>(
  (ref) => ref.watch(lostFoundRepositoryProvider).watchOpenLostItems(),
);

final myLostItemsProvider = StreamProvider<List<LostItem>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(lostFoundRepositoryProvider).watchMyLostItems(uid);
});

final myFoundItemsProvider = StreamProvider<List<FoundItem>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(lostFoundRepositoryProvider).watchMyFoundItems(uid);
});

final myClaimsProvider = StreamProvider<List<Claim>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(lostFoundRepositoryProvider).watchMyClaims(uid);
});

final foundItemProvider = StreamProvider.family<FoundItem?, String>(
  (ref, id) => ref.watch(lostFoundRepositoryProvider).watchFoundItem(id),
);

final lostItemProvider = StreamProvider.family<LostItem?, String>(
  (ref, id) => ref.watch(lostFoundRepositoryProvider).watchLostItem(id),
);

/// Suggestions for one of the user's lost reports.
///
/// Computed here rather than stored: see the note on [ItemMatcher] explaining
/// why matching moved to the device.
final matchesForLostItemProvider = Provider.family<List<ItemMatch>, LostItem>((ref, lost) {
  final found = ref.watch(openFoundItemsProvider).valueOrNull ?? const [];
  return const ItemMatcher().matchesFor(lost, found);
});

/// Every suggestion across all of the user's open lost reports, best first.
/// This is what the Lost & Found home screen leads with.
final myMatchesProvider = Provider<List<ItemMatch>>((ref) {
  final mine = ref.watch(myLostItemsProvider).valueOrNull ?? const [];
  final found = ref.watch(openFoundItemsProvider).valueOrNull ?? const [];
  const matcher = ItemMatcher();

  final all = <ItemMatch>[];
  for (final lost in mine.where((l) => l.isOpen)) {
    all.addAll(matcher.matchesFor(lost, found, limit: 5));
  }
  all.sort((a, b) => b.score.compareTo(a.score));
  return all;
});
