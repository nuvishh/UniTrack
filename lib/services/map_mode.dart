/// Which map the Map tab shows.
///
/// OpenStreetMap (flutter_map) is the default and needs no key.
/// Google Maps (google_maps_flutter) is used only when the user has
/// saved their own Google Maps API key in Settings.
enum MapType {
  openStreetMap,
  googleMaps;

  static MapType fromName(String? name) => MapType.values.firstWhere(
    (v) => v.name == name,
    orElse: () => MapType.openStreetMap,
  );
}

/// Pure map-mode selection (v1.5.0).
///
/// Google Maps is available only when a key is saved; without a key
/// the app always falls back to OpenStreetMap, whatever the stored
/// choice says. With a key saved, the user's explicit toggle wins;
/// with no explicit choice the default is Google Maps.
MapType selectMapType({
  required bool hasGoogleMapsKey,
  MapType? userChoice,
}) {
  if (!hasGoogleMapsKey) return MapType.openStreetMap;
  return userChoice ?? MapType.googleMaps;
}

/// Google Maps link for a live location, shared by "Share live
/// location" (vehicle detail) and the map bottom sheet.
String liveLocationUrl(double latitude, double longitude) =>
    'https://maps.google.com/?q=$latitude,$longitude';
