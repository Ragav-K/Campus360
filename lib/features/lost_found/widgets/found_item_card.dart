import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/enums/lost_found_enums.dart';
import '../../../models/found_item.dart';

/// One found item on the board.
class FoundItemCard extends StatelessWidget {
  const FoundItemCard({super.key, required this.item, this.onTap});

  final FoundItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(photoUrl: item.photoUrl, category: item.category),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap.h4,
                    Text(
                      [
                        if (item.locationName.isNotEmpty) item.locationName,
                        if (item.foundAt != null) Fmt.relative(item.foundAt!),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                    if (item.handoverNote.isNotEmpty) ...[
                      Gap.h8,
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 14, color: theme.hintColor),
                          Gap.w4,
                          Expanded(
                            child: Text(
                              item.handoverNote,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.status == FoundItemStatus.claimPending) ...[
                      Gap.h8,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: Radii.sm,
                        ),
                        child: Text(
                          'Someone has claimed this',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo, or the category emoji when there isn't one. Never a broken image
/// box — plenty of finds are reported without a picture.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.photoUrl, required this.category});

  final String? photoUrl;
  final ItemCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: Radii.md,
      ),
      child: Text(category.emoji, style: const TextStyle(fontSize: 24)),
    );

    if (photoUrl == null || photoUrl!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: Radii.md,
      child: Image.network(
        photoUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
      ),
    );
  }
}
