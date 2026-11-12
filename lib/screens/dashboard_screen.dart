import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vehicle.dart';
import '../providers/alerts_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/tracker_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_widgets.dart';
import '../widgets/fleet_donut_chart.dart';
import 'settings_screen.dart';

/// Dashboard (first tab): fleet status at a glance + the latest
/// alerts, Volty-style.
///
/// The donut splits the fleet into Moving / Idle / Stopped /
/// Unreachable, derived from the live vehicle state:
/// - Moving: ignition on and speed above 5 km/h;
/// - Idle: ignition on and speed at or below 5 km/h;
/// - Stopped: ignition off;
/// - Unreachable: no ignition info, or provider-reported expired.
///
/// The Notifications feed shows the newest locally detected alerts;
/// tapping one opens the Alerts tab.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trackerState = ref.watch(trackerProvider);
    final vehicles = trackerState.vehicles;
    final alerts = ref.watch(
      alertsProvider.select((s) => s.alerts),
    );

    var moving = 0;
    var idle = 0;
    var stopped = 0;
    var unreachable = 0;
    for (final vehicle in vehicles) {
      switch (vehicle.status) {
        case VehicleStatus.live:
          if ((vehicle.speedKmph ?? 0) > 5) {
            moving++;
          } else {
            idle++;
          }
        case VehicleStatus.idle:
          stopped++;
        case VehicleStatus.unknown:
        case VehicleStatus.expired:
          unreachable++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh now',
            onPressed: () =>
                ref.read(trackerProvider.notifier).refreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            trackerState.isRefreshing
                ? 'Updating…'
                : vehicles.isEmpty
                ? 'No vehicles yet'
                : '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} · '
                    '${vehicles.map((v) => v.providerKey).toSet().length} '
                    'provider${vehicles.map((v) => v.providerKey).toSet().length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (trackerState.lastError != null && vehicles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ErrorStateCard(
                message: trackerState.lastError!,
                onRetry: () =>
                    ref.read(trackerProvider.notifier).refreshAll(),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  FleetDonutChart(
                    segments: [
                      DonutSegment(
                        label: 'Moving',
                        count: moving,
                        color: AppColors.live,
                      ),
                      DonutSegment(
                        label: 'Idle',
                        count: idle,
                        color: AppColors.idle,
                      ),
                      DonutSegment(
                        label: 'Stopped',
                        count: stopped,
                        color: AppColors.expired,
                      ),
                      DonutSegment(
                        label: 'Unreachable',
                        count: unreachable,
                        color: AppColors.unknown,
                      ),
                    ],
                    total: vehicles.length,
                  ),
                  const SizedBox(height: 20),
                  _LegendGrid(
                    moving: moving,
                    idle: idle,
                    stopped: stopped,
                    unreachable: unreachable,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.notifications_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notifications',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(homeNavProvider.notifier).goToTab(4),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (alerts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No alerts yet — ignition changes, overspeed and '
                  'geofence crossings will appear here as the fleet '
                  'polls.',
                ),
              ),
            )
          else
            ...alerts.take(8).map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationTile(
                  title: alert.title,
                  time: alert.time,
                  vehicleName: alert.vehicleName,
                  onTap: () =>
                      ref.read(homeNavProvider.notifier).goToTab(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two-by-two legend under the donut; tapping a row opens the Fleet
/// tab so the user can see those vehicles.
class _LegendGrid extends ConsumerWidget {
  const _LegendGrid({
    required this.moving,
    required this.idle,
    required this.stopped,
    required this.unreachable,
  });

  final int moving;
  final int idle;
  final int stopped;
  final int unreachable;

  Widget _item(
    BuildContext context,
    WidgetRef ref,
    String label,
    int count,
    Color color,
  ) {
    return InkWell(
      onTap: () => ref.read(homeNavProvider.notifier).goToTab(1),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _item(context, ref, 'Moving', moving, AppColors.live),
            ),
            Expanded(
              child: _item(context, ref, 'Idle', idle, AppColors.idle),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _item(
                context,
                ref,
                'Stopped',
                stopped,
                AppColors.expired,
              ),
            ),
            Expanded(
              child: _item(
                context,
                ref,
                'Unreachable',
                unreachable,
                AppColors.unknown,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.time,
    required this.vehicleName,
    required this.onTap,
  });

  final String title;
  final DateTime time;
  final String vehicleName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOff = title.startsWith('Ignition Off');
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isOff ? AppColors.expired : AppColors.live)
                      .withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: isOff ? AppColors.expired : AppColors.live,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isOff ? AppColors.expired : AppColors.live,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatAlertTime(time),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      vehicleName,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
