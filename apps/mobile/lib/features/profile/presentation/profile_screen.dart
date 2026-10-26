import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/offline/offline_providers.dart';
import '../../../core/widgets/main_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final isAdmin = user?.role.isAdmin ?? false;
    final queue = ref.watch(checkinQueueProvider);
    final pending = user == null ? 0 : queue.pendingCountForUser(user.id);

    return MainScaffold(
      title: 'Profile',
      selectedIndex: isAdmin ? 1 : 2,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshUser();
          await ref.read(syncWorkerProvider).syncNow();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      child: Text(
                        (user?.displayName.isNotEmpty ?? false)
                            ? user!.displayName.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.displayName ?? 'Not signed in',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(user?.email ?? ''),
                    const SizedBox(height: 8),
                    Chip(label: Text(user?.role.value ?? '—')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_queue),
                    title: const Text('Queued check-ins'),
                    trailing: Text('$pending'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Sync now'),
                    onTap: () => ref.read(syncWorkerProvider).syncNow(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('API'),
                    subtitle: Text(AppConfig.apiBaseUrl),
                  ),
                  if (AppConfig.enableDebugScanner) ...[
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.science_outlined),
                      title: Text('Debug scanner enabled'),
                      subtitle: Text(
                        'Check-in screens can inject simulated beacon readings.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
