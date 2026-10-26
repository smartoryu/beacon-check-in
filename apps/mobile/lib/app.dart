import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/offline/offline_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class BeaconCheckInApp extends ConsumerStatefulWidget {
  const BeaconCheckInApp({super.key});

  @override
  ConsumerState<BeaconCheckInApp> createState() => _BeaconCheckInAppState();
}

class _BeaconCheckInAppState extends ConsumerState<BeaconCheckInApp> {
  @override
  void initState() {
    super.initState();
    ref.read(syncWorkerProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beacon Check-In',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
