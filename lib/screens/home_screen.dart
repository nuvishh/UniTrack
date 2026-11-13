import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_provider.dart';
import 'add_vehicle_screen.dart';
import 'fleet_list_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// Home shell: bottom navigation between Fleet, Map, Add and
/// Settings (Material 3, as in the UI prototype).
///
/// The tab index lives in [homeNavProvider] (not local state) so
/// other screens can switch tabs — a fleet card's "Map" action opens
/// the Map tab centred on that vehicle. The "Add vehicle" FAB shows
/// only on the Fleet tab; the Add tab itself embeds the same wizard
/// (saving there returns to Fleet instead of popping a route).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  List<Widget> _tabs(WidgetRef ref) {
    void goToFleet() => ref.read(homeNavProvider.notifier).goToTab(0);
    return [
      const FleetListScreen(),
      const MapScreen(),
      AddVehicleScreen(onSaved: goToFleet, onBack: goToFleet),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeNavProvider.select((s) => s.tab));
    final tabs = _tabs(ref);
    return Scaffold(
      body: IndexedStack(index: tab, children: tabs),
      floatingActionButton: tab == 0
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
        height: 80,
        selectedIndex: tab,
        onDestinationSelected: (index) =>
            ref.read(homeNavProvider.notifier).goToTab(index),
        destinations: const [
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
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
