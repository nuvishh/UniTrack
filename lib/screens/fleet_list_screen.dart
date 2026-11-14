import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/provider_descriptor.dart';
import '../models/vehicle.dart';
import '../models/vehicle_category.dart';
import '../providers/navigation_provider.dart';
import '../providers/registry_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/tracker_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/vehicle_category_icon.dart';
import '../widgets/vehicle_status_chip.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

/// Home screen: every vehicle from every provider, with a live summary,
/// search, a compact status filter bar and big readable vehicle cards.
/// Provider + category filters live in the Filters bottom sheet
/// (v1.3.1) — three chip rows took up the whole screen.
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
    final l10n = AppLocalizations.of(context);
    final trackerState = ref.watch(trackerProvider);
    final vehicles = trackerState.vehicles;
    final isRefreshing = trackerState.isRefreshing;
    final error = trackerState.lastError;
    final descriptors = ref.watch(providerDescriptorsProvider);
    final descriptorByKey = {for (final d in descriptors) d.key: d};
    final filtered = _filtered(vehicles, descriptorByKey);
    final liveCount = vehicles
        .where((v) => v.status == VehicleStatus.live)
        .length;
    final idleCount = vehicles
        .where((v) => v.status == VehicleStatus.idle)
        .length;
    final offlineCount = vehicles.length - liveCount - idleCount;
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
                  Text(l10n.appTitle),
                  Text(
                    vehicles.isEmpty
                        ? l10n.appSubtitle
                        : l10n.fleetSubtitle(
                            vehicles.length,
                            vehicles.map((v) => v.providerKey).toSet().length,
                          ),
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
            tooltip: isDark ? l10n.themeToggleLight : l10n.themeToggleDark,
            onPressed: _toggleTheme,
          ),
          const SizedBox(width: 6),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
            ),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refreshNow,
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
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
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
                        tooltip: l10n.clearSearch,
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
            _FilterBar(
              total: vehicles.length,
              live: liveCount,
              idle: idleCount,
              offline: offlineCount,
              selectedStatuses: _selectedStatuses,
              onSelectStatus: (statuses) => setState(() {
                _selectedStatuses = statuses;
              }),
              activeFilterCount:
                  (_selectedProviderKey != 'all' ? 1 : 0) +
                  (_selectedCategory != null ? 1 : 0),
              onOpenFilters: _openFilterSheet,
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
    final l10n = AppLocalizations.of(context);
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
              title: l10n.emptyFleetTitle,
              message: l10n.emptyFleetMessage,
              actionLabel: l10n.emptyFleetAction,
              onAction: _openAddVehicle,
            ),
          ],
        );
      }
      // The empty state is tall (icon + long message + button); on a
      // short screen the summary strip + filter bar above leave too
      // little room, so it scrolls instead of overflowing.
      return _ScrollableEmptyState(
        child: EmptyState(
          icon: Icons.directions_bus_outlined,
          title: l10n.emptyFleetTitle,
          message: l10n.emptyFleetMessage,
          actionLabel: l10n.emptyFleetAction,
          onAction: _openAddVehicle,
        ),
      );
    }
    if (filtered.isEmpty) {
      return _ScrollableEmptyState(
        child: EmptyState(
          icon: Icons.search_off_outlined,
          title: l10n.noMatchesTitle,
          message: l10n.noMatchesDetail(_searchQuery),
          actionLabel: l10n.noMatchesAction,
          onAction: () {
            _searchController.clear();
            setState(() {
              _searchQuery = '';
              _selectedProviderKey = 'all';
              _selectedCategory = null;
              _selectedStatuses = null;
            });
          },
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _openOnMap(vehicle);
    }
  }

  /// Shares the vehicle's live position as text (reg, status, speed,
  /// Google Maps link). Falls back to copying the text when the share
  /// sheet is unavailable.
  Future<void> _share(Vehicle vehicle) async {
    final l10n = AppLocalizations.of(context);
    final location = vehicle.hasFix
        ? 'https://maps.google.com/?q=${vehicle.latitude},${vehicle.longitude}'
        : l10n.noLocation;
    final text =
        '${vehicle.displayName} — ${l10n.statusLabel(vehicle.status).toUpperCase()}, '
        '${vehicle.speedKmph == null ? l10n.speedUnknown : '${vehicle.speedKmph!.toStringAsFixed(0)} km/h'}. '
        '${l10n.lastUpdatedLabel(vehicle)}. Location: $location';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shareUnavailableCopied)));
    }
  }

  void _openOnMap(Vehicle vehicle) {
    ref
        .read(homeNavProvider.notifier)
        .focusVehicleOnMap('${vehicle.providerKey}:${vehicle.id}');
  }

  /// The Filters bottom sheet: provider + category chips live here
  /// now (v1.3.1) instead of two more chip rows on the screen — the
  /// user said the rows took up the whole screen. The compact bar
  /// above keeps only the status chips; the sheet holds the rest.
  ///
  /// Tapping a chip applies immediately: the parent filter state
  /// updates (so the list behind the sheet filters at once) and the
  /// sheet repaints via [StatefulBuilder]. "Clear all" resets
  /// provider + category to All (status untouched); "Done" closes.
  Future<void> _openFilterSheet() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final descriptors = ref.read(providerDescriptorsProvider);
    final descriptorByKey = {for (final d in descriptors) d.key: d};
    final vehicles = ref.read(trackerProvider).vehicles;
    final providerCounts = <String, int>{};
    final categoryCounts = <VehicleCategory, int>{};
    for (final v in vehicles) {
      providerCounts[v.providerKey] = (providerCounts[v.providerKey] ?? 0) + 1;
      categoryCounts[v.category] = (categoryCounts[v.category] ?? 0) + 1;
    }
    final providerKeys = ['all', ...providerCounts.keys.toList()..sort()];
    final categories = VehicleCategory.values
        .where((c) => categoryCounts.containsKey(c))
        .toList();

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applyProvider(String key) {
              setState(() => _selectedProviderKey = key);
              setSheetState(() {});
            }

            void applyCategory(VehicleCategory? category) {
              setState(() => _selectedCategory = category);
              setSheetState(() {});
            }

            void clearAll() {
              setState(() {
                _selectedProviderKey = 'all';
                _selectedCategory = null;
              });
              setSheetState(() {});
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.filters, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Text(l10n.provider, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Column(
                    key: const Key('filterProviderSection'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: providerKeys.map((key) {
                          final selected = key == _selectedProviderKey;
                          final label = key == 'all'
                              ? l10n.countChip(l10n.filterAll, vehicles.length)
                              : '${descriptorByKey[key]?.displayName ?? key} (${providerCounts[key]})';
                          return _FilterChip(
                            label: label,
                            selected: selected,
                            showCheck: true,
                            onTap: () => applyProvider(key),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.category, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Column(
                    key: const Key('filterCategorySection'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: l10n.countChip(
                              l10n.filterAll,
                              vehicles.length,
                            ),
                            selected: _selectedCategory == null,
                            onTap: () => applyCategory(null),
                          ),
                          ...categories.map(
                            (category) => _FilterChip(
                              label: l10n.countChip(
                                l10n.categoryLabel(category),
                                categoryCounts[category]!,
                              ),
                              selected: _selectedCategory == category,
                              icon: category.icon,
                              onTap: () => applyCategory(category),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(
                        onPressed: clearAll,
                        child: Text(l10n.clearAll),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.done),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              color: selected ? theme.colorScheme.primary : Colors.transparent,
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
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final updated = isRefreshing
        ? l10n.updating
        : lastRefreshed == null
        ? l10n.notUpdatedYet
        : l10n.tp('updatedPrefix', {'time': l10n.relativeTime(lastRefreshed)});
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
                  l10n.multiApiTelemetry,
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
              _stat(context, live, l10n.filterLive, AppColors.live, {
                VehicleStatus.live,
              }),
              const SizedBox(width: 8),
              _stat(context, idle, l10n.filterIdle, AppColors.idle, {
                VehicleStatus.idle,
              }),
              const SizedBox(width: 8),
              _stat(context, offline, l10n.filterOffline, AppColors.unknown, {
                VehicleStatus.unknown,
                VehicleStatus.expired,
              }),
            ],
          ),
        ],
      ),
    );
  }
}

/// One pill filter chip (shared by the compact status bar and the
/// Filters sheet): secondaryContainer + onSecondaryContainer when
/// selected, surfaceContainerLow + outlineVariant border when not.
/// An optional leading [icon] (category chips) or a check mark when
/// [showCheck] and selected (provider chips).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return GestureDetector(
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && showCheck) ...[
              Icon(Icons.check, size: 16, color: foreground),
              const SizedBox(width: 4),
            ],
            if (icon != null) ...[
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One compact filter bar (v1.3.1): the status chips scroll
/// horizontally in a single ~48px row, with a tune button at the
/// end that opens the Filters sheet (provider + category). The
/// badge on the tune button counts the active non-"All"
/// provider/category filters (hidden while none are active).
///
/// Provider and category chips used to be two more full rows here —
/// three rows of chips pushed the vehicle cards off the screen, so
/// they moved into the sheet. Status stays in the bar because it
/// mirrors the summary strip taps above: same taxonomy
/// (Live = ignition on, Idle = ignition off, Offline = no fix /
/// expired) and the same filter state.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.total,
    required this.live,
    required this.idle,
    required this.offline,
    required this.selectedStatuses,
    required this.onSelectStatus,
    required this.activeFilterCount,
    required this.onOpenFilters,
  });

  final int total;
  final int live;
  final int idle;
  final int offline;
  final Set<VehicleStatus>? selectedStatuses;
  final void Function(Set<VehicleStatus>? statuses) onSelectStatus;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;

  bool get _allSelected => selectedStatuses == null;

  bool _isSelected(Set<VehicleStatus> statuses) {
    return selectedStatuses != null &&
        selectedStatuses!.length == statuses.length &&
        selectedStatuses!.containsAll(statuses);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    Widget tuneButton = IconButton(
      icon: const Icon(Icons.tune),
      tooltip: l10n.filters,
      onPressed: onOpenFilters,
      style: IconButton.styleFrom(
        backgroundColor: activeFilterCount > 0
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainer,
        foregroundColor: activeFilterCount > 0
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onSurface,
      ),
    );
    if (activeFilterCount > 0) {
      tuneButton = Badge(
        key: const Key('filterBadge'),
        // M3 badge, but in the theme's primary (not the error red —
        // the badge means "filters active", not an error).
        backgroundColor: theme.colorScheme.primary,
        textColor: theme.colorScheme.onPrimary,
        label: Text('$activeFilterCount'),
        child: tuneButton,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.countChip(l10n.filterAll, total),
                      selected: _allSelected,
                      onTap: () => onSelectStatus(null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.countChip(l10n.filterLive, live),
                      selected: _isSelected({VehicleStatus.live}),
                      onTap: () => onSelectStatus({VehicleStatus.live}),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.countChip(l10n.filterIdle, idle),
                      selected: _isSelected({VehicleStatus.idle}),
                      onTap: () => onSelectStatus({VehicleStatus.idle}),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.countChip(l10n.filterOffline, offline),
                      selected: _isSelected({
                        VehicleStatus.unknown,
                        VehicleStatus.expired,
                      }),
                      onTap: () => onSelectStatus({
                        VehicleStatus.unknown,
                        VehicleStatus.expired,
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            tuneButton,
          ],
        ),
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
    final l10n = AppLocalizations.of(context);
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
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
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
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
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
    final l10n = AppLocalizations.of(context);
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
                    tileColor: AppColors.statusColor(vehicle.status)
                        .withValues(alpha: 0.12),
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
                          l10n.lastUpdatedLabel(vehicle),
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
                    l10n.navigate,
                    onNavigate,
                  ),
                  _action(context, Icons.share_outlined, l10n.share, onShare),
                  _action(context, Icons.map_outlined, l10n.mapAction, onMap),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
