import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import 'sync_status_chip.dart';

class MainScaffold extends ConsumerWidget {
  const MainScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final int selectedIndex;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isAdmin = auth.user?.role.isAdmin ?? false;

    final destinations = isAdmin
        ? const [
            NavigationDestination(
              icon: Icon(Icons.bluetooth_searching),
              label: 'Scanner',
            ),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ];

    void go(int index) {
      if (isAdmin) {
        context.go(index == 0 ? '/scanner' : '/profile');
      } else {
        context.go(switch (index) {
          0 => '/events',
          1 => '/history',
          _ => '/profile',
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: SyncStatusChip()),
          ),
          ...?actions,
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: go,
        destinations: destinations,
      ),
    );
  }
}
