import 'package:flutter/material.dart';

/// The kind of vehicle a saved vehicle is: bus, car, truck, bike or
/// other.
///
/// The category is the user's own label for the vehicle — it is set
/// in the add-vehicle wizard, stored on the [SavedVehicle], stamped
/// onto the live [Vehicle] by the tracker, and shown as an icon on
/// fleet cards, the detail header and map markers. It is also a
/// filter on the Fleet screen.
enum VehicleCategory {
  bus(label: 'Bus', icon: Icons.directions_bus),
  car(label: 'Car', icon: Icons.directions_car),
  truck(label: 'Truck', icon: Icons.local_shipping),
  bike(label: 'Bike', icon: Icons.two_wheeler),
  other(label: 'Other', icon: Icons.help_outline);

  const VehicleCategory({required this.label, required this.icon});

  /// Short label shown on filter chips and in the detail screen.
  final String label;

  /// Material icon for the category.
  final IconData icon;

  /// Parses a stored key ('bus', 'car', ...). Unknown or missing
  /// values fall back to [other] so saves from before categories
  /// existed keep working.
  static VehicleCategory fromKey(String? key) {
    for (final category in VehicleCategory.values) {
      if (category.name == key) return category;
    }
    return VehicleCategory.other;
  }
}
