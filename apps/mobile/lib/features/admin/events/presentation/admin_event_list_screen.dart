import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/api_models.dart';
import '../../../../core/widgets/sync_status_chip.dart';
import '../application/admin_events_controller.dart';
import '../application/event_time.dart';

class AdminEventListScreen extends ConsumerWidget {
  const AdminEventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(adminEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Management'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: SyncStatusChip()),
          ),
          IconButton(
            onPressed: () => context.push('/manage-events/new'),
            icon: const Icon(Icons.add),
            tooltip: 'Create event',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/scanner'),
        icon: const Icon(Icons.bluetooth_searching),
        label: const Text('Scanner'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(adminEventsProvider.notifier).refresh(),
        child: events.when(
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
                  child: Text('Unable to load events: $error'),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.event_busy, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No events yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tap + to create the first event.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            items.sort((a, b) => b.startsAt.compareTo(a.startsAt));
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: items.map((event) => _AdminEventCard(event: event)).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _AdminEventCard extends StatelessWidget {
  const _AdminEventCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final confirmed = event.beacons.where((beacon) => beacon.hasConfirmedLocation).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/manage-events/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Chip(
                    label: Text(
                      _eventStatus(event),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(event.placeName),
              const SizedBox(height: 4),
              Text(
                '${formatEventTime(event.startsAt, event.timezone, 'EEE, d MMM · HH:mm')} → '
                '${formatEventTime(event.endsAt, event.timezone, 'EEE, d MMM · HH:mm')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Pill(icon: Icons.bluetooth, text: '${event.beacons.length} beacon(s)'),
                  _Pill(
                    icon: Icons.pin_drop_outlined,
                    text: '$confirmed/${event.beacons.length} located',
                    color: confirmed == event.beacons.length && event.beacons.isNotEmpty
                        ? Colors.green
                        : Colors.orange,
                  ),
                  _Pill(icon: Icons.how_to_reg, text: '${event.checkinCount} check-in(s)'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: effective),
        const SizedBox(width: 3),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _eventStatus(Event event) {
  final now = DateTime.now().toUtc();
  if (now.isBefore(event.startsAt.toUtc())) return 'Upcoming';
  if (now.isAfter(event.endsAt.toUtc())) return 'Past';
  return 'Ongoing';
}
