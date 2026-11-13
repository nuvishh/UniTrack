import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/provider_descriptor.dart';
import '../models/vehicle.dart';
import '../models/vehicle_category.dart';
import '../providers/navigation_provider.dart';
import '../providers/registry_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/tracker_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_widgets.dart';
import '../widgets/vehicle_category_icon.dart';
import '../widgets/vehicle_status_chip.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

/// Home screen: every vehicle from every provider, with a live summary,
/// search, provider + category filters and big readable vehicle cards.
///
/// The fleet screen is also the app's dashboard now (v1.2.0): the
/// gradient summary strip on top carries the Live / Idle / Offline
/// counts, tappable as status filters.
///
/// Shared state (the fleet, refreshing flag, last error) comes from
/// [trackerProvider] via `ref.watch`. Only the search query, the
/// selected filters and the "last refreshed" label are local widget
/// state, kept with setState — that is the rule: Riverpod for
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
  VehicleCategory? _selectedCategory;
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
    if (_selectedCategory != null) {
      list = list.where((v) => v.category == _selectedCategory).toList();
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

  void _toggleTheme() {
    final mode = ref.read(themeProvider);
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);
    ref
        .read(themeProvider.notifier)
        .setMode(isDark ? ThemeMode.light : ThemeMode.dark);
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_on,
                color: theme.colorScheme.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
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
            ),
          ],
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainer,
              foregroundColor: theme.colorScheme.onSurface,
            ),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            onPressed: _toggleTheme,
          ),
          const SizedBox(width: 6),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
            ),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh now',
            onPressed: _refresh,
          ),
          const SizedBox(width: 4),
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
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
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
            _CategoryFilterChips(
              vehicles: vehicles,
              selected: _selectedCategory,
              onSelected: (category) =>
                  setState(() => _selectedCategory = category),
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
      // The empty state is tall (icon + long message + button); on a
      // short screen the filter rows above leave too little room, so
      // it scrolls instead of overflowing.
      return _ScrollableEmptyState(
        child: EmptyState(
          icon: Icons.directions_bus_outlined,
          title: 'No vehicles yet',
          message:
              'Add a vehicle from any GPS provider — Transight, Aargee, '
              'LiveTrace, MercyDataTrack, PauldeaTrack, SimplyTrack or '
              'HashTrace — and track them all here.',
          actionLabel: 'Add your first vehicle',
          onAction: _openAddVehicle,
        ),
      );
    }
    if (filtered.isEmpty) {
      return _ScrollableEmptyState(
        child: EmptyState(
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
              _selectedCategory = null;
              _selectedStatuses = null;
              _movingOnly = null;
            });
          },
        ),
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

  void _openOnMap(Vehicle vehicle) {
    ref
        .read(homeNavProvider.notifier)
        .focusVehicleOnMap('${vehicle.providerKey}:${vehicle.id}');
  }
}

