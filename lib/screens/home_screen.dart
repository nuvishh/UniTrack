import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_provider.dart';
import 'add_vehicle_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'fleet_list_screen.dart';
import 'map_screen.dart';
import 'reports_screen.dart';

/// Home shell: bottom navigation between Dashboard, Fleet, Map,
/// Reports and Alerts.
///
/// The tab index lives in [homeNavProvider] (not local state) so
/// other screens can switch tabs — a fleet card's "Reports" action
/// opens the Reports tab for that vehicle, an alert's "View on Map"
/// opens the Map tab centred on it. Settings moved to a gear icon in
/// the Dashboard AppBar. The "Add vehicle" action shows only on the
/// Fleet tab.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _tabs = [
    DashboardScreen(),
    FleetListScreen(),
    MapScreen(),
    ReportsScreen(),
    AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeNavProvider.select((s) => s.tab));
    return Scaffold(
      body: IndexedStack(index: tab, children: _tabs),
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddVehicleScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add vehicle'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) =>
            ref.read(homeNavProvider.notifier).goToTab(index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: 'Fleet',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
