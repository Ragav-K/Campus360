import 'package:campus360/features/lost_found/matching.dart';
import 'package:campus360/models/enums/lost_found_enums.dart';
import 'package:campus360/models/found_item.dart';
import 'package:campus360/models/keywords.dart';
import 'package:campus360/models/lost_item.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 8, 13, 12);

LostItem lost({
  String owner = 'owner1',
  String name = 'Black leather wallet',
  ItemCategory category = ItemCategory.wallet,
  String description = '',
  String? locationId = 'library',
  String locationName = 'Library',
  DateTime? lostAt,
  // A plain `lostAt ?? _now` default cannot express "the student didn't say",
  // which is exactly the case worth testing — hence a separate flag.
  bool unknownTime = false,
}) {
  final item = LostItem(
    id: 'l1',
    ownerId: owner,
    ownerName: 'Owner',
    itemName: name,
    category: category,
    description: description,
    locationId: locationId,
    locationName: locationName,
    lostAt: unknownTime ? null : (lostAt ?? _now),
    createdAt: _now,
  );
  // Keywords are derived on write, so mirror that here rather than hand-listing
  // them — otherwise the tests could pass against tokens the app never produces.
  return LostItem(
    id: item.id,
    ownerId: item.ownerId,
    ownerName: item.ownerName,
    itemName: item.itemName,
    category: item.category,
    description: item.description,
    locationId: item.locationId,
    locationName: item.locationName,
    lostAt: item.lostAt,
    keywords: Keywords.from([name, description, locationName], category),
    createdAt: item.createdAt,
  );
}

FoundItem found({
  String id = 'f1',
  String finder = 'finder1',
  String name = 'Black leather wallet',
  ItemCategory category = ItemCategory.wallet,
  String description = '',
  String? locationId = 'library',
  String locationName = 'Library',
  DateTime? foundAt,
  bool unknownTime = false,
  FoundItemStatus status = FoundItemStatus.active,
}) =>
    FoundItem(
      id: id,
      finderId: finder,
      finderName: 'Finder',
      itemName: name,
      category: category,
      description: description,
      locationId: locationId,
      locationName: locationName,
      foundAt: unknownTime ? null : (foundAt ?? _now),
      keywords: Keywords.from([name, description, locationName], category),
      status: status,
      createdAt: _now,
    );