/// Empty state that scrolls when the space above it (summary strip +
/// filter rows) leaves too little room, and centres its content when
/// there is room to spare.
class _ScrollableEmptyState extends StatelessWidget {
  const _ScrollableEmptyState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

/// Tonal fleet summary (Material You, v1.3.0): a primary-container
/// card with Live / Idle / Offline stat tiles in surfaceContainerLowest
/// (light) / surfaceContainerLow (dark), as in the prototype. No
/// gradient — the old indigo strip is gone.
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
    required this.selectedStatuses,
    required this.onStatTap,
  });

  final int live;
  final int idle;
  final int offline;
  final DateTime? lastRefreshed;
  final bool isRefreshing;
  final Set<VehicleStatus>? selectedStatuses;
  final void Function(Set<VehicleStatus> statuses) onStatTap;

  Widget _stat(
    BuildContext context,
    int count,
    String label,
    Color dot,
    Set<VehicleStatus> statuses,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected =
        selectedStatuses != null &&
        selectedStatuses!.length == statuses.length &&
        selectedStatuses!.containsAll(statuses);
    return Expanded(
      child: InkWell(
        onTap: () => onStatTap(statuses),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerLow
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
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
    final isDark = theme.brightness == Brightness.dark;
    final updated = isRefreshing
        ? 'Updating…'
        : lastRefreshed == null
        ? 'Not updated yet'
        : 'Updated ${relativeTime(lastRefreshed)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Prototype: primaryContainer at 55% in light, plain
        // surfaceContainer in dark.
        color: isDark
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PulsingDot(color: AppColors.live, pulsing: live > 0),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Multi-API Telemetry',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onPrimaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHigh
                        : theme.colorScheme.surfaceContainerLowest.withValues(
                            alpha: 0.8,
                          ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    updated,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(
                context,
                live,
                'Live',
                AppColors.live,
                {VehicleStatus.live},
              ),
              const SizedBox(width: 8),
              _stat(
                context,
                idle,
                'Idle',
                AppColors.idle,
                {VehicleStatus.idle},
              ),
              const SizedBox(width: 8),
              _stat(
                context,
                offline,
                'Offline',
                AppColors.unknown,
                {VehicleStatus.unknown, VehicleStatus.expired},
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
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(
                        Icons.check,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Vehicle-type filter chips: All + one per category present in the
/// fleet, with counts. Combines with the search, status and provider
/// filters — a vehicle must pass all of them to show.
class _CategoryFilterChips extends StatelessWidget {
  const _CategoryFilterChips({
    required this.vehicles,
    required this.selected,
    required this.onSelected,
  });

  final List<Vehicle> vehicles;
  final VehicleCategory? selected;
  final void Function(VehicleCategory?) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <VehicleCategory, int>{};
    for (final v in vehicles) {
      counts[v.category] = (counts[v.category] ?? 0) + 1;
    }
    final categories = VehicleCategory.values
        .where((c) => counts.containsKey(c))
        .toList();
    if (categories.isEmpty) return const SizedBox.shrink();
    Widget chip({
      required Widget label,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                child: label,
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
          chip(
            label: Text('All (${vehicles.length})'),
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          ...categories.map(
            (category) => chip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon),
                  const SizedBox(width: 6),
                  Text('${category.label} (${counts[category]})'),
                ],
              ),
              isSelected: selected == category,
              onTap: () => onSelected(category),
            ),
          ),
        ],
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
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              '$label ($count)',
              style: TextStyle(
                color: selected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
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
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.error),
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

/// One vehicle, big and readable: category icon, reg no, status pill,
/// provider badge, ignition, large speed and relative update time —
/// plus the three actions: Navigate / Share / Map.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onNavigate,
    required this.onShare,
    required this.onMap,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback onShare;
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
    final ignitionOn = vehicle.ignition == true;
    final ignitionUnknown = vehicle.ignition == null;
    final speedIsLive = vehicle.status == VehicleStatus.live;
    return Card(
      clipBehavior: Clip.antiAlias,
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
                  VehicleCategoryIcon(
                    category: vehicle.category,
                    size: 22,
                    color: AppColors.statusColor(vehicle.status),
                    tileColor: AppColors.statusColor(
                      vehicle.status,
                    ).withValues(alpha: 0.12),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vehicle.displayName,
                      style: AppTheme.mono(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
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
                  // Tonal IGN chip (prototype): secondaryContainer
                  // when on, surfaceContainer when off / unknown.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ignitionOn
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ignitionUnknown
                          ? 'IGN ?'
                          : ignitionOn
                          ? 'IGN ON'
                          : 'IGN OFF',
                      style: TextStyle(
                        color: ignitionOn
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
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
                        color: speedIsLive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
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
                  // The trailing "last updated" label is long
                  // ("Last update unknown"); let it truncate
                  // instead of overflowing on narrow screens.
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          lastUpdatedLabel(vehicle),
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
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
                  _action(context, Icons.map_outlined, 'Map', onMap),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
