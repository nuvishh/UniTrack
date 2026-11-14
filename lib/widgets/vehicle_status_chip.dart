import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';

/// Small coloured badge showing a vehicle's live state, with a pulsing
/// dot while the vehicle is live so the fleet reads at a glance.
///
/// Material You (v1.3.0), as in the prototype's statusBadgeHTML: Live
/// is emerald on a light emerald wash with dark emerald text in light
/// mode (light emerald text in dark mode); Idle is amber the same way;
/// Unknown / Expired are Offline — a surfaceContainerHigh pill with
/// onSurfaceVariant text and an outline dot.
class VehicleStatusChip extends StatelessWidget {
  const VehicleStatusChip({super.key, required this.status});

  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (Color color, Color textColor, Color wash) = switch (status) {
      VehicleStatus.live => (
        AppColors.live,
        isDark ? AppColors.liveTextDark : AppColors.liveTextLight,
        AppColors.live.withValues(alpha: 0.12),
      ),
      VehicleStatus.idle => (
        AppColors.idle,
        isDark ? AppColors.idleTextDark : AppColors.idleTextLight,
        AppColors.idle.withValues(alpha: 0.15),
      ),
      VehicleStatus.unknown => (
        theme.colorScheme.outline,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.surfaceContainerHigh,
      ),
      VehicleStatus.expired => (
        theme.colorScheme.outline,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.surfaceContainerHigh,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(color: color, pulsing: status == VehicleStatus.live),
          const SizedBox(width: 6),
          Text(
            l10n.statusLabel(status),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// A status dot that gently pulses when [pulsing] is true (live
/// vehicles), and stays solid otherwise.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, this.pulsing = false});

  final Color color;
  final bool pulsing;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulsing) _controller.repeat();
  }

  @override
  void didUpdateWidget(PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulsing) {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: 18,
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 9 + 9 * t,
                height: 9 + 9 * t,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
