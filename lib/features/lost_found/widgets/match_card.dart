import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/enums/lost_found_enums.dart';
import '../matching.dart';
import 'found_item_card.dart';

/// A suggested pairing, with the reasons it was suggested.
///
/// The reasons are the point. A bare "92% match" asks the student to trust a
/// number they cannot check; "same category, same place, around the same time"
/// lets them judge it themselves — and quietly explains a wrong suggestion
/// instead of just looking broken.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.onTap});

  final ItemMatch match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reasons = match.signals.reasons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _BandChip(band: match.band),
            Gap.w8,
            Expanded(
              child: Text(
                'for "${match.lostItem.itemName}"',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Gap.h8,
        FoundItemCard(item: match.foundItem, onTap: onTap),
        if (reasons.isNotEmpty) ...[
          Gap.h8,
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final reason in reasons)
                Chip(
                  label: Text(reason),
                  labelStyle: theme.textTheme.labelSmall,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: theme.dividerColor),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({required this.band});

  final MatchBand band;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (band) {
      MatchBand.likely => (scheme.primaryContainer, scheme.onPrimaryContainer),
      MatchBand.related => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      MatchBand.possible => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: Radii.sm),
      child: Text(
        band.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
