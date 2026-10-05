import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/firebase_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Offline-first reads: cached Firestore data keeps Pulse, Map and order
    // history readable without a connection (§31, §37).
    //
    // Applied to the named-database instance, not FirebaseFirestore.instance —
    // see firebase_providers.dart for why this project uses a named database.
    campus360Firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Uncaught framework error: ${details.exception}');
    };

    runApp(const ProviderScope(child: Campus360App()));
  }, (error, stack) {
    // Phase 5 hooks Crashlytics in here. Until then, don't swallow silently.
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