void main() {
  const matcher = ItemMatcher();

  group('category gating', () {
    test('a different category is never a match, however well it reads', () {
      // Same words, same place, same minute — but a wallet is not a bottle.
      final result = matcher.score(
        lost(name: 'Black bottle', category: ItemCategory.wallet),
        found(name: 'Black bottle', category: ItemCategory.bottle),
      );
      expect(result, isNull);
    });

    test('"something else" pairs with anything, at a discount', () {
      final asOther = matcher.score(
        lost(category: ItemCategory.other),
        found(category: ItemCategory.wallet),
      );
      final asExact = matcher.score(lost(), found());
      expect(asOther, isNotNull);
      expect(asOther!.score, lessThan(asExact!.score));
    });
  });

  group('scoring', () {
    test('an identical report in the same place at the same time scores high', () {
      final result = matcher.score(lost(), found())!;
      expect(result.score, greaterThan(0.5));
      expect(result.band, MatchBand.likely);
    });

    test('the same object described differently still matches', () {
      // "purse" and "mobile" are how students actually write these.
      final result = matcher.score(
        lost(name: 'Brown purse', category: ItemCategory.wallet),
        found(name: 'Brown wallet', category: ItemCategory.wallet),
      );
      expect(result, isNotNull);
      expect(result!.signals.keywords, greaterThan(0));
    });

    test('a wrong place and a stale date drag the score down', () {
      final near = matcher.score(lost(), found())!;
      final far = matcher.score(
        lost(),
        found(
          locationId: 'canteen',
          locationName: 'Canteen',
          foundAt: _now.subtract(const Duration(days: 30)),
        ),
      )!;
      expect(far.score, lessThan(near.score));
    });

    test('an unknown time is neutral, not a penalty to zero', () {
      final result = matcher.score(lost(unknownTime: true), found())!;
      expect(result.signals.time, 0.5);
    });

    test('finding something before it was reported lost is not penalised', () {
      // Reports come in late constantly; the gap is what matters, not the sign.
      final before = matcher.score(lost(), found(foundAt: _now.subtract(const Duration(hours: 20))))!;
      final after = matcher.score(lost(), found(foundAt: _now.add(const Duration(hours: 20))))!;
      expect(before.score, closeTo(after.score, 0.0001));
    });

    test('time decays to zero after three weeks', () {
      final result = matcher.score(lost(), found(foundAt: _now.subtract(const Duration(days: 25))))!;
      expect(result.signals.time, 0);
    });
  });

  group('matchesFor', () {
    test('ranks the better match first', () {
      final results = matcher.matchesFor(lost(), [
        found(id: 'weak', name: 'Wallet', locationId: 'canteen', locationName: 'Canteen'),
        found(id: 'strong', name: 'Black leather wallet'),
      ]);
      expect(results.first.foundItem.id, 'strong');
    });

    test('never suggests your own find as a match for your own loss', () {
      final results = matcher.matchesFor(
        lost(owner: 'same-person'),
        [found(finder: 'same-person')],
      );
      expect(results, isEmpty);
    });

    test('ignores items already returned', () {
      final results = matcher.matchesFor(
        lost(),
        [found(status: FoundItemStatus.returned)],
      );
      expect(results, isEmpty);
    });

    test('drops noise below the floor', () {
      // Same category, but nothing else in common at all.
      final results = matcher.matchesFor(
        lost(name: 'Wallet', locationId: 'library', locationName: 'Library'),
        [
          found(
            id: 'noise',
            name: 'Purse',
            locationId: 'annexe',
            locationName: 'Annexe',
            foundAt: _now.subtract(const Duration(days: 40)),
          ),
        ],
      );
      for (final m in results) {
        expect(m.score, greaterThanOrEqualTo(ItemMatcher.minimumScore));
      }
    });

    test('respects the limit', () {
      final many = List.generate(50, (i) => found(id: 'f$i'));
      expect(matcher.matchesFor(lost(), many, limit: 5).length, 5);
    });
  });

  group('reasons shown to the student', () {
    test('a strong match explains itself', () {
      final result = matcher.score(lost(), found())!;
      expect(result.signals.reasons, contains('Same category'));
      expect(result.signals.reasons, contains('Same place'));
    });

    test('never claims a reason it does not have', () {
      final result = matcher.score(
        lost(unknownTime: true),
        found(locationId: 'canteen', locationName: 'Canteen', unknownTime: true),
      )!;
      expect(result.signals.reasons, isNot(contains('Same place')));
      expect(result.signals.reasons, isNot(contains('Around the same time')));
    });
  });

  group('jaccard', () {
    test('identical sets score 1', () {
      expect(ItemMatcher.jaccard(['a', 'b'], ['a', 'b']), 1);
    });
    test('disjoint sets score 0', () {
      expect(ItemMatcher.jaccard(['a'], ['b']), 0);
    });
    test('an empty side scores 0 rather than dividing by zero', () {
      expect(ItemMatcher.jaccard([], ['a']), 0);
      expect(ItemMatcher.jaccard(['a'], []), 0);
    });
    test('half overlap scores a third', () {
      expect(ItemMatcher.jaccard(['a', 'b'], ['b', 'c']), closeTo(1 / 3, 0.0001));
    });
  });

  group('Keywords', () {
    test('drops stop words and short noise', () {
      final tokens = Keywords.from(['I lost my black wallet in the library']);
      expect(tokens, isNot(contains('the')));
      expect(tokens, isNot(contains('lost')));
      expect(tokens, contains('black'));
    });

    test('folds the ways students write the same object', () {
      expect(Keywords.from(['my mobile']), contains('phone'));
      expect(Keywords.from(['purse']), contains('wallet'));
      expect(Keywords.from(['headphones']), contains('earphone'));
    });

    test('plurals fold to the singular', () {
      expect(Keywords.from(['keys']), contains('key'));
      expect(Keywords.from(['glasses']), Keywords.from(['spectacles']));
    });

    test('adds the category as a token', () {
      expect(Keywords.from(['something'], ItemCategory.wallet), contains('wallet'));
    });

    test('does not add "other" — it distinguishes nothing', () {
      expect(Keywords.from(['thing'], ItemCategory.other), isNot(contains('other')));
    });

    test('is order-independent, so wording differences do not matter', () {
      expect(
        Keywords.from(['black leather wallet']),
        Keywords.from(['wallet, leather — black']),
      );
    });
  });
}
