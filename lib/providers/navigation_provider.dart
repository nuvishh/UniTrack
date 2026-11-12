import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cross-tab navigation: which bottom-nav tab is showing, plus an
/// optional focus request (a vehicle to centre the map on, or to open
/// Reports for).
///
/// Tabs: 0 Dashboard, 1 Fleet, 2 Map, 3 Reports, 4 Alerts. Screens
/// request navigation through this notifier instead of reaching into
/// the HomeScreen's local state.
class HomeNavState {
  const HomeNavState({
    this.tab = 0,
    this.mapVehicleKey,
    this.reportsVehicleKey,
  });

  final int tab;

  /// `<providerKey>:<vehicleId>` the Map tab should centre on, once.
  final String? mapVehicleKey;

  /// `<providerKey>:<vehicleId>` the Reports tab should select, once.
  final String? reportsVehicleKey;

  HomeNavState copyWith({
    int? tab,
    String? mapVehicleKey,
    String? reportsVehicleKey,
    bool clearMapFocus = false,
    bool clearReportsFocus = false,
  }) {
    return HomeNavState(
      tab: tab ?? this.tab,
      mapVehicleKey: clearMapFocus ? null : mapVehicleKey ?? this.mapVehicleKey,
      reportsVehicleKey: clearReportsFocus
          ? null
          : reportsVehicleKey ?? this.reportsVehicleKey,
    );
  }
}

class HomeNavNotifier extends Notifier<HomeNavState> {
  @override
  HomeNavState build() => const HomeNavState();

  void goToTab(int tab) {
    state = HomeNavState(tab: tab);
  }

  void focusVehicleOnMap(String vehicleKey) {
    state = HomeNavState(tab: 2, mapVehicleKey: vehicleKey);
  }

  void openReportsFor(String vehicleKey) {
    state = HomeNavState(tab: 3, reportsVehicleKey: vehicleKey);
  }

  void clearMapFocus() {
    state = state.copyWith(clearMapFocus: true);
  }

  void clearReportsFocus() {
    state = state.copyWith(clearReportsFocus: true);
  }
}

/// Cross-tab navigation for the whole app.
final homeNavProvider =
    NotifierProvider<HomeNavNotifier, HomeNavState>(HomeNavNotifier.new);
