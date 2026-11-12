import '../models/trip_point.dart';
import '../utils/geo.dart';

/// A day's driving summary for one vehicle, computed from [TripPoint]s
/// (local trip log, or provider history converted to points).
///
/// Classification, per segment between two consecutive points:
/// - driving: speed above 5 km/h;
/// - idling: ignition on and speed at or below 5 km/h;
/// - stopped: everything else (ignition off or unknown).
///
/// Two guards keep the numbers honest: a segment longer than 5 km is
/// treated as a GPS jump and adds no distance, and a time gap over
/// 10 minutes adds no driving/idling/stopped time (the app was closed
/// or polling was paused).
class DaySummary {
  const DaySummary({
    required this.date,
    required this.distanceKm,
    required this.driving,
    required this.idling,
    required this.stopped,
    required this.points,
    this.startTime,
    this.endTime,
  });

  factory DaySummary.empty(DateTime date) => DaySummary(
    date: date,
    distanceKm: 0,
    driving: Duration.zero,
    idling: Duration.zero,
    stopped: Duration.zero,
    points: 0,
  );

  final DateTime date;
  final double distanceKm;
  final Duration driving;
  final Duration idling;
  final Duration stopped;
  final int points;
  final DateTime? startTime;
  final DateTime? endTime;

  Duration get total => driving + idling + stopped;
}

const double _drivingSpeedThresholdKmh = 5;
const double _maxSegmentKm = 5;
const Duration _maxGap = Duration(minutes: 10);

/// Computes [DaySummary] for [day] (local calendar day) from [points].
DaySummary computeDaySummary(List<TripPoint> points, DateTime day) {
  final startOfDay = DateTime(day.year, day.month, day.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  final dayPoints = points
      .where(
        (p) => !p.time.isBefore(startOfDay) && p.time.isBefore(endOfDay),
      )
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  if (dayPoints.isEmpty) return DaySummary.empty(startOfDay);

  var distanceKm = 0.0;
  var driving = Duration.zero;
  var idling = Duration.zero;
  var stopped = Duration.zero;
  for (var i = 0; i + 1 < dayPoints.length; i++) {
    final a = dayPoints[i];
    final b = dayPoints[i + 1];
    final segmentKm = haversineKm(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    if (segmentKm <= _maxSegmentKm) distanceKm += segmentKm;
    final gap = b.time.difference(a.time);
    if (gap <= Duration.zero || gap > _maxGap) continue;
    if ((a.speedKmph ?? 0) > _drivingSpeedThresholdKmh) {
      driving += gap;
    } else if (a.ignition == true) {
      idling += gap;
    } else {
      stopped += gap;
    }
  }
  return DaySummary(
    date: startOfDay,
    distanceKm: distanceKm,
    driving: driving,
    idling: idling,
    stopped: stopped,
    points: dayPoints.length,
    startTime: dayPoints.first.time,
    endTime: dayPoints.last.time,
  );
}

/// Builds a CSV of the day: a summary block, then one row per point.
/// Shared from the vehicle detail screen's "Today's trip" section
/// (share sheet) — no file is written.
String daySummaryCsv({
  required String vehicleName,
  required DaySummary summary,
  required List<TripPoint> points,
}) {
  final buffer = StringBuffer()
    ..writeln('UniTrack day report — $vehicleName')
    ..writeln(
      'Date,${summary.date.year}-${summary.date.month.toString().padLeft(2, '0')}-${summary.date.day.toString().padLeft(2, '0')}',
    )
    ..writeln('Total distance (km),${summary.distanceKm.toStringAsFixed(2)}')
    ..writeln('Driving time (min),${summary.driving.inMinutes}')
    ..writeln('Idling time (min),${summary.idling.inMinutes}')
    ..writeln('Stopped time (min),${summary.stopped.inMinutes}')
    ..writeln('Points,${summary.points}')
    ..writeln()
    ..writeln('Time,Latitude,Longitude,Speed (km/h),Ignition');
  for (final p in points) {
    buffer.writeln(
      '${p.time.toIso8601String()},${p.latitude},${p.longitude},'
      '${p.speedKmph?.toStringAsFixed(1) ?? ''},'
      '${p.ignition == null ? '' : (p.ignition! ? 'on' : 'off')}',
    );
  }
  return buffer.toString();
}
