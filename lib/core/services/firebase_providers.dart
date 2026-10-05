import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firestore_paths.dart';
import '../../models/remote_config.dart';

/// The Firestore database id this project uses. See [firestoreProvider].
const kFirestoreDatabaseId = 'default';

/// The single Firestore instance for the app, bound to [kFirestoreDatabaseId].
final campus360Firestore = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: kFirestoreDatabaseId,
);

/// Root DI for Firebase SDK singletons. Overriding these in a ProviderScope is
/// how tests inject fakes/emulators without touching any repository.
final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// This project's Firestore database is a *named* database ("default"), not
/// Firestore's conventional "(default)" one. `FirebaseFirestore.instance`
/// targets "(default)", which does not exist here and fails with NOT_FOUND, so
/// every read must go through this provider.
///
/// Keep [kFirestoreDatabaseId] in sync with `firebase.json` → firestore.database.
final firestoreProvider = Provider<FirebaseFirestore>((_) => campus360Firestore);
final storageProvider = Provider<FirebaseStorage>((_) => FirebaseStorage.instance);
final functionsProvider = Provider<FirebaseFunctions>((_) => FirebaseFunctions.instance);

/// Campus-configurable policy (allowed email domains, upload limits, feature
/// availability). Falls back to compiled defaults if the doc is missing or
/// unreachable, so the app never hard-fails on a config read.
final remoteConfigProvider = StreamProvider<RemoteConfig>((ref) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection(Paths.config)
      .doc(Paths.appConfigDoc)
      .snapshots()
      .map((snap) => RemoteConfig.fromMap(snap.data()))
      .handleError((_) => RemoteConfig.fallback);
});

/// Non-async accessor for places that cannot await (validators, guards).
final remoteConfigValueProvider = Provider<RemoteConfig>(
  (ref) => ref.watch(remoteConfigProvider).valueOrNull ?? RemoteConfig.fallback,
);
