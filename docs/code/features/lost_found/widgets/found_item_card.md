# lib/features/lost_found/widgets/found_item_card.dart

## Purpose
Reusable card rendering one found-item entry for board/list views.

## Key members
- `FoundItemCard` (StatelessWidget) — shows thumbnail, item name, location/found-date subtitle, optional handover note, and a "Someone has claimed this" badge when `status == FoundItemStatus.claimPending`. Takes an `onTap` callback.
- `_Thumbnail` — renders the item's photo via `Image.network` with an error/loading fallback to a category-emoji placeholder tile; shows the placeholder directly when no photo URL exists.

## Dependencies & relationships
Uses `FoundItem` and `ItemCategory`/`FoundItemStatus` models and `Fmt.relative` for date formatting. Used by `lost_found_home_screen.dart`, `my_reports_screen.dart`, and `match_card.dart`.

## Notable behavior / gotchas
Never shows a broken-image icon — the thumbnail always falls back to the category emoji, since many finds are reported without a picture.
