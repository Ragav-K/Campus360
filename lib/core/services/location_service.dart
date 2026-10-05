import 'package:geolocator/geolocator.dart';

import '../errors/app_failure.dart';

/// GPS access, with every failure mapped to an [AppFailure] so the map screens
/// reuse the app's existing error states instead of inventing their own.
///
/// Positioning works with no network at all — GPS reads satellites. Only the
/// *first* fix is slower offline, because assisted-GPS normally downloads
/// satellite almanac data over the network. That is what makes offline
/// navigation possible.
class LocationService {
  const LocationService();

  static const _denied = AppFailure(
    kind: FailureKind.permission,
    message: 'Location permission is needed to show where you are on the map.',
    isRetryable: true,
  );

  static const _deniedForever = AppFailure(
    kind: FailureKind.permission,
    message: 'Location is blocked for Campus360. Enable it in Settings to use navigation.',
    isRetryable: false,
  );

  static const _serviceOff = AppFailure(
    kind: FailureKind.permission,
    message: 'Turn on location (GPS) to see where you are.',
    isRetryable: true,
  );

  /// Requests permission if needed. Throws an [AppFailure] describing exactly
  /// what the user must do.
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw _serviceOff;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) throw _denied;
    if (permission == LocationPermission.deniedForever) throw _deniedForever;
  }

  /// A single fix. Used by the survey screen, where one accurate reading
  /// matters more than a continuous stream.
  Future<Position> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    await ensurePermission();
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeout),
      );
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure(
        kind: FailureKind.unknown,
        // Offline first fixes are genuinely slow — say so rather than blaming
        // the user's connection, which is irrelevant to GPS.
        message: 'Could not get a GPS fix. Step outside or into the open and try again.',
        debug: e.toString(),
      );
    }
  }

  /// Continuous position while navigating.
  ///
  /// The distance filter keeps the GPS chip from reporting every metre of jitter
  /// while standing still, which is the main battery cost of live navigation.
  Stream<Position> positionStream({int distanceFilterMetres = 3}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilterMetres,
      ),
    );
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
