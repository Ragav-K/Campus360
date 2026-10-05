import '../../models/enums/lost_found_enums.dart';
import '../../models/found_item.dart';
import '../../models/lost_item.dart';

/// Why a found item was suggested. Shown to the student, so they can judge the
/// suggestion instead of trusting a number they can't see inside.
class MatchSignals {
  const MatchSignals({
    required this.category,
    required this.keywords,
    required this.location,
    required this.time,
  });

  final double category;
  final double keywords;
  final double location;
  final double time;

  /// Human-readable reasons, strongest first. Empty entries are dropped so the
  /// UI never shows "matched on nothing".
  List<String> get reasons => [
        if (category == 1) 'Same category',
        if (keywords >= 0.5) 'Description matches closely',
        if (keywords >= 0.2 && keywords < 0.5) 'Some words in common',
        if (location == 1) 'Same place',
        if (time >= 0.8) 'Around the same time',
      ];
}

/// A suggested pairing. Computed on the device, never stored.
class ItemMatch {
  const ItemMatch({
    required this.lostItem,
    required this.foundItem,
    required this.score,
    required this.signals,
  });

  final LostItem lostItem;
  final FoundItem foundItem;
  final double score;
  final MatchSignals signals;

  MatchBand get band => MatchBand.forScore(score);
}

/// Scores lost reports against found reports.
///
/// ## Why this runs on the device
///
/// ARCHITECTURE.md specifies server-side matching via a Cloud Function on item
/// creation. Cloud Functions require the Blaze plan, which this project does
/// not have. Matching client-side is viable *because found items are already
/// public to signed-in students* — browsing them is the feature, so computing
/// over them leaks nothing that reading the list wouldn't.
///
/// What is genuinely lost by moving it here: matches aren't precomputed, so
/// there is no push notification the moment someone reports a matching find,
/// and the work is redone on each device. For a few hundred open items that is
/// milliseconds. It would need revisiting at a few thousand.
///
/// ## The weights
///
/// Category is a gate rather than a weight — a lost wallet is never a found
/// umbrella, so a category mismatch scores zero outright instead of being
/// outvoted by four weak agreements. Among the rest, wording carries the most
/// information, then place, then time. Time is the weakest signal on purpose:
/// students report things days late, and a "lost yesterday" report matching a
/// find from last week is still worth surfacing.
class ItemMatcher {
  const ItemMatcher();

  static const _keywordWeight = 0.5;
  static const _locationWeight = 0.3;
  static const _timeWeight = 0.2;

  /// Below this, a suggestion is noise and is not shown at all.
  static const minimumScore = 0.25;

  /// Ranked suggestions for one lost item, best first.
  List<ItemMatch> matchesFor(
    LostItem lost,
    Iterable<FoundItem> candidates, {
    int limit = 20,
  }) {
    final matches = <ItemMatch>[];

    for (final found in candidates) {
      // A student's own find is not a match for their own loss.
      if (found.finderId == lost.ownerId) continue;
      if (!found.isOpen) continue;

      final match = score(lost, found);
      if (match != null && match.score >= minimumScore) matches.add(match);
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(limit).toList();
  }

  /// Null when the pair is disqualified outright.
  ItemMatch? score(LostItem lost, FoundItem found) {
    final categoryScore = _categoryScore(lost.category, found.category);
    if (categoryScore == 0) return null;

    final keywordScore = jaccard(lost.keywords, found.keywords);
    final locationScore = _locationScore(lost, found);
    final timeScore = _timeScore(lost.lostAt, found.foundAt);

    final total = categoryScore *
        (keywordScore * _keywordWeight +
            locationScore * _locationWeight +
            timeScore * _timeWeight);

    return ItemMatch(
      lostItem: lost,
      foundItem: found,
      score: total,
      signals: MatchSignals(
        category: categoryScore,
        keywords: keywordScore,
        location: locationScore,
        time: timeScore,
      ),
    );
  }

  /// `other` is the escape hatch students pick when nothing fits, so it must
  /// not be treated as a category that disagrees with everything — it pairs
  /// with anything at a discount.
  double _categoryScore(ItemCategory lost, ItemCategory found) {
    if (lost == found) return 1;
    if (lost == ItemCategory.other || found == ItemCategory.other) return 0.6;
    return 0;
  }

  double _locationScore(LostItem lost, FoundItem found) {
    if (lost.locationId != null && lost.locationId == found.locationId) return 1;
    if (lost.locationName.isNotEmpty &&
        lost.locationName.toLowerCase() == found.locationName.toLowerCase()) {
      return 1;
    }
    // Unknown location is not evidence *against* a match, so it scores neutral
    // rather than zero — otherwise every report without a place is buried.
    if (lost.locationId == null || found.locationId == null) return 0.5;
    return 0;
  }

  /// 1.0 when found on the same day, decaying to 0 over three weeks. Finding
  /// something *before* it was reported lost is normal (the report comes late),
  /// so the gap is absolute.
  double _timeScore(DateTime? lostAt, DateTime? foundAt) {
    if (lostAt == null || foundAt == null) return 0.5; // unknown, not wrong
    final days = lostAt.difference(foundAt).abs().inHours / 24.0;
    if (days <= 1) return 1;
    if (days >= 21) return 0;
    return 1 - (days - 1) / 20;
  }

  /// Overlap of two token sets: shared ÷ combined.
  static double jaccard(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final setA = a.toSet();
    final setB = b.toSet();
    final intersection = setA.intersection(setB).length;
    if (intersection == 0) return 0;
    return intersection / setA.union(setB).length;
  }
}
