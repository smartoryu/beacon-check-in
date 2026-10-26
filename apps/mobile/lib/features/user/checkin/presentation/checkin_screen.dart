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
  bool _recording = false;

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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    setState(() => _recording = true);
    try {
      await _controller.record();
      if (!mounted) return;
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final hasReadings = state.discovered.isNotEmpty;
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
                  ] else
                    Text(
                      hasReadings
                          ? 'Scan complete. Review the beacons below and record your check-in.'
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
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: state.scanning || !hasReadings || _recording
                ? null
                : _record,
            icon: _recording
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.how_to_reg),
            label: Text(_recording ? 'Recording…' : 'Record check-in'),
          ),
          const SizedBox(height: 8),
          Text(
            'Recorded locally first — the server result appears in History after sync.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
