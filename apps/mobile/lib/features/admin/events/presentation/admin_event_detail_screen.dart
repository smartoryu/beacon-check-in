import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/api_models.dart';
import '../../../../core/widgets/sync_status_chip.dart';
import '../application/admin_events_controller.dart';
import '../application/event_time.dart';
import 'beacon_location_sheet.dart';

class AdminEventDetailScreen extends ConsumerWidget {
  const AdminEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(adminEventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: SyncStatusChip()),
          ),
          IconButton(
            onPressed: () => context.push('/manage-events/$eventId/edit'),
            icon: const Icon(Icons.edit),
            tooltip: 'Edit event',
          ),
          IconButton(
            onPressed: () {
              ref.invalidate(adminEventDetailProvider(eventId));
              ref.invalidate(adminEventsProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/scanner'),
        icon: const Icon(Icons.bluetooth_searching),
        label: const Text('Scanner'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminEventDetailProvider(eventId));
          await ref.read(adminEventDetailProvider(eventId).future);
        },
        child: event.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 80),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Unable to load event: $error'),
                ),
              ),
            ],
          ),
          data: (item) => _EventBody(event: item),
        ),
      ),
    );
  }
}

class _EventBody extends ConsumerWidget {
  const _EventBody({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(event.placeName),
                if (event.address != null) Text(event.address!),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.schedule,
                  text:
                      '${formatEventTime(event.startsAt, event.timezone, 'EEE, d MMM yyyy · HH:mm')}\n'
                      '${formatEventTime(event.endsAt, event.timezone, 'EEE, d MMM yyyy · HH:mm')} (${event.timezone})',
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.tune,
                  text:
                      'Floor ${event.floorWidthM.toStringAsFixed(1)} × ${event.floorHeightM.toStringAsFixed(1)} m · '
                      'RSSI ≥ ${event.rssiThresholdDbm} dBm · min ${event.minBeacons} beacon(s)',
                ),
                if (event.coverageRadiusM != null) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.radar,
                    text: 'Coverage radius ${event.coverageRadiusM!.toStringAsFixed(1)} m',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Beacons', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (event.beacons.isEmpty)
          const Text('No beacons attached.')
        else
          ...event.beacons.map(
            (beacon) => _BeaconCard(event: event, beacon: beacon),
          ),
      ],
    );
  }
}

class _BeaconCard extends ConsumerWidget {
  const _BeaconCard({required this.event, required this.beacon});

  final Event event;
  final EventBeacon beacon;

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ConfirmBeaconLocationSheet(
        eventId: event.id,
        beacon: beacon,
      ),
    );
    if (result == true) {
      ref.invalidate(adminEventDetailProvider(event.id));
      ref.invalidate(adminEventsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location saved for ${beacon.label}')),
        );
      }
    }
  }

  void _history(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BeaconLocationHistorySheet(
        eventId: event.id,
        beacon: beacon,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmed = beacon.hasConfirmedLocation;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    beacon.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    confirmed ? 'Location confirmed' : 'Location missing',
                    style: const TextStyle(fontSize: 11),
                  ),
                  color: WidgetStatePropertyAll(
                    (confirmed ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                  ),
                  side: BorderSide(
                    color: (confirmed ? Colors.green : Colors.orange).withValues(alpha: 0.4),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              beacon.identityKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            if (confirmed) ...[
              const SizedBox(height: 8),
              Text(
                '${beacon.latitude!.toStringAsFixed(6)}, ${beacon.longitude!.toStringAsFixed(6)}'
                '${beacon.locationAccuracyM == null ? '' : ' · ±${beacon.locationAccuracyM!.toStringAsFixed(0)} m'}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              if (beacon.locationConfirmedAt != null)
                Text(
                  'Confirmed ${DateFormat('d MMM yyyy · HH:mm').format(beacon.locationConfirmedAt!.toLocal())}'
                  '${beacon.locationConfirmedByName == null ? '' : ' by ${beacon.locationConfirmedByName}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _confirm(context, ref),
                  icon: const Icon(Icons.pin_drop_outlined, size: 18),
                  label: Text(confirmed ? 'Update location' : 'Confirm location'),
                ),
                TextButton.icon(
                  onPressed: () => _history(context),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
