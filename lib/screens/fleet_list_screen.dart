import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/provider_descriptor.dart';
import '../models/vehicle.dart';
import '../providers/navigation_provider.dart';
import '../providers/registry_provider.dart';
import '../providers/tracker_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_widgets.dart';
import '../widgets/vehicle_status_chip.dart';
import 'add_vehicle_screen.dart';
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
  Set<VehicleStatus>? _selectedStatuses;

  /// Narrows a LIVE selection further by motion: true = moving
  /// (speed above 5 km/h), false = idle (ignition on, not moving).
  /// Null means "don't narrow". The status chips and the summary
  /// strip both write these two fields.
  bool? _movingOnly;
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

  void _openDetail(Vehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: vehicle)),
    );
  }

  List<Vehicle> _filtered(
    List<Vehicle> vehicles,
    Map<String, ProviderDescriptor> descriptors,
  ) {
    // Copy first: the fleet list may be the state's const [] (or any
    // other unmodifiable list) and the sort below mutates in place.
    var list = List<Vehicle>.from(vehicles);
    if (_selectedProviderKey != 'all') {
      list = list.where((v) => v.providerKey == _selectedProviderKey).toList();
    }
    if (_selectedStatuses != null) {
      list = list.where((v) => _selectedStatuses!.contains(v.status)).toList();
    }
    if (_movingOnly != null) {
      final moving = _movingOnly!;
      list = list
          .where(
            (v) =>
                v.status == VehicleStatus.live &&
                (((v.speedKmph ?? 0) > 5) == moving),
          )
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((v) {
        final providerName =
            descriptors[v.providerKey]?.displayName.toLowerCase() ??
            v.providerKey;
        return v.displayName.toLowerCase().contains(q) ||
            (v.imei?.toLowerCase().contains(q) ?? false) ||
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
    final descriptors = ref.watch(providerDescriptorsProvider);
    final descriptorByKey = {
      for (final d in descriptors) d.key: d,
    };
    final filtered = _filtered(vehicles, descriptorByKey);
    final liveCount = vehicles
        .where((v) => v.status == VehicleStatus.live)
        .length;
    final idleCount = vehicles
        .where((v) => v.status == VehicleStatus.idle)
        .length;
    final offlineCount = vehicles.length - liveCount - idleCount;
    final movingCount = vehicles
        .where(
          (v) =>
              v.status == VehicleStatus.live && (v.speedKmph ?? 0) > 5,
        )
        .length;
    final idleMovingCount = liveCount - movingCount;

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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh now',
            onPressed: _refresh,
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
            selectedStatuses: _selectedStatuses,
            onStatTap: (statuses) => setState(() {
              final same =
                  _selectedStatuses != null &&
                  _selectedStatuses!.length == statuses.length &&
                  _selectedStatuses!.containsAll(statuses);
              _selectedStatuses = same ? null : statuses;
              _movingOnly = null;
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by reg no, IMEI or provider',
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
              descriptors: descriptorByKey,
              selectedKey: _selectedProviderKey,
              onSelected: (key) => setState(() => _selectedProviderKey = key),
            ),
          if (vehicles.isNotEmpty)
            _StatusFilterChips(
              total: vehicles.length,
              moving: movingCount,
              idle: idleMovingCount,
              stopped: idleCount,
              selectedStatuses: _selectedStatuses,
              movingOnly: _movingOnly,
              onSelect: (statuses, movingOnly) => setState(() {
                _selectedStatuses = statuses;
                _movingOnly = movingOnly;
              }),
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
            'Try a different reg no, provider or status.',
        actionLabel: 'Clear search & filters',
        onAction: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
            _selectedProviderKey = 'all';
            _selectedStatuses = null;
            _movingOnly = null;
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
          final vehicle = filtered[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VehicleCard(
              vehicle: vehicle,
              onTap: () => _openDetail(vehicle),
              onNavigate: () => _navigate(vehicle),
              onShare: () => _share(vehicle),
              onReports: () => _openReports(vehicle),
              onMap: () => _openOnMap(vehicle),
            ),
          );
        },
      ),
    );
  }

  /// Opens Google Maps directions to the vehicle; falls back to the
  /// in-app map when the vehicle has no fix or Maps won't open.
  Future<void> _navigate(Vehicle vehicle) async {
    if (!vehicle.hasFix) {
      _openOnMap(vehicle);
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${vehicle.latitude},${vehicle.longitude}',
    );
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _openOnMap(vehicle);
    }
  }

  /// Shares the vehicle's live position as text (reg, status, speed,
  /// Google Maps link). Falls back to copying the text when the share
  /// sheet is unavailable.
  Future<void> _share(Vehicle vehicle) async {
    final location = vehicle.hasFix
        ? 'https://maps.google.com/?q=${vehicle.latitude},${vehicle.longitude}'
        : 'No location yet';
    final text =
        '${vehicle.displayName} — ${vehicle.status.name.toUpperCase()}, '
        '${vehicle.speedKmph == null ? 'speed unknown' : '${vehicle.speedKmph!.toStringAsFixed(0)} km/h'}. '
        '${lastUpdatedLabel(vehicle)}. Location: $location';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share unavailable — copied instead.')),
      );
    }
  }

  void _openReports(Vehicle vehicle) {
    ref
        .read(homeNavProvider.notifier)
        .openReportsFor('${vehicle.providerKey}:${vehicle.id}');
  }

  void _openOnMap(Vehicle vehicle) {
    ref
        .read(homeNavProvider.notifier)
        .focusVehicleOnMap('${vehicle.providerKey}:${vehicle.id}');
  }
}

