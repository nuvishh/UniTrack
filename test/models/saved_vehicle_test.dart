import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/saved_vehicle.dart';
import 'package:unitrack/models/vehicle_category.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.
void main() {
  group('SavedVehicle category persistence', () {
    test('category round-trips through JSON', () {
      const vehicle = SavedVehicle(
        id: '1',
        providerKey: 'aargee',
        deviceId: '860000000000001',
        regNo: 'KL00XX0000',
        category: VehicleCategory.truck,
      );
      final restored = SavedVehicle.fromJson(vehicle.toJson());
      expect(restored.category, VehicleCategory.truck);
      expect(restored.id, '1');
      expect(restored.regNo, 'KL00XX0000');
    });

    test('missing category in stored JSON defaults to other', () {
      final restored = SavedVehicle.fromJson({
        'id': '2',
        'providerKey': 'hashtrace',
        'deviceId': '10001',
      });
      expect(restored.category, VehicleCategory.other);
    });

    test('unknown category string defaults to other', () {
      final restored = SavedVehicle.fromJson({
        'id': '3',
        'providerKey': 'hashtrace',
        'deviceId': '10001',
        'category': 'spaceship',
      });
      expect(restored.category, VehicleCategory.other);
    });

    test('default category is other', () {
      const vehicle = SavedVehicle(
        id: '4',
        providerKey: 'aargee',
        deviceId: '860000000000001',
      );
      expect(vehicle.category, VehicleCategory.other);
    });
  });
}
