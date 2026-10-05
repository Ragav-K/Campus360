/// Categories a student picks from when reporting. Deliberately a closed list:
/// free-text categories can't be matched against each other reliably, and the
/// category is the strongest matching signal we have.
enum ItemCategory {
  wallet('Wallet / purse', '👛'),
  phone('Phone', '📱'),
  keys('Keys', '🔑'),
  idCard('ID card', '🪪'),
  bag('Bag', '🎒'),
  book('Book / notes', '📘'),
  electronics('Electronics', '🎧'),
  clothing('Clothing', '🧥'),
  bottle('Water bottle', '🍶'),
  jewellery('Jewellery', '💍'),
  other('Something else', '📦');

  const ItemCategory(this.label, this.emoji);

  final String label;
  final String emoji;

  static ItemCategory parse(String? raw) =>
      ItemCategory.values.firstWhere((c) => c.name == raw, orElse: () => ItemCategory.other);
}

enum LostItemStatus {
  active('Still missing'),
  claimPending('Claim in progress'),
  resolved('Returned'),
  closed('Closed');

  const LostItemStatus(this.label);
  final String label;

  static LostItemStatus parse(String? raw) =>
      LostItemStatus.values.firstWhere((s) => s.name == raw, orElse: () => LostItemStatus.active);
}

enum FoundItemStatus {
  active('Waiting to be claimed'),
  claimPending('Claim in progress'),
  returned('Returned to owner'),
  closed('Closed');

  const FoundItemStatus(this.label);
  final String label;

  static FoundItemStatus parse(String? raw) =>
      FoundItemStatus.values.firstWhere((s) => s.name == raw, orElse: () => FoundItemStatus.active);
}

/// How a claim moves from "I think that's mine" to the item changing hands.
///
/// Both sides must confirm the handover. Without a server there is no way to
/// mint a pickup OTP the client cannot read, so two-sided confirmation is the
/// honest substitute — see ARCHITECTURE.md and the note in
/// `LostFoundRepository.confirmHandover`.
enum ClaimStatus {
  pending('Waiting for the finder'),
  approved('Approved — arrange handover'),
  rejected('Not approved'),
  returned('Returned'),
  withdrawn('Withdrawn');

  const ClaimStatus(this.label);
  final String label;

  static ClaimStatus parse(String? raw) =>
      ClaimStatus.values.firstWhere((s) => s.name == raw, orElse: () => ClaimStatus.pending);
}

/// How confident the matcher is. Bands, not raw scores, because a percentage
/// implies a precision this matching does not have.
enum MatchBand {
  possible('Possible match'),
  related('Worth a look'),
  likely('Likely match');

  const MatchBand(this.label);
  final String label;

  static MatchBand forScore(double score) => switch (score) {
        >= 0.8 => MatchBand.likely,
        >= 0.55 => MatchBand.related,
        _ => MatchBand.possible,
      };
}
