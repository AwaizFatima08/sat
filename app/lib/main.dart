import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moduleup/app.dart';
import 'package:moduleup/core/clock.dart';
import 'package:moduleup/data/ads_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  final prefs = await SharedPreferences.getInstance();
  final ads = AdMobAdsService(prefs, const SystemClock());
  runApp(
    ProviderScope(
      overrides: [adsServiceProvider.overrideWithValue(ads)],
      child: const ModuleUpApp(),
    ),
  );
  // Consent first, then the ad SDK; the app is usable meanwhile.
  unawaited(
    ads.init().catchError((Object e) => debugPrint('ads init failed: $e')),
  );
}
