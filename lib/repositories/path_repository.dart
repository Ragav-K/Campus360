import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/failure_mapper.dart';
import '../models/campus_path.dart';

/// Reads and writes `campusPaths/graph` — the campus walking network.
///
/// A single document on purpose: the whole graph is a few KB, and Firestore's
/// offline persistence (enabled in main.dart) caches it automatically. That
/// means routing keeps working with no network, with no extra caching code.
class PathRepository {
  PathRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('campusPaths').doc('graph');

  Stream<CampusGraph> watchGraph() => _doc
      .snapshots()
      .map((snap) => CampusGraph.fromMap(snap.data()))
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  Future<CampusGraph> fetchGraph() => FailureMapper.guard(() async {
        final snap = await _doc.get();
        return CampusGraph.fromMap(snap.data());
      });

  /// Admin-only, from the survey screen.
  Future<void> saveGraph(CampusGraph graph) => FailureMapper.guard(
        () => _doc.set({
          ...graph.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );

  /// Records a surveyed coordinate on a campus location.
  Future<void> setLocationCoordinates({
    required String locationId,
    required double lat,
    required double lng,
    required double accuracyMetres,
  }) =>
      FailureMapper.guard(
        () => _db.collection('campusLocations').doc(locationId).set({
          'geo': {'lat': lat, 'lng': lng},
          // Kept so a later survey can tell whether it's worth re-recording.
          'geoAccuracyMetres': accuracyMetres,
          'geoRecordedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
}
