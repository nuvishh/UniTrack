import 'package:flutter/material.dart';

import '../models/vehicle_category.dart';

/// The icon for a [VehicleCategory], optionally on a tinted tile.
///
/// Used on fleet cards, the detail header, map markers and the
/// Settings saved-vehicle list so the vehicle type reads at a glance.
class VehicleCategoryIcon extends StatelessWidget {
  const VehicleCategoryIcon({
    super.key,
    required this.category,
    this.size = 24,
    this.color,
    this.tileColor,
  });

  final VehicleCategory category;

  /// Icon size in logical pixels.
  final double size;

  /// Icon colour. Defaults to the theme's on-surface colour.
  final Color? color;

  /// When set, the icon sits on a rounded tile of this colour.
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(category.icon, size: size, color: color);
    final tile = tileColor;
    if (tile == null) return icon;
    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: icon),
    );
  }
}
