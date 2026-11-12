import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cross-tab navigation: which bottom-nav tab is showing, plus an
/// optional focus request (a vehicle to centre the map on).
///
/// Tabs: 0 Fleet, 1 Map, 2 Add, 3 Settings. Screens request
/// navigation through this notifier instead of reaching into the
/// HomeScreen's local state.
///
/// (v1.2.0: Dashboard, Reports and Alerts tabs are gone — the app
/// centres on live tracking + map view. The fleet screen is the
/// dashboard now, and the day report moved into the vehicle detail
/// screen.)
class HomeNavState {
  const HomeNavState({this.tab = 0, this.mapVehicleKey});

  final int tab;

  /// `<providerKey>:<vehicleId>` the Map tab should centre on, once.
  final String? mapVehicleKey;

  HomeNavState copyWith({
    int? tab,
    String? mapVehicleKey,
    bool clearMapFocus = false,
  }) {
    return HomeNavState(
      tab: tab ?? this.tab,
      mapVehicleKey: clearMapFocus ? null : mapVehicleKey ?? this.mapVehicleKey,
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
    state = HomeNavState(tab: 1, mapVehicleKey: vehicleKey);
  }

  void clearMapFocus() {
    state = state.copyWith(clearMapFocus: true);
  }
}

/// Cross-tab navigation for the whole app.
final homeNavProvider =
    NotifierProvider<HomeNavNotifier, HomeNavState>(HomeNavNotifier.new);
