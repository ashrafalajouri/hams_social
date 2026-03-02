import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';
import 'core/config/remote_config_service.dart';
import 'core/presence/presence_service.dart';
import 'firebase_options.dart';

PresenceService? _presenceService;

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        rethrow;
      }
      Firebase.app();
    }

    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    const enableCrashlyticsInDebug = true;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode || enableCrashlyticsInDebug,
    );
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    await FirebaseAnalytics.instance.logAppOpen();
    try {
      await RemoteConfigService.instance.initialize();
    } catch (e, s) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'remote_config_init_failed',
      );
    }

    ErrorWidget.builder = (details) => Material(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Something went wrong.\nPlease restart the app.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        );

    _presenceService =
        PresenceService(FirebaseAuth.instance, FirebaseDatabase.instance);
    await _presenceService!.start();

    runApp(const ProviderScope(child: HamsApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
