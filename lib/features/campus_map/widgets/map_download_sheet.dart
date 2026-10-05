import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/services/tile_cache.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/c_button.dart';

/// "Download campus map" — pre-fetches the campus so the map works with no
/// network at all.
///
/// Shown as a sheet with real progress rather than a spinner: it's a couple of
/// hundred tiles and the user should be able to see it finish.
Future<void> showMapDownloadSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false, // avoid killing a download by a stray tap outside
    builder: (_) => const _MapDownloadSheet(),
  );
}

class _MapDownloadSheet extends ConsumerStatefulWidget {
  const _MapDownloadSheet();

  @override
  ConsumerState<_MapDownloadSheet> createState() => _MapDownloadSheetState();
}

class _MapDownloadSheetState extends ConsumerState<_MapDownloadSheet> {
  TileCache? _cache;
  int _done = 0;
  int _total = 0;
  int _cachedTiles = 0;
  int _cachedBytes = 0;
  bool _running = false;
  bool _cancelled = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    TileCache.instance().then((cache) async {
      final tiles = await cache.tileCount();
      final bytes = await cache.sizeBytes();
      if (mounted) {
        setState(() {
          _cache = cache;
          _cachedTiles = tiles;
          _cachedBytes = bytes;
        });
      }
    });
  }

  Future<void> _download() async {
    final cache = _cache;
    if (cache == null) return;

    setState(() {
      _running = true;
      _cancelled = false;
      _result = null;
    });

    final template = ref.read(remoteConfigValueProvider).tileUrlTemplate;

    final fetched = await cache.prefetchCampus(
      urlTemplate: template,
      isCancelled: () => _cancelled,
      onProgress: (done, total) {
        if (mounted) setState(() { _done = done; _total = total; });
      },
    );

    final tiles = await cache.tileCount();
    final bytes = await cache.sizeBytes();

    if (!mounted) return;
    setState(() {
      _running = false;
      _cachedTiles = tiles;
      _cachedBytes = bytes;
      _result = _cancelled
          ? 'Stopped. $fetched new tiles saved — the map still works for those areas.'
          : 'Done. The campus map now works without a network.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _total == 0 ? 0.0 : _done / _total;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offline campus map', style: theme.textTheme.titleMedium),
            Gap.h8,
            Text(
              'Downloads the campus map to this phone so it works without a '
              'network. Do this once on Wi-Fi — it is a few megabytes.',
              style: theme.textTheme.bodySmall,
            ),
            Gap.h16,

            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: Radii.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.sd_storage_outlined, size: 20, color: theme.colorScheme.primary),
                  Gap.w12,
                  Expanded(
                    child: Text(
                      _cachedTiles == 0
                          ? 'Nothing saved yet'
                          : '$_cachedTiles tiles saved · ${Fmt.fileSize(_cachedBytes)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            if (_running) ...[
              Gap.h16,
              LinearProgressIndicator(value: progress == 0 ? null : progress),
              Gap.h8,
              Text('$_done of $_total tiles', style: theme.textTheme.bodySmall),
            ],

            if (_result != null) ...[
              Gap.h16,
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary),
                  Gap.w8,
                  Expanded(child: Text(_result!, style: theme.textTheme.bodySmall)),
                ],
              ),
            ],

            Gap.h24,
            if (_running)
              CButton(
                label: 'Stop',
                variant: CButtonVariant.outlined,
                onPressed: () => setState(() => _cancelled = true),
              )
            else ...[
              CButton(
                label: _cachedTiles == 0 ? 'Download campus map' : 'Update saved map',
                icon: Icons.download_rounded,
                onPressed: _cache == null ? null : _download,
              ),
              if (_cachedTiles > 0) ...[
                Gap.h8,
                CButton(
                  label: 'Delete saved map',
                  variant: CButtonVariant.text,
                  danger: true,
                  onPressed: () async {
                    await _cache?.clear();
                    if (!mounted) return;
                    setState(() {
                      _cachedTiles = 0;
                      _cachedBytes = 0;
                      _result = 'Saved map deleted.';
                    });
                  },
                ),
              ],
            ],
            Gap.h8,
            Center(
              child: TextButton(
                onPressed: _running ? null : () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
            Gap.h8,
            Text(
              AppConfig.mapAttribution,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
