// Shared defensive parsers for provider JSON payloads.
//
// Provider APIs are inconsistent about types: coordinates arrive as numbers
// (LiveTrace, SimplyTrack) or quoted strings (HashTrace), ignition as a
// bool, int or string, and some fields are null. Every parser here returns
// null instead of throwing so one bad record never kills a whole fleet
// refresh.

/// Parses a latitude/longitude value that may be a [num] or a [String].
double? parseCoord(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Parses a speed value (km/h) that may be a [num], a [String], or null.
double? parseSpeed(dynamic value) => parseCoord(value);

/// Parses an ignition value that may be a bool, a number, or a string
/// such as "true", "1", "on".
bool? parseIgnition(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'on' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'off' || v == 'no') return false;
  }
  return null;
}

/// Parses a timestamp string. Returns null when the value is missing or
/// unparseable. Note: several providers return times with no timezone
/// marker (Aargee, HashTrace) — those are parsed as local time and the raw
/// string is always kept alongside (see [Vehicle.lastUpdatedRaw]).
DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value.trim());
  return null;
}

/// Normalises a registration number for comparison: strips spaces and
/// dashes and upper-cases it, so "KL 00 XX 0000" matches "KL00XX0000".
String normalizeRegNo(String input) =>
    input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
