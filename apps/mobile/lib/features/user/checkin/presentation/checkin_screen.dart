import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/providers.dart';
import '../../../../core/widgets/ble_status_banner.dart';
import '../../events/application/events_controller.dart';
import '../application/checkin_controller.dart';

class CheckinScreen extends ConsumerWidget {
  const CheckinScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(title: const Text('Check in')),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load event: $error')),
        data: (item) => _CheckinBody(event: item),
      ),
    );
  }
}

class _CheckinBody extends ConsumerStatefulWidget {
  const _CheckinBody({required this.event});
  final Event event;

  @override
  ConsumerState<_CheckinBody> createState() => _CheckinBodyState();
}

class _CheckinBodyState extends ConsumerState<_CheckinBody> {
  late final CheckinController _controller;
  String? _shownRecordedId;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _controller = CheckinController(
      event: widget.event,
      userId: user?.id ?? '',
      api: ref.read(apiClientProvider),
      queue: ref.read(checkinQueueProvider),
      syncWorker: ref.read(syncWorkerProvider),
    )..addListener(_refresh);
    unawaited(_controller.start());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    final recorded = _controller.state.recorded;
    if (recorded != null && recorded.clientCheckinId != _shownRecordedId) {
      _shownRecordedId = recorded.clientCheckinId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRecordedDialog();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showRecordedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check-in recorded'),
        content: const Text(
          'Your check-in is saved on this device. It will be validated and synced automatically when the API is reachable.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/history');
            },
            child: const Text('View history'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final hasReadings = state.discovered.isNotEmpty;
    final canRetry =
        !state.scanning && !state.recording && state.recorded == null;
    return RefreshIndicator(
      onRefresh: _controller.start,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          BleStatusBanner(
            status: _controller.scanService.status,
            onEnableBluetooth: () => _controller.scanService.enableBluetooth(),
            onRetry: _controller.retry,
            onStartScan: _controller.start,
          ),
          Text(
            widget.event.title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(widget.event.placeName),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.scanning) ...[
                    LinearProgressIndicator(value: state.secondsLeft / 8),
                    const SizedBox(height: 8),
                    Text('Scanning for event beacons… ${state.secondsLeft}s'),
                  ] else if (state.recording) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Scan complete. Recording your check-in…'),
                  ] else
                    Text(
                      hasReadings
                          ? 'Check-in recorded. It will sync automatically in the background.'
                          : 'No event beacons found. Move closer and scan again.',
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Required: at least ${widget.event.minBeacons} beacon(s) with RSSI ≥ ${widget.event.rssiThresholdDbm} dBm while the event is ongoing.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(state.error!),
              ),
            ),
          ],
          const SizedBox(height: 8),
          ...state.discovered.map(
            (beacon) => Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(beacon.localName ?? beacon.identityKey),
                subtitle: Text(
                  '${beacon.identityKey}\nRSSI ${beacon.medianRssi} dBm · ${beacon.samples.length} sample(s)',
                ),
                isThreeLine: true,
                trailing: Text(
                  '${beacon.measuredPower} dBm\n@1m',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (AppConfig.enableDebugScanner)
            OutlinedButton.icon(
              onPressed: _controller.simulate,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Simulate beacon readings (debug)'),
            ),
          if (canRetry) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _controller.start,
              icon: const Icon(Icons.refresh),
              label: Text(hasReadings ? 'Try again' : 'Scan again'),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'The scan and check-in happen in one step. The result is saved locally first, then synced when online.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
