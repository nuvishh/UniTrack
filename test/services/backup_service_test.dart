import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/services/backup_service.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.
void main() {
  const fakeVehicles = [
    BackupVehicle(
      providerKey: 'aargee',
      deviceId: '860000000000001',
      secret: 'fake-aargee-key',
      regNo: 'KL00XX0000',
      displayName: 'KL00XX0000',
    ),
    BackupVehicle(
      providerKey: 'hashtrace',
      deviceId: '10001',
      secret: 'fake-hashtrace-key',
      displayName: 'BUS 01',
    ),
  ];

  group('buildBackupJson / parseBackup round-trip', () {
    test('export -> import restores identical vehicles + secrets', () {
      final json = buildBackupJson(fakeVehicles);
      final restored = parseBackup(json);
      expect(restored, hasLength(2));
      expect(restored[0].providerKey, 'aargee');
      expect(restored[0].deviceId, '860000000000001');
      expect(restored[0].secret, 'fake-aargee-key');
      expect(restored[0].regNo, 'KL00XX0000');
      expect(restored[0].displayName, 'KL00XX0000');
      expect(restored[1].providerKey, 'hashtrace');
      expect(restored[1].secret, 'fake-hashtrace-key');
      expect(restored[1].regNo, isNull);
    });

    test('the JSON carries the schema version', () {
      final json = buildBackupJson(fakeVehicles);
      expect(json, contains('"schemaVersion": 1'));
      expect(json, contains('"app": "UniTrack"'));
    });
  });

  group('planImport — duplicate skip', () {
    test('same provider + deviceId is skipped, the rest import', () {
      final plan = planImport(fakeVehicles, [
        const BackupVehicle(
          providerKey: 'aargee',
          deviceId: '860000000000001',
          secret: 'another-key',
        ),
        const BackupVehicle(
          providerKey: 'transight',
          deviceId: '860000000000002',
          secret: 'fake-transight-key',
        ),
      ]);
      expect(plan.fresh, hasLength(1));
      expect(plan.fresh.first.providerKey, 'transight');
      expect(plan.skipped, 1);
    });

    test('matching is case-insensitive on the device id', () {
      final plan = planImport(fakeVehicles, [
        const BackupVehicle(
          providerKey: 'aargee',
          deviceId: ' 860000000000001 ',
          secret: 'x',
        ),
      ]);
      expect(plan.fresh, isEmpty);
      expect(plan.skipped, 1);
    });

    test('duplicates inside the file itself are skipped too', () {
      final plan = planImport(const [], [
        const BackupVehicle(
          providerKey: 'aargee',
          deviceId: '860000000000001',
          secret: 'x',
        ),
        const BackupVehicle(
          providerKey: 'aargee',
          deviceId: '860000000000001',
          secret: 'y',
        ),
      ]);
      expect(plan.fresh, hasLength(1));
      expect(plan.skipped, 1);
    });
  });

  group('parseBackup — malformed files', () {
    test('not JSON at all', () {
      expect(
        () => parseBackup('hello world'),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
    });

    test('valid JSON but not a backup (no schema version)', () {
      expect(
        () => parseBackup('{"vehicles": []}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('unsupported schema version', () {
      expect(
        () => parseBackup('{"schemaVersion": 99, "vehicles": []}'),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('v99'),
          ),
        ),
      );
    });

    test('vehicle entry missing its secret', () {
      expect(
        () => parseBackup(
          '{"schemaVersion": 1, "vehicles": '
          '[{"providerKey": "aargee", "deviceId": "123"}]}',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('vehicles is not a list', () {
      expect(
        () => parseBackup('{"schemaVersion": 1, "vehicles": {}}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('error messages never contain the file content', () {
      const secret = 'super-secret-value-12345';
      try {
        parseBackup('{"schemaVersion": 1, "vehicles": "x $secret"}');
        fail('should have thrown');
      } on BackupFormatException catch (e) {
        expect(e.message, isNot(contains(secret)));
      }
    });
  });
}
