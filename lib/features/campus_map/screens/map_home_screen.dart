import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/tile_cache.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/campus_location.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/state_views.dart';
import '../providers/location_providers.dart';
import '../providers/navigation_providers.dart';
import '../widgets/campus_map_view.dart';
import '../widgets/location_tile.dart';
import '../widgets/map_download_sheet.dart';

/// Campus Map (§8).
///
/// A real map now, not a list with a placeholder: OpenStreetMap tiles served
/// from an on-device cache, so it keeps working when campus network doesn't.
/// Search sits on top of the map, satisfying §35's "find a location without
/// navigating through menus".
class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  final _searchController = TextEditingController();
  final _mapController = MapController();

  TileCache? _tileCache;
  bool _showList = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    TileCache.instance().then((cache) {
      if (mounted) setState(() => _tileCache = cache);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(locationSearchProvider.notifier).state = '';
    ref.read(locationCategoryFilterProvider.notifier).state = null;
    setState(() {});
  }

  void _focusOn(CampusLocation location) {
    setState(() {
      _selectedId = location.id;
      _showList = false;
    });
    if (location.hasCoordinates) {
      _mapController.move(LatLng(location.lat!, location.lng!), 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(filteredLocationsProvider);
    final mapped = ref.watch(mappedLocationsProvider);
    final categories = ref.watch(availableLocationCategoriesProvider);
    final selectedCategory = ref.watch(locationCategoryFilterProvider);
    final filterActive = ref.watch(locationFilterActiveProvider);
    final searching = ref.watch(locationSearchProvider).trim().isNotEmpty;

    // Only listens while this screen is alive; the GPS chip stops on dispose.
    final position = ref.watch(positionStreamProvider).valueOrNull;

    // Search results take over the view — you're looking for one thing.
    final showResults = _showList || searching || filterActive;

    return Scaffold(
      body: Stack(
        children: [
          if (_tileCache != null)
            Positioned.fill(
              child: CampusMapWithMarkers(
                tileCache: _tileCache!,
                controller: _mapController,
                locations: mapped,
                selectedId: _selectedId,
                position: position,
                onMarkerTap: (l) => context.push(Routes.locationDetail(l.id)),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // ---- search + filters, floating over the map ----
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                  child: Material(
                    elevation: 3,
                    borderRadius: Radii.md,
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search for a place, e.g. Print Shop',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searching
                            ? IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _clearSearch,
                              )
                            : IconButton(
                                tooltip: _showList ? 'Show map' : 'Show list',
                                icon: Icon(_showList ? Icons.map_outlined : Icons.list_rounded),
                                onPressed: () => setState(() => _showList = !_showList),
                              ),
                      ),
                      onChanged: (v) {
                        ref.read(locationSearchProvider.notifier).state = v;
                        setState(() {});
                      },
                    ),
                  ),
                ),
                if (categories.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
                      children: [
                        _MapChip(
                          label: 'All',
                          selected: selectedCategory == null,
                          onTap: () =>
                              ref.read(locationCategoryFilterProvider.notifier).state = null,
                        ),
                        for (final c in categories) ...[
                          Gap.w8,
                          _MapChip(
                            label: c.chipLabel,
                            icon: c.icon,
                            selected: selectedCategory == c,
                            onTap: () => ref.read(locationCategoryFilterProvider.notifier).state =
                                selectedCategory == c ? null : c,
                          ),
                        ],
                      ],
                    ),
                  ),
                if (showResults)
                  Expanded(
                    child: _ResultsSheet(
                      locations: locations,
                      filterActive: filterActive,
                      onClear: _clearSearch,
                      onTap: _focusOn,
                      onOpen: (l) => context.push(Routes.locationDetail(l.id)),
                    ),
                  ),
              ],
            ),
          ),

          // ---- map controls ----
          if (!showResults)
            Positioned(
              right: Gap.lg,
              bottom: Gap.xl,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.download_outlined,
                    tooltip: 'Download campus map for offline use',
                    onPressed: () => showMapDownloadSheet(context),
                  ),
                  Gap.h12,
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Centre on me',
                    onPressed: () => _centreOnMe(position),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _centreOnMe(Position? position) async {
    if (position != null) {
      _mapController.move(LatLng(position.latitude, position.longitude), 18);
      return;
    }
    // No fix yet — usually permission. Surface the real reason.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(locationServiceProvider).ensurePermission();
      messenger.showSnackBar(
        const SnackBar(content: Text('Looking for a GPS fix…')),
      );
      ref.invalidate(positionStreamProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
    }
  }
}

/// Extracted so the map can be reused by the navigation screen.
class CampusMapWithMarkers extends StatelessWidget {
  const CampusMapWithMarkers({
    super.key,
    required this.tileCache,
    required this.locations,
    this.controller,
    this.selectedId,
    this.position,
    this.onMarkerTap,
    this.route,
  });

  final TileCache tileCache;
  final List<CampusLocation> locations;
  final MapController? controller;
  final String? selectedId;
  final Position? position;
  final void Function(CampusLocation)? onMarkerTap;
  final NavigationRoute? route;

  @override
  Widget build(BuildContext context) {
    return CampusMapView(
      tileCache: tileCache,
      mapController: controller,
      locations: locations,
      selectedId: selectedId,
      position: position,
      onMarkerTap: onMarkerTap,
      route: route,
    );
  }
}

class _ResultsSheet extends StatelessWidget {
  const _ResultsSheet({
    required this.locations,
    required this.filterActive,
    required this.onClear,
    required this.onTap,
    required this.onOpen,
  });

  final AsyncValue<List<CampusLocation>> locations;
  final bool filterActive;
  final VoidCallback onClear;
  final void Function(CampusLocation) onTap;
  final void Function(CampusLocation) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: AsyncValueView<List<CampusLocation>>(
        value: locations,
        skeleton: () => ListView.separated(
          padding: const EdgeInsets.all(Gap.lg),
          itemCount: 4,
          separatorBuilder: (_, __) => Gap.h12,
          itemBuilder: (_, __) => const SkeletonCard(lines: 1),
        ),
        empty: (_) => filterActive
            ? EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No places match',
                message: 'Try a different search or category.',
                actionLabel: 'Clear',
                onAction: onClear,
                compact: true,
              )
            : const EmptyState(
                icon: Icons.map_outlined,
                title: 'No campus locations yet',
                message: 'Once an admin adds locations, you can search and find them here.',
                compact: true,
              ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(Gap.lg),
          itemCount: items.length,
          separatorBuilder: (_, __) => Gap.h12,
          itemBuilder: (_, i) => LocationTile(
            location: items[i],
            onTap: () => onOpen(items[i]),
            onShowOnMap: items[i].hasCoordinates ? () => onTap(items[i]) : null,
          ),
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        elevation: 2,
        borderRadius: Radii.pill,
        child: ChoiceChip(
          avatar: icon == null
              ? null
              : Icon(icon, size: 16, color: selected ? scheme.onPrimary : scheme.onSurface),
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        color: theme.colorScheme.primary,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: kMinTouchTarget, height: kMinTouchTarget),
      ),
    );
  }
}
