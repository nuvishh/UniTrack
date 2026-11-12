import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/vehicle_category.dart';

void main() {
  group('VehicleCategory', () {
    test('every category has a label and a distinct icon', () {
      expect(VehicleCategory.values, hasLength(5));
      final labels = VehicleCategory.values.map((c) => c.label).toSet();
      expect(labels, {'Bus', 'Car', 'Truck', 'Bike', 'Other'});
      final icons = VehicleCategory.values.map((c) => c.icon).toSet();
      expect(icons, hasLength(5));
    });

    test('icons are the expected Material icons', () {
      expect(VehicleCategory.bus.icon, Icons.directions_bus);
      expect(VehicleCategory.car.icon, Icons.directions_car);
      expect(VehicleCategory.truck.icon, Icons.local_shipping);
      expect(VehicleCategory.bike.icon, Icons.two_wheeler);
      expect(VehicleCategory.other.icon, Icons.help_outline);
    });

    test('fromKey parses stored keys and falls back to other', () {
      expect(VehicleCategory.fromKey('bus'), VehicleCategory.bus);
      expect(VehicleCategory.fromKey('car'), VehicleCategory.car);
      expect(VehicleCategory.fromKey('truck'), VehicleCategory.truck);
      expect(VehicleCategory.fromKey('bike'), VehicleCategory.bike);
      expect(VehicleCategory.fromKey('other'), VehicleCategory.other);
      expect(VehicleCategory.fromKey(null), VehicleCategory.other);
      expect(VehicleCategory.fromKey(''), VehicleCategory.other);
      expect(VehicleCategory.fromKey('spaceship'), VehicleCategory.other);
    });
  });
}
