import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/services/map_mode.dart';

void main() {
  group('selectMapType', () {
    test('no key -> OpenStreetMap regardless of choice', () {
      expect(
        selectMapType(hasGoogleMapsKey: false, userChoice: MapType.googleMaps),
        MapType.openStreetMap,
      );
      expect(
        selectMapType(
          hasGoogleMapsKey: false,
          userChoice: MapType.openStreetMap,
        ),
        MapType.openStreetMap,
      );
    });

    test('key saved + user picked Google -> Google Maps', () {
      expect(
        selectMapType(hasGoogleMapsKey: true, userChoice: MapType.googleMaps),
        MapType.googleMaps,
      );
    });

    test('key saved + user picked OSM -> OpenStreetMap', () {
      expect(
        selectMapType(
          hasGoogleMapsKey: true,
          userChoice: MapType.openStreetMap,
        ),
        MapType.openStreetMap,
      );
    });

    test('key saved + no user choice yet -> Google Maps by default', () {
      expect(
        selectMapType(hasGoogleMapsKey: true, userChoice: null),
        MapType.googleMaps,
      );
    });

    test('no key + no user choice -> OpenStreetMap', () {
      expect(
        selectMapType(hasGoogleMapsKey: false, userChoice: null),
        MapType.openStreetMap,
      );
    });
  });

  group('liveLocationUrl', () {
    test('builds a Google Maps link with the coordinates', () {
      expect(
        liveLocationUrl(9.9938, 76.2844),
        'https://maps.google.com/?q=9.9938,76.2844',
      );
    });

    test('negative coordinates keep their sign', () {
      expect(
        liveLocationUrl(-33.8688, 151.2093),
        'https://maps.google.com/?q=-33.8688,151.2093',
      );
    });
  });
}
