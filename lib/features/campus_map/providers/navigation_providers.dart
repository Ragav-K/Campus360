import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/tile_cache.dart';
import '../../../models/campus_location.dart';
import '../../../models/campus_path.dart';
import '../../../repositories/path_repository.dart';
import 'location_providers.dart';

final locationServiceProvider = Provider<LocationService>((_) => const LocationService());

/// The on-device tile store.
///
/// Behind a provider so map screens can be rendered in a widget test, where
/// `TileCache.instance()` would ask `path_provider` for a directory through a
/// plugin channel that doesn't exist and never complete.
final tileCacheProvider = FutureProvider<TileCache>((_) => TileCache.instance());

final pathRepositoryProvider = Provider<PathRepository>(
  (ref) => PathRepository(ref.watch(firestoreProvider)),
);

/// The campus walking network. Served from Firestore's offline cache when
/// there's no network, so routing survives a dead signal.
final campusGraphProvider = StreamProvider<CampusGraph>(
  (ref) => ref.watch(pathRepositoryProvider).watchGraph(),
);

/// Live GPS position. autoDispose so the GPS chip stops as soon as the last
/// map screen closes — continuous positioning is the main battery cost here.
final positionStreamProvider = StreamProvider.autoDispose<Position>((ref) async* {
  final service = ref.watch(locationServiceProvider);
  await service.ensurePermission();
  yield* service.positionStream();
});

/// A computed walking route to a destination.
class NavigationRoute {
  const NavigationRoute({
    required this.points,
    required this.metres,
    required this.isDirectLine,
  });

  /// Ordered coordinates to draw. Always includes the user's position first and
  /// the destination last.
  final List<({double lat, double lng})> points;

  final double metres;

  /// True when no mapped path connects the two ends, so this is a straight
  /// line. The UI must label it as such rather than implying a walkable route.
  final bool isDirectLine;

  Duration get eta => walkingTime(metres);
}

/// Arguments for [routeProvider] — a destination plus the current fix.
typedef RouteRequest = ({double fromLat, double fromLng, CampusLocation to});

/// Computes the route. Pure function of the graph and the two endpoints, so it
/// recomputes automatically as the user walks.
final routeProvider = Provider.autoDispose.family<NavigationRoute?, RouteRequest>((ref, request) {
  final destination = request.to;
  if (!destination.hasCoordinates) return null;

  final graph = ref.watch(campusGraphProvider).valueOrNull;

  final start = (lat: request.fromLat, lng: request.fromLng);
  final end = (lat: destination.lat!, lng: destination.lng!);

  final path = graph?.route(
    fromLat: start.lat,
    fromLng: start.lng,
    toLat: end.lat,
    toLng: end.lng,
  );

  // No graph, or the two ends aren't connected — fall back to a straight line
  // and say so, rather than pretending a path exists.
  if (path == null || path.isEmpty) {
    return NavigationRoute(
      points: [start, end],
      metres: haversineMetres(start.lat, start.lng, end.lat, end.lng),
      isDirectLine: true,
    );
  }

  final points = <({double lat, double lng})>[
    start,
    for (final node in path) (lat: node.lat, lng: node.lng),
    end,
  ];

  var metres = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    metres += haversineMetres(
      points[i].lat,
      points[i].lng,
      points[i + 1].lat,
      points[i + 1].lng,
    );
  }

  return NavigationRoute(points: points, metres: metres, isDirectLine: false);
});

/// Locations that have been surveyed, so the map only pins real places.
final mappedLocationsProvider = Provider<List<CampusLocation>>((ref) {
  final all = ref.watch(allLocationsProvider).valueOrNull ?? const [];
  return all.where((l) => l.hasCoordinates).toList();
});

/// How many locations still need surveying — surfaced in the admin screen.
final unmappedCountProvider = Provider<int>((ref) {
  final all = ref.watch(allLocationsProvider).valueOrNull ?? const [];
  return all.where((l) => !l.hasCoordinates).length;
});

/// Formats a distance the way a person would say it.
String formatDistance(double metres) {
  if (metres < 1000) return '${metres.round()} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

String formatEta(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return 'less than a minute';
  return '$minutes min walk';
}

/// Walking pace, exposed so the survey screen can explain its ETA maths.
const walkingSpeedMetresPerSecond = AppConfig.walkingSpeed;
