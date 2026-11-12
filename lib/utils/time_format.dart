import '../models/vehicle.dart';

/// Human-friendly relative time: "just now", "2 min ago", "3 h ago".
///
/// Used everywhere a timestamp is shown, so the fleet reads at a glance.
/// Returns 'Unknown' when there is nothing to format.
String relativeTime(DateTime? when, {DateTime? now}) {
  if (when == null) return 'Unknown';
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.isNegative || diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m min ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  final d = diff.inDays;
  return '$d ${d == 1 ? 'day' : 'days'} ago';
}

/// Relative last-update label for a [Vehicle].
///
/// Prefers the parsed timestamp; falls back to the provider's raw
/// string (several providers omit the timezone, so the raw value is
/// still shown in detail screens as secondary text).
String relativeUpdatedLabel(Vehicle vehicle) {
  if (vehicle.lastUpdated != null) {
    return 'Updated ${relativeTime(vehicle.lastUpdated)}';
  }
  if (vehicle.lastUpdatedRaw.isEmpty) return 'Last update unknown';
  return 'Updated ${vehicle.lastUpdatedRaw}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Short day label: "Today", "Yesterday", or "Nov 12".
String dayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final dayStart = DateTime(day.year, day.month, day.day);
  final diff = dayStart.difference(todayStart).inDays;
  if (diff == 0) return 'Today';
  if (diff == -1) return 'Yesterday';
  return '${_months[day.month - 1]} ${day.day}';
}
