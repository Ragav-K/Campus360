import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/services/tile_cache.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/campus_location.dart';
import '../../../models/campus_path.dart';
import '../providers/navigation_providers.dart';

/// The campus map.
///
/// Tiles come from [CachedTileProvider], so anything already downloaded renders
/// with no network. Uncached tiles simply stay blank offline — correct
/// behaviour, not an error state.
class CampusMapView extends StatelessWidget {
  const CampusMapView({
    super.key,
    required this.tileCache,
    required this.locations,
    this.selectedId,
    this.onMarkerTap,
    this.position,
    this.route,
    this.mapController,
    this.tileUrlTemplate,
    this.interactive = true,
    this.graph,
    this.selectedNodeId,
    this.highlightedNodeIds = const {},
    this.onNodeTap,
  });

  final TileCache tileCache;
  final List<CampusLocation> locations;
  final String? selectedId;
  final void Function(CampusLocation location)? onMarkerTap;

  /// The walking network, drawn on top of the tiles. Only the survey screen
  /// passes this — students see routes, not the graph the routes run over.
  final CampusGraph? graph;

  final String? selectedNodeId;

  /// Nodes joined to the selection, drawn distinctly so it is obvious what a
  /// deletion would disconnect.
  final Set<String> highlightedNodeIds;

  final void Function(PathNode node)? onNodeTap;

  /// Current GPS fix, drawn as a dot with its accuracy circle.
  final Position? position;

  final NavigationRoute? route;
  final MapController? mapController;
  final String? tileUrlTemplate;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = tileUrlTemplate ?? AppConfig.tileUrlTemplate;

