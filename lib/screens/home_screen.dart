import 'package:flutter/material.dart';

import 'add_vehicle_screen.dart';
import 'fleet_list_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// Home shell: bottom navigation between Fleet, Map and Settings.
///
/// Thumb-reachable navigation (2026-11-11 modern refresh) — the three
/// main views are tabs now instead of small icons in the fleet
/// AppBar. The tabs keep their state in an IndexedStack; the
/// "Add vehicle" action lives here and shows only on the Fleet tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _tabs = [
    FleetListScreen(),
    MapScreen(),
    SettingsScreen(),
  ];

  Future<void> _openAddVehicle() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddVehicle,
              icon: const Icon(Icons.add),
              label: const Text('Add vehicle'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
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
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
