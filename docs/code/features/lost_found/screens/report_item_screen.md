# lib/features/lost_found/screens/report_item_screen.dart

## Purpose
One form screen that handles both "lost" and "found" submission flows, parameterized by a boolean flag.

## Key members
- `ReportItemScreen` (ConsumerStatefulWidget, flag: `isLost`) — a single screen covering both directions since the fields are nearly identical; differences (wording, the date question, and the lost-only "identifying details" secret field) are branched on `isLost` instead of being duplicated into two files.
- `_pickPhoto` — uses `image_picker` (camera/gallery), capped at 1600px width and 80% quality.
- `_pickWhen` — date picker bounded to the last 60 days through today.
- `_submit` — validates the form, builds a `LostItem` or `FoundItem` value object, and calls the repository's write method, passing the photo file and (for lost items) the identifying-details text.
- `_PhotoPicker` — shows the selected photo with a clear button, or a camera/gallery picker prompt with a category-emoji placeholder.

## Dependencies & relationships
Uses the lost & found providers file for repository access, the auth providers for the current user, the lost/found item models and category enum, `image_picker`, and the shared `CButton` widget. Feeds the home screen board and the matching engine via the repository write.

## Notable behavior / gotchas
Name field requires at least 3 trimmed characters; no other field is required. The "identifying details" field (lost-only) is explicitly described in-UI as private and never visible to browsers — it exists so the owner can later prove ownership when claiming. On success it pops the route and shows a tailored confirmation message per direction; on failure it keeps the form populated and shows a formatted error message.
