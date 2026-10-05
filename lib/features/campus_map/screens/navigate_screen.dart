import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/services/tile_cache.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/campus_location.dart';
import '../../../widgets/state_views.dart';
import '../providers/location_providers.dart';
import '../providers/navigation_providers.dart';
import '../widgets/campus_map_view.dart';

/// Walking navigation to one location.
///
/// Everything here works offline: tiles from the local cache, the route from
/// the on-device graph, and the position from GPS satellites.
class NavigateScreen extends ConsumerStatefulWidget {
  const NavigateScreen({super.key, required this.locationId});

  final String locationId;

  @override
  ConsumerState<NavigateScreen> createState() => _NavigateScreenState();
}

class _NavigateScreenState extends ConsumerState<NavigateScreen> {
  final _mapController = MapController();
  TileCache? _tileCache;
  bool _followMe = true;

  @override
  void initState() {
    super.initState();
    TileCache.instance().then((cache) {
      if (mounted) setState(() => _tileCache = cache);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(locationDetailProvider(widget.locationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Navigate')),
      body: destination.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => ErrorStateView(
          failure: e is AppFailure ? e : FailureMapper.map(e, s),
          onRetry: () => ref.invalidate(locationDetailProvider(widget.locationId)),
        ),
        data: (location) {
          if (location == null) {
            return const EmptyState(
              icon: Icons.wrong_location_outlined,
              title: 'Location not found',
              message: 'This place is no longer in the campus directory.',
            );
          }
          if (!location.hasCoordinates) {
            // Honest: the place exists, we just don't know where it is yet.
            return EmptyState(
              icon: Icons.explore_off_outlined,
              title: 'Not on the map yet',
              message: '${location.name} hasn\'t had its position recorded, so '
                  'it can\'t be navigated to. An admin can add it from the '
                  'survey screen.',
            );
          }
          return _Navigator(
            location: location,
            tileCache: _tileCache,
            mapController: _mapController,
            followMe: _followMe,
            onFollowChanged: (v) => setState(() => _followMe = v),
          );
        },
      ),
    );
  }
}

class _Navigator extends ConsumerWidget {
  const _Navigator({
    required this.location,
    required this.tileCache,
    required this.mapController,
    required this.followMe,
    required this.onFollowChanged,
  });

  final CampusLocation location;
  final TileCache? tileCache;
  final MapController mapController;
  final bool followMe;
  final ValueChanged<bool> onFollowChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(positionStreamProvider);
    final position = positionAsync.valueOrNull;

    // Permission or GPS problems are the common case here, and they have
    // specific fixes — say which one rather than "something went wrong".
    if (positionAsync.hasError && position == null) {
      final error = positionAsync.error!;
      return _LocationProblem(
        failure: error is AppFailure ? error : AppFailure.unknown,
        onRetry: () => ref.invalidate(positionStreamProvider),
      );
    }

    if (position == null || tileCache == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            Gap.h16,
            Text('Finding your position…'),
          ],
        ),
      );
    }

    final route = ref.watch(routeProvider((
      fromLat: position.latitude,
      fromLng: position.longitude,
      to: location,
    )));

    if (followMe) {
      // Keep the user centred as they walk, without fighting manual panning.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.move(LatLng(position.latitude, position.longitude), mapController.camera.zoom);
      });
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CampusMapView(
            tileCache: tileCache!,
            mapController: mapController,
            locations: [location],
            selectedId: location.id,
            position: position,
            route: route,
          ),
        ),
        Positioned(
          left: Gap.lg,
          right: Gap.lg,
          bottom: Gap.lg,
          child: _RouteCard(location: location, route: route, accuracy: position.accuracy),
        ),
        Positioned(
          right: Gap.lg,
          bottom: 170,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              tooltip: followMe ? 'Stop following' : 'Follow me',
              icon: Icon(followMe ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded),
              color: Theme.of(context).colorScheme.primary,
              onPressed: () => onFollowChanged(!followMe),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.location, required this.route, required this.accuracy});

  final CampusLocation location;
  final NavigationRoute? route;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 6,
      borderRadius: Radii.lg,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(location.category.icon, color: theme.colorScheme.primary),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(location.subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (route != null) ...[
              Gap.h16,
              Row(
                children: [
                  Text(
                    formatDistance(route!.metres),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Gap.w12,
                  Text(formatEta(route!.eta), style: theme.textTheme.bodyMedium),
                ],
              ),
              if (route!.isDirectLine) ...[
                Gap.h8,
                // Never imply a walkable path we don't have.
                Row(
                  children: [
                    Icon(Icons.timeline_rounded, size: 15, color: theme.colorScheme.onSurfaceVariant),
                    Gap.w8,
                    Expanded(
                      child: Text(
                        'Straight-line direction — no walking path has been '
                        'mapped between here and there yet.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            Gap.h8,
            Text(
              // State the real precision rather than implying metre accuracy.
              'GPS accurate to about ${accuracy.round()} m',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationProblem extends ConsumerWidget {
  const _LocationProblem({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(locationServiceProvider);

    return EmptyState(
      icon: Icons.location_disabled_rounded,
      title: 'Can\'t find you',
      message: failure.message,
      actionLabel: failure.isRetryable ? 'Try again' : 'Open settings',
      onAction: failure.isRetryable ? onRetry : service.openAppSettings,
    );
  }
}
