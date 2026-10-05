import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/failure_mapper.dart';
import '../models/campus_location.dart';
import '../models/enums/location_enums.dart';

/// Reads and writes `campusLocations`.
///
/// Locations change rarely and the whole set is small (tens of documents), so
/// this streams the entire active collection once and lets search and category
/// filtering happen in memory. That makes search instant and costs one
/// listener instead of a query per keystroke (§37).
class LocationRepository {
  LocationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Paths.campusLocations);

  Stream<List<CampusLocation>> watchAll() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList())
        .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));
  }

  Stream<CampusLocation?> watchOne(String id) => _col.doc(id).snapshots().map(
        (snap) => snap.exists ? _fromDoc(snap.id, snap.data()!) : null,
      );

  Future<CampusLocation?> fetchOne(String id) => FailureMapper.guard(() async {
        final snap = await _col.doc(id).get();
        return snap.exists ? _fromDoc(snap.id, snap.data()!) : null;
      });

  // ---- admin writes --------------------------------------------------------

  Future<String> create(CampusLocation location) => FailureMapper.guard(() async {
        final ref = await _col.add(_toMap(location));
        return ref.id;
      });

  Future<void> update(CampusLocation location) =>
      FailureMapper.guard(() => _col.doc(location.id).set(_toMap(location), SetOptions(merge: true)));

  Future<void> setActive(String id, bool active) =>
      FailureMapper.guard(() => _col.doc(id).update({'isActive': active}));

  Map<String, dynamic> _toMap(CampusLocation l) => {
        'name': l.name.trim(),
        'category': l.category.name,
        'building': l.building.trim(),
        'floor': l.floor.trim(),
        'roomCode': l.roomCode.trim(),
        'description': l.description.trim(),
        'geo': (l.lat != null && l.lng != null) ? {'lat': l.lat, 'lng': l.lng} : null,
        'openHours': l.openHours.map((h) => h.toMap()).toList(),
        'isActive': l.isActive,
      };

  CampusLocation _fromDoc(String id, Map<String, dynamic> d) {
    final geo = d['geo'] as Map<String, dynamic>?;
    return CampusLocation(
      id: id,
      name: d['name'] as String? ?? '',
      category: LocationCategory.fromName(d['category'] as String?),
      building: d['building'] as String? ?? '',
      floor: d['floor'] as String? ?? '',
      roomCode: d['roomCode'] as String? ?? '',
      description: d['description'] as String? ?? '',
      lat: (geo?['lat'] as num?)?.toDouble(),
      lng: (geo?['lng'] as num?)?.toDouble(),
      openHours: (d['openHours'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(OpenHours.fromMap)
              .toList() ??
          const [],
      isActive: d['isActive'] as bool? ?? true,
    );
  }
}
