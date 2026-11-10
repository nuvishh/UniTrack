import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gps_provider.dart';
import '../models/vehicle.dart';
import '../providers/tracker_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_widgets.dart';
import '../widgets/vehicle_status_chip.dart';
import 'add_vehicle_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'vehicle_detail_screen.dart';

/// Home screen: every vehicle from every provider, with a live summary,
/// search, provider filters and big readable vehicle cards.
///
/// Shared state (the fleet, refreshing flag, last error) comes from
/// [trackerProvider] via `ref.watch`. Only the search query, the
/// selected provider filter and the "last refreshed" label are local
/// widget state, kept with setState — that is the rule: Riverpod for
/// shared state, setState only for ephemeral local UI state.
class FleetListScreen extends ConsumerStatefulWidget {
  const FleetListScreen({super.key});

  @override
  ConsumerState<FleetListScreen> createState() => _FleetListScreenState();
}

class _FleetListScreenState extends ConsumerState<FleetListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedProviderKey = 'all';
  DateTime? _lastRefreshed;
  bool _wasRefreshing = false;
  Timer? _labelTimer;

  @override
  void initState() {
    super.initState();
    // Stamp the "last refreshed" label when a refresh finishes.
    ref.listenManual(trackerProvider.select((s) => s.isRefreshing), (
      previous,
      next,
    ) {
      if (_wasRefreshing && !next) {
        if (mounted) setState(() => _lastRefreshed = DateTime.now());
      }
      _wasRefreshing = next;
    });
    // Re-render the relative-time labels ("2 min ago") every 30s.
    _labelTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.read(trackerProvider.notifier).refreshAll();

  Future<void> _openAddVehicle() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddVehicleScreen()));
    await _refresh();
  }

  void _openMap() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MapScreen()));
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openDetail(Vehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: vehicle)),
    );
  }

  List<Vehicle> _filtered(List<Vehicle> vehicles) {
    var list = vehicles;
    if (_selectedProviderKey != 'all') {
      list = list.where((v) => v.providerKey == _selectedProviderKey).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((v) {
        final providerName = GpsProvider.fromKey(v.providerKey).displayName
            .toLowerCase();
        return v.displayName.toLowerCase().contains(q) ||
            providerName.contains(q);
      }).toList();
    }
    const order = {
      VehicleStatus.live: 0,
      VehicleStatus.idle: 1,
      VehicleStatus.unknown: 2,
      VehicleStatus.expired: 3,
    };
    list.sort((a, b) {
      final byStatus = order[a.status]!.compareTo(order[b.status]!);
      if (byStatus != 0) return byStatus;
      return a.displayName.compareTo(b.displayName);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackerState = ref.watch(trackerProvider);
    final vehicles = trackerState.vehicles;
    final isRefreshing = trackerState.isRefreshing;
    final error = trackerState.lastError;
    final filtered = _filtered(vehicles);
    final liveCount = vehicles
        .where((v) => v.status == VehicleStatus.live)
        .length;
    final idleCount = vehicles
        .where((v) => v.status == VehicleStatus.idle)
        .length;
    final offlineCount = vehicles.length - liveCount - idleCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('UniTrack'),
            Text(
              vehicles.isEmpty
                  ? 'All your GPS providers, one fleet'
                  : '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} · ${vehicles.map((v) => v.providerKey).toSet().length} provider${vehicles.map((v) => v.providerKey).toSet().length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Map',
            onPressed: _openMap,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          _SummaryStrip(
            live: liveCount,
            idle: idleCount,
            offline: offlineCount,
            lastRefreshed: _lastRefreshed,
            isRefreshing: isRefreshing,
            onRefresh: _refresh,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by reg no or provider',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
          if (vehicles.isNotEmpty)
            _ProviderFilterChips(
              vehicles: vehicles,
              selectedKey: _selectedProviderKey,
              onSelected: (key) => setState(() => _selectedProviderKey = key),
            ),
          if (error != null && vehicles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _InlineErrorBanner(message: error, onRetry: _refresh),
            ),
          Expanded(
            child: _buildList(
              vehicles: vehicles,
              filtered: filtered,
              isRefreshing: isRefreshing,
              error: error,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Add vehicle'),
      ),
    );
  }

  Widget _buildList({
    required List<Vehicle> vehicles,
    required List<Vehicle> filtered,
    required bool isRefreshing,
    required String? error,
  }) {
    if (isRefreshing && vehicles.isEmpty) {
      return const FleetListSkeleton();
    }
    if (vehicles.isEmpty) {
      if (error != null) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ErrorStateCard(message: error, onRetry: _refresh),
            const SizedBox(height: 24),
            EmptyState(
              icon: Icons.directions_bus_outlined,
              title: 'No vehicles yet',
              message:
                  'Add a vehicle from any GPS provider — Transight, '
                  'Aargee, LiveTrace, MercyDataTrack, PauldeaTrack, '
                  'SimplyTrack or HashTrace — and track them all here.',
              actionLabel: 'Add your first vehicle',
              onAction: _openAddVehicle,
            ),
          ],
        );
      }
      return EmptyState(
        icon: Icons.directions_bus_outlined,
        title: 'No vehicles yet',
        message:
            'Add a vehicle from any GPS provider — Transight, Aargee, '
            'LiveTrace, MercyDataTrack, PauldeaTrack, SimplyTrack or '
            'HashTrace — and track them all here.',
        actionLabel: 'Add your first vehicle',
        onAction: _openAddVehicle,
      );
    }
    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'No matches',
        message:
            'Nothing in the fleet matches "$_searchQuery". '
            'Try a different reg no or provider.',
        actionLabel: 'Clear search & filters',
        onAction: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
            _selectedProviderKey = 'all';
          });
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VehicleCard(
              vehicle: filtered[index],
              onTap: () => _openDetail(filtered[index]),
            ),
          );
        },
      ),
    );
  }
}