/// Bold gradient strip on top of the fleet: live / idle / offline
/// counts at a glance, plus when the fleet was last refreshed.
///
/// The three counts are tappable: tap one to filter the list to that
/// status, tap it again to clear the filter.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.live,
    required this.idle,
    required this.offline,
    required this.lastRefreshed,
    required this.isRefreshing,
    required this.onRefresh,
    required this.selectedStatuses,
    required this.onStatTap,
  });

  final int live;
  final int idle;
  final int offline;
  final DateTime? lastRefreshed;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final Set<VehicleStatus>? selectedStatuses;
  final void Function(Set<VehicleStatus> statuses) onStatTap;

  Widget _stat(
    BuildContext context,
    int count,
    String label,
    Color dot,
    Set<VehicleStatus> statuses,
  ) {
    final selected =
        selectedStatuses != null &&
        selectedStatuses!.length == statuses.length &&
        selectedStatuses!.containsAll(statuses);
    return Expanded(
      child: InkWell(
        onTap: () => onStatTap(statuses),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
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
        ),
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
              _stat(
                context,
                live,
                'LIVE',
                Colors.white,
                {VehicleStatus.live},
              ),
              _stat(
                context,
                idle,
                'IDLE',
                AppColors.accent,
                {VehicleStatus.idle},
              ),
              _stat(
                context,
                offline,
                'OFFLINE',
                Colors.white70,
                {VehicleStatus.unknown, VehicleStatus.expired},
              ),
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
    required this.descriptors,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<Vehicle> vehicles;
  final Map<String, ProviderDescriptor> descriptors;
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
              : '${descriptors[key]?.displayName ?? key} (${counts[key]})';
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

/// Status filter chips, Volty-style: All / Moving / Idle / Stopped,
/// with counts. They write the same filter state as the tappable
/// summary strip above (Moving = live + speed above 5 km/h, Idle =
/// live + not moving, Stopped = ignition off).
class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({
    required this.total,
    required this.moving,
    required this.idle,
    required this.stopped,
    required this.selectedStatuses,
    required this.movingOnly,
    required this.onSelect,
  });

  final int total;
  final int moving;
  final int idle;
  final int stopped;
  final Set<VehicleStatus>? selectedStatuses;
  final bool? movingOnly;
  final void Function(Set<VehicleStatus>? statuses, bool? movingOnly)
  onSelect;

  bool get _allSelected => selectedStatuses == null && movingOnly == null;

  bool _isSelected(Set<VehicleStatus> statuses, bool? moving) {
    return selectedStatuses != null &&
        selectedStatuses!.length == statuses.length &&
        selectedStatuses!.containsAll(statuses) &&
        movingOnly == moving;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(
      String label,
      int count,
      bool selected,
      VoidCallback onTap,
    ) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$label ($count)',
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
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          chip('All', total, _allSelected, () => onSelect(null, null)),
          chip(
            'Moving',
            moving,
            _isSelected({VehicleStatus.live}, true),
            () => onSelect({VehicleStatus.live}, true),
          ),
          chip(
            'Idle',
            idle,
            _isSelected({VehicleStatus.live}, false),
            () => onSelect({VehicleStatus.live}, false),
          ),
          chip(
            'Stopped',
            stopped,
            _isSelected({VehicleStatus.idle}, null),
            () => onSelect({VehicleStatus.idle}, null),
          ),
        ],
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
/// ignition, large speed and relative update time — plus the four
/// Volty-style actions: Navigate / Share / Reports / Map.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onNavigate,
    required this.onShare,
    required this.onReports,
    required this.onMap,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback onShare;
  final VoidCallback onReports;
  final VoidCallback onMap;

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: AppColors.statusColor(vehicle.status),
              ),
              Expanded(
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
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      Row(
                        children: [
                          _action(
                            context,
                            Icons.navigation_outlined,
                            'Navigate',
                            onNavigate,
                          ),
                          _action(
                            context,
                            Icons.share_outlined,
                            'Share',
                            onShare,
                          ),
                          _action(
                            context,
                            Icons.assignment_outlined,
                            'Reports',
                            onReports,
                          ),
                          _action(
                            context,
                            Icons.map_outlined,
                            'Map',
                            onMap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
