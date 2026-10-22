import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>('checkin_queue');
  await Hive.openBox<dynamic>('event_cache');
  await Hive.openBox<dynamic>('sync_meta');
  runApp(const ProviderScope(child: BeaconCheckInApp()));
}