    // Indexed once per build rather than scanning `nodes` per edge endpoint —
    // this runs on every pan and zoom frame.
    final nodesById = {for (final n in graph?.nodes ?? const <PathNode>[]) n.id: n};

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _initialCentre(),
        initialZoom: AppConfig.mapInitialZoom,
        minZoom: AppConfig.mapMinZoom,
        maxZoom: AppConfig.mapMaxZoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        // Keep the view over campus; this is not a world map.
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(AppConfig.campusSouth, AppConfig.campusWest),
            const LatLng(AppConfig.campusNorth, AppConfig.campusEast),
          ),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: url,
          userAgentPackageName: 'com.campus360.campus360',
          tileProvider: CachedTileProvider(tileCache),
          maxNativeZoom: AppConfig.prefetchMaxZoom,
          // A blank tile is the honest offline state — no error glyph.
          errorTileCallback: (_, __, ___) {},
        ),

        // Under the route and the pins: the network is context, not the subject.
        if (graph != null && !graph!.isEmpty)
          PolylineLayer(
            polylines: [
              for (final edge in graph!.edges)
                // A dangling edge draws nothing rather than crashing — the same
                // tolerance CampusGraph applies when routing over one.
                if (nodesById[edge.a] != null && nodesById[edge.b] != null)
                  Polyline(
                    points: [
                      LatLng(nodesById[edge.a]!.lat, nodesById[edge.a]!.lng),
                      LatLng(nodesById[edge.b]!.lat, nodesById[edge.b]!.lng),
                    ],
                    strokeWidth: 3,
                    color: _edgeTouchesSelection(edge)
                        ? AppColors.warning
                        : AppColors.info.withValues(alpha: 0.55),
                  ),
            ],
          ),

        if (route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route!.points.map((p) => LatLng(p.lat, p.lng)).toList(),
                strokeWidth: 5,
                color: route!.isDirectLine
                    ? AppColors.neutral.withValues(alpha: 0.75)
                    : theme.colorScheme.primary,
                // Dashed when it's a straight line rather than a real path, so
                // the drawing itself signals the difference.
                pattern: route!.isDirectLine
                    ? StrokePattern.dashed(segments: const [10, 8])
                    : const StrokePattern.solid(),
              ),
            ],
          ),

        if (position != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(position!.latitude, position!.longitude),
                radius: position!.accuracy,
                useRadiusInMeter: true,
                color: AppColors.info.withValues(alpha: 0.15),
                borderColor: AppColors.info.withValues(alpha: 0.4),
                borderStrokeWidth: 1,
              ),
            ],
          ),

        if (graph != null)
          MarkerLayer(
            markers: [
              for (final node in graph!.nodes)
                Marker(
                  point: LatLng(node.lat, node.lng),
                  // Generous next to the 10 px dot it draws: these are tapped
                  // with a thumb, outdoors, while standing on the path.
                  width: 34,
                  height: 34,
                  child: _PathNodeDot(
                    // Keyed so a test can tap a specific point: the dots'
                    // semantics merge into the map's own node, leaving nothing
                    // else to address an individual one by.
                    key: ValueKey('path-node-${node.id}'),
                    node: node,
                    selected: node.id == selectedNodeId,
                    highlighted: highlightedNodeIds.contains(node.id),
                    onTap: onNodeTap == null ? null : () => onNodeTap!(node),
                  ),
                ),
            ],
          ),

        MarkerLayer(
          markers: [
            for (final location in locations)
              Marker(
                point: LatLng(location.lat!, location.lng!),
                width: 44,
                height: 52,
                alignment: Alignment.topCenter,
                child: _LocationPin(
                  location: location,
                  selected: location.id == selectedId,
                  onTap: onMarkerTap == null ? null : () => onMarkerTap!(location),
                ),
              ),
            if (position != null)
              Marker(
                point: LatLng(position!.latitude, position!.longitude),
                width: 22,
                height: 22,
                child: const _PositionDot(),
              ),
          ],
        ),

        // OSM's licence requires visible attribution wherever tiles are shown.
        const RichAttributionWidget(
          attributions: [TextSourceAttribution(AppConfig.mapAttribution, onTap: null)],
          alignment: AttributionAlignment.bottomLeft,
        ),
      ],
    );
  }

  bool _edgeTouchesSelection(({String a, String b}) edge) =>
      selectedNodeId != null && (edge.a == selectedNodeId || edge.b == selectedNodeId);

  LatLng _initialCentre() {
    if (position != null) return LatLng(position!.latitude, position!.longitude);
    final selected = locations.where((l) => l.id == selectedId).firstOrNull;
    if (selected != null) return LatLng(selected.lat!, selected.lng!);
    return const LatLng(AppConfig.campusLat, AppConfig.campusLng);
  }
}

class _LocationPin extends StatelessWidget {
  const _LocationPin({required this.location, required this.selected, this.onTap});

  final CampusLocation location;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.surface;
    final iconColor = selected ? theme.colorScheme.onPrimary : theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: location.name,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(location.category.icon, size: 18, color: iconColor),
            ),
            // Little stalk so the pin points at the actual coordinate.
            Container(width: 2, height: 8, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// A point on the walking network, as drawn on the survey map.
///
/// Deliberately smaller than a location pin: dozens of these sit along a
/// footpath, and at pin size they would bury the places they lead to.
class _PathNodeDot extends StatelessWidget {
  const _PathNodeDot({
    super.key,
    required this.node,
    required this.selected,
    required this.highlighted,
    this.onTap,
  });

  final PathNode node;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (size, colour) = switch ((selected, highlighted)) {
      (true, _) => (18.0, scheme.primary),
      (false, true) => (14.0, AppColors.warning),
      _ => (10.0, AppColors.info),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: node.name.isEmpty ? 'Path point' : 'Path point, ${node.name}',
      child: GestureDetector(
        onTap: onTap,
        // Transparent rather than none, so the whole 34 px marker takes the tap
        // and not just the dot drawn inside it.
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              color: colour,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: selected ? 3 : 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "you are here" dot. Always drawn inside its accuracy circle so the
/// precision it implies matches the precision GPS actually delivers.
class _PositionDot extends StatelessWidget {
  const _PositionDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.info,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 5),
        ],
      ),
    );
  }
}