/// Bold gradient strip on top of the fleet: live / idle / offline
/// counts at a glance, plus when the fleet was last refreshed.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.live,
    required this.idle,
    required this.offline,
    required this.lastRefreshed,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final int live;
  final int idle;
  final int offline;
  final DateTime? lastRefreshed;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  Widget _stat(BuildContext context, int count, String label, Color dot) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updated = lastRefreshed == null
        ? 'Not updated yet'
        : 'Updated ${relativeTime(lastRefreshed)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF00A896)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _stat(context, live, 'LIVE', Colors.white),
              _stat(context, idle, 'IDLE', AppColors.accent),
              _stat(context, offline, 'OFFLINE', Colors.white70),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                isRefreshing ? Icons.sync : Icons.check_circle_outline,
                size: 18,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isRefreshing ? 'Updating…' : updated,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal provider filter chips: All + one per provider in the fleet.
class _ProviderFilterChips extends StatelessWidget {
  const _ProviderFilterChips({
    required this.vehicles,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<Vehicle> vehicles;
  final String selectedKey;
  final void Function(String key) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final v in vehicles) {
      counts[v.providerKey] = (counts[v.providerKey] ?? 0) + 1;
    }
    final keys = ['all', ...counts.keys.toList()..sort()];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: keys.map((key) {
          final selected = key == selectedKey;
          final label = key == 'all'
              ? 'All (${vehicles.length})'
              : '${GpsProvider.fromKey(key).displayName} (${counts[key]})';
          final color = key == 'all'
              ? theme.colorScheme.primary
              : AppColors.providerColor(key);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? color
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Slim inline error banner shown above the list when a refresh failed
/// but vehicles are still on screen.
class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.expired.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.expired.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.expired),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// One vehicle, big and readable: reg no, status pill, provider badge,
/// ignition, large speed and relative update time.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ignition = vehicle.ignition == null
        ? 'Ignition unknown'
        : vehicle.ignition!
        ? 'Ignition on'
        : 'Ignition off';
    final ignitionColor = vehicle.ignition == null
        ? theme.colorScheme.onSurfaceVariant
        : vehicle.ignition!
        ? AppColors.live
        : AppColors.idle;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  VehicleStatusChip(status: vehicle.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ProviderBadge(providerKey: vehicle.providerKey),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.power_settings_new,
                    size: 16,
                    color: ignitionColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ignition,
                    style: TextStyle(
                      color: ignitionColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (vehicle.speedKmph != null) ...[
                    Text(
                      vehicle.speedKmph!.toStringAsFixed(0),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'km/h',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ] else
                    Text(
                      '—',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 36,
                      ),
                    ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lastUpdatedLabel(vehicle),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
