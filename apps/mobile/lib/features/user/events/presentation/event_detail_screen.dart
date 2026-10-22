import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/api_models.dart';
import '../../../../core/widgets/sync_status_chip.dart';
import '../application/events_controller.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: SyncStatusChip()),
          ),
        ],
      ),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load event: $error'),
          ),
        ),
        data: (item) => _Body(event: item),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEEE, d MMMM yyyy · HH:mm');
    final ongoing = event.isOngoing;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              label: Text(ongoing ? 'Ongoing' : 'Not ongoing'),
              color: WidgetStatePropertyAll(
                ongoing ? Colors.green.shade100 : Colors.grey.shade200,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(event.placeName, style: Theme.of(context).textTheme.titleMedium),
        if (event.address != null) Text(event.address!),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.schedule,
                  text:
                      '${formatter.format(event.startsAt.toLocal())}\n${formatter.format(event.endsAt.toLocal())}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.my_location,
                  text:
                      '${event.beacons.length} beacon(s) · minimum ${event.minBeacons} · RSSI ≥ ${event.rssiThresholdDbm} dBm',
                ),
                if (event.coverageRadiusM != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.radar,
                    text: 'Coverage radius ${event.coverageRadiusM!.toStringAsFixed(1)} m',
                  ),
                ],
              ],
            ),
          ),
        ),
        if (event.description != null) ...[
          const SizedBox(height: 12),
          Text(event.description!),
        ],
        const SizedBox(height: 16),
        Text('Beacons in this event', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...event.beacons.map(
          (beacon) => Card(
            child: ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(beacon.label),
              subtitle: Text(beacon.identityKey),
              trailing: Text('(${beacon.x.toStringAsFixed(1)}, ${beacon.y.toStringAsFixed(1)}) m'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: ongoing ? () => context.push('/events/${event.id}/checkin') : null,
          icon: const Icon(Icons.how_to_reg),
          label: Text(ongoing ? 'Check in' : 'Check-in opens during the event'),
        ),
        const SizedBox(height: 8),
        Text(
          'Your check-in is recorded on this device immediately, then synced when online. '
          'The server validates the event window against the recorded time and the beacon coverage rule.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
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
