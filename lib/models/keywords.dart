import 'enums/lost_found_enums.dart';

/// Turns what a student typed into comparable tokens.
///
/// Both a lost report and a found report go through this, so "Black Leather
/// Wallet" and "black wallet, leather" produce overlapping tokens and can be
/// scored against each other. Kept deliberately small and pure — no stemming
/// library, no network — because the matcher must be fully testable.
class Keywords {
  const Keywords._();

  /// Words carrying no distinguishing information. Without this, every pair of
  /// reports matches on "the" and "a" and every score drifts upward.
  static const _stopWords = {
    'a', 'an', 'and', 'at', 'by', 'for', 'from', 'i', 'in', 'is', 'it', 'its',
    'me', 'my', 'of', 'on', 'or', 'the', 'to', 'with', 'was', 'were', 'near',
    'lost', 'found', 'missing', 'please', 'somewhere', 'around', 'about',
    'have', 'has', 'been', 'this', 'that', 'there', 'help', 'anyone',
  };

  /// Common ways students write the same thing. Only pairs that genuinely mean
  /// one object — not loose synonyms, which would create false matches.
  static const _synonyms = {
    'mobile': 'phone',
    'cell': 'phone',
    'cellphone': 'phone',
    'smartphone': 'phone',
    'purse': 'wallet',
    'earphones': 'earphone',
    'earbuds': 'earphone',
    'headphones': 'earphone',
    'headphone': 'earphone',
    'specs': 'glasses',
    'spectacles': 'glasses',
    'idcard': 'id',
    'identity': 'id',
    'watter': 'water',
    'bottel': 'bottle',
    'notebook': 'notes',
    'note': 'notes',
    'book': 'notes',
    'charger': 'charging',
    'laptop': 'computer',
  };

  static List<String> from(Iterable<String?> inputs, [ItemCategory? category]) {
    final tokens = <String>{};

    for (final input in inputs) {
      if (input == null || input.isEmpty) continue;
      for (final raw in input.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
        final word = _normalise(raw);
        if (word != null) tokens.add(word);
      }
    }

    // The category is a token too, so a wallet reported as "purse" still shares
    // ground with one reported as "wallet".
    if (category != null && category != ItemCategory.other) tokens.add(category.name.toLowerCase());

    return tokens.toList()..sort();
  }

  static String? _normalise(String raw) {
    if (raw.length < 2) return null; // single letters carry no signal
    if (_stopWords.contains(raw)) return null;

    final mapped = _synonyms[raw] ?? raw;

    // Crude plural stripping. "wallets" and "wallet" must not be different
    // tokens; "glass"/"glasses" is handled by the synonym table instead.
    if (mapped.length > 3 && mapped.endsWith('s') && !mapped.endsWith('ss')) {
      final singular = mapped.substring(0, mapped.length - 1);
      return _synonyms[singular] ?? singular;
    }
    return mapped;
  }
}
