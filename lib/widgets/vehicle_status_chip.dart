import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

/// Small coloured badge showing a vehicle's live state, with a pulsing
/// dot while the vehicle is live so the fleet reads at a glance.
class VehicleStatusChip extends StatelessWidget {
  const VehicleStatusChip({super.key, required this.status});

  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      VehicleStatus.live => ('Live', AppColors.live),
      VehicleStatus.idle => ('Idle', AppColors.idle),
      VehicleStatus.unknown => ('Unknown', AppColors.unknown),
      VehicleStatus.expired => ('Expired', AppColors.expired),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(color: color, pulsing: status == VehicleStatus.live),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
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

/// Human-readable last-update text from a [Vehicle].
///
/// Relative time ("Updated 2 min ago") when the timestamp parsed,
/// otherwise the provider's raw string.
String lastUpdatedLabel(Vehicle vehicle) {
  if (vehicle.lastUpdated != null) {
    return 'Updated ${relativeTime(vehicle.lastUpdated)}';
  }
  if (vehicle.lastUpdatedRaw.isEmpty) return 'Last update unknown';
  return 'Updated ${vehicle.lastUpdatedRaw}';
}

/// Speed text, or '—' when the provider did not report one.
String speedLabel(Vehicle vehicle) {
  final speed = vehicle.speedKmph;
  if (speed == null) return '—';
  return '${speed.toStringAsFixed(0)} km/h';
}
