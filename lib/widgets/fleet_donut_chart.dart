import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One slice of the fleet donut.
class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

/// Fleet status donut, custom-painted (no chart dependency): a thick
/// ring split by status, with the total in the centre.
///
/// Segments are drawn with a small gap between them; a fleet of zero
/// vehicles draws a plain muted ring.
class FleetDonutChart extends StatelessWidget {
  const FleetDonutChart({
    super.key,
    required this.segments,
    required this.total,
    this.size = 220,
    this.thickness = 34,
  });

  final List<DonutSegment> segments;
  final int total;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
              segments: segments,
              total: total,
              thickness: thickness,
              emptyColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 44),
              ),
              Text(
                total == 1 ? 'Vehicle' : 'Vehicles',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.total,
    required this.thickness,
    required this.emptyColor,
  });

  final List<DonutSegment> segments;
  final int total;
  final double thickness;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - thickness / 2;
    const gap = 0.045; // radians between segments
    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = emptyColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      return;
    }
    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.count <= 0) continue;
      final sweep = (segment.count / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.total != total ||
        oldDelegate.thickness != thickness;
  }
}
