import '../models/vehicle.dart';

/// Pure trip-playback state (v1.5.0): which point of a route is
/// showing, how the route splits into travelled / remaining, and the
/// step timing for each speed multiplier.
///
/// No Flutter imports — unit-testable. The UI owns the [Timer] that
/// calls [advance]; this class only holds the position and the math.
class TripPlayback {
  TripPlayback({required List<Vehicle> points, double speedMultiplier = 1.0})
    : _points = List.of(points) {
    _speedMultiplier = speedMultiplier;
    if (_points.isEmpty) {
      throw ArgumentError('TripPlayback needs at least one point');
    }
    if (!speeds.contains(_speedMultiplier)) {
      throw ArgumentError.value(
        _speedMultiplier,
        'speedMultiplier',
        'must be one of $speeds',
      );
    }
  }

  final List<Vehicle> _points;

  /// Assigned in the constructor body (after validation), so it is
  /// `late` rather than an initializing formal.
  late double _speedMultiplier;

  /// 1x, 2x or 4x (see [speeds]).
  double get speedMultiplier => _speedMultiplier;

  set speedMultiplier(double value) {
    if (!speeds.contains(value)) {
      throw ArgumentError.value(
        value,
        'speedMultiplier',
        'must be one of $speeds',
      );
    }
    _speedMultiplier = value;
  }

  /// Index of the point currently shown (0-based).
  int index = 0;

  /// Time between steps at 1x. Faster multipliers shorten it.
  static const baseStep = Duration(milliseconds: 500);

  /// The speed choices offered in the UI.
  static const speeds = [1.0, 2.0, 4.0];

  List<Vehicle> get points => List.unmodifiable(_points);

  bool get isEmpty => _points.isEmpty;

  bool get isAtEnd => _points.isEmpty || index >= _points.length - 1;

  Vehicle? get current =>
      _points.isEmpty ? null : _points[index.clamp(0, _points.length - 1)];

  /// Points up to and including the current one, drawn in the
  /// primary colour.
  List<Vehicle> get travelled =>
      _points.isEmpty
          ? const []
          : _points.sublist(0, (index + 1).clamp(0, _points.length));

  /// Points from the current one on, drawn faded.
  List<Vehicle> get remaining =>
      _points.isEmpty
          ? const []
          : _points.sublist(index.clamp(0, _points.length));

  Duration get stepDuration => Duration(
    milliseconds: (baseStep.inMilliseconds / speedMultiplier).round(),
  );

  /// 0.0–1.0 progress for the scrub slider.
  double get progress =>
      _points.length <= 1 ? 1 : index / (_points.length - 1);

  void advance() {
    if (index < _points.length - 1) index++;
  }

  void seek(int i) {
    index = i.clamp(0, _points.length - 1);
  }

  void restart() {
    index = 0;
  }
}
