# UniTrack — Universal GPS Tracker

One Flutter app to track vehicles from **different GPS providers** in a
single fleet list and map. Each provider is tracked through its own API —
add a vehicle with that provider's credentials and UniTrack polls it,
normalises the result into one vehicle model, and shows everything
together.

> Working name: **UniTrack**. Package: `com.nuvish.unitrack`.

## Providers

| Provider | Key | Auth | History | Status |
|---|---|---|---|---|
| Transight GPS | `transight` | API key | Yes | TODO — endpoints unverified |
| Aargee GPS | `aargee` | API key | Yes | ✅ Verified live 2026-11-09 |
| Radiant / LiveTrace | `radiant` | User ID + key | No (live only) | ✅ Verified live 2026-11-09 |
| MercyDataTrack | `mercydatrack` | Username + password | Yes | TODO — endpoints unverified |
| PauldeaTrack | `pauldeatrack` | Username + password | Yes | TODO — endpoints unverified |
| Voltysoft / SimplyTrack | `voltysoft` | `x-api-key` + user ID | Yes | ✅ Verified live 2026-11-09 |
| HashTrace Tracker | `hashtrace` | Auth key (`authKey`) | No (live only) | ✅ Verified live 2026-11-09 |

"Verified" means the API contract in the code was tested against the
real API on 2026-11-09. "TODO" providers are implemented from the
CampusMan GPS integration guide only — their clients are skeletons with
explicit TODOs and will tell you exactly what is missing instead of
calling an endpoint that was never confirmed. Do not invent endpoint
paths for them; confirm the paths against each provider's API docs
first.

### Verified API contracts (as implemented)

- **LiveTrace (`radiant`)** — POST `http://livetrace.live:1234/Live_All`,
  JSON body `{"header":{"Version":"1.0","clientName":"API_LiveTrace"},
  "request":{"userid":"…","key":"…"}}` → `response.LiveData[]` with
  `Lat, Lon, Speed, Time, Igni, Nick, Reg_No, imei`. Credentials:
  device ID = IMEI and password = `userid:key`, or device ID = user ID
  and password = key. No history.
- **SimplyTrack (`voltysoft`)** — base **must** be
  `https://india.voltysoft.com/api/v12/` (plain http returns 403).
  Header `x-api-key` on every request. `GET /vehicles/{userId}`,
  `GET /vehicles/{userId}/{imei}`,
  `GET /vehicles/{userId}/{imei}/{fromEpoch}/{toEpoch}` for history.
  **100 requests/hour — UniTrack never polls this provider faster than
  60s per account.**
- **HashTrace (`hashtrace`)** — `https://cdn.hashtrace.com/api/Tracker/`,
  auth via `authKey` query parameter. `GET /All` → array,
  `GET /Vehicle?vehicleId=…` → single object; 12 fields
  (`VId, VName, Imei, VPlate, TTime, Lat, Lon, Ign, Spd, Dir, MVolt,
  Batt`). **Lat/Lon are strings; TTime has no timezone.** Missing
  authKey/vehicleId → HTTP 404; wrong key → 200 + `[]`; unknown
  vehicleId → 200 + `_Expired` sentinel (`VId` 0) — UniTrack checks
  for it and never plots it. No history.
- **Aargee (`aargee`)** — `https://rgvtrack.aargee.net/external/api/v2`,
  all POST with JSON body, `apikey` in the body.
  `POST /get_all_vehicles/` (100/day — never polled),
  `POST /get_all_vehicles_last_data/` (500/day — used for polling),
  `POST /get_vehicle_last_data/` (500/day/vehicle),
  `POST /get_vehicle_details/` (10/day/vehicle — history).
  Status codes: 0 server error, 1 success, 2 key not active,
  3 vehicle not assigned, 4 rate limit, 5 data not available.
  Optional `split_latlng: "True"` splits `location` into
  `latitude`/`longitude`. Note: the doc says `time` is UTC, but live
  values matched IST — UniTrack stores and shows the raw string.

### Rate limits (enforced in code)

The tracker never polls a provider account faster than its minimum
interval, however short the global refresh interval is set:
SimplyTrack ≥ 60s, Aargee ≥ 60s, others ≥ 30s.

## Screens

Bold, user-friendly UI (light + dark themes, toggle in Settings):

- **Fleet list** — gradient summary strip (Live / Idle / Offline counts
  + "Updated 2 min ago"), search by reg no or provider, provider filter
  chips, and big vehicle cards (reg no, status pill with pulsing live
  dot, provider badge, large speed, ignition, relative update time).
  Pull to refresh; skeleton while loading, helpful empty state and a
  Retry card on errors.
- **Map** — OpenStreetMap tiles via `flutter_map` (no Google Maps key
  needed). Markers carry the reg no on a status-coloured pin; tap one
  for a bottom sheet with the key facts + "View details". Fit-all and
  recenter buttons, live count chip on top.
- **Vehicle detail** — big status hero (LIVE/IDLE with pulsing dot,
  huge speed readout), ignition, relative update time, coordinates with
  a copy button, provider + device info, and today's route (map
  polyline + points) where the provider supports history; a clear
  "history not supported" note for HashTrace / LiveTrace.
- **Add vehicle** — 3 steps with a progress indicator: 1) pick a
  provider from big tappable cards (verified / setup-needed badge),
  2) credential fields with helper text and inline validation,
  3) test connection with clear success / error states and plain
  "what to check" hints. Save unlocks only after a successful test.
- **Settings** — appearance (Light / Dark / System), refresh interval
  as a segmented control, saved vehicles (with delete), the provider
  table with verified/TODO status, and app info.

## State management — Riverpod

Shared state lives in Riverpod providers under `lib/providers/`
(`flutter_riverpod`, modern `Notifier` / `NotifierProvider` API, no
code generation). The app is wrapped in a `ProviderScope` in
`main.dart`; screens are `ConsumerWidget` / `ConsumerStatefulWidget`
and use `ref.watch` for reactive state, `ref.read` for actions.

| Provider | Owns |
| :--- | :--- |
| `trackerProvider` (`TrackerNotifier`, `TrackerState`) | The fleet: vehicle list, refreshing flag, last error, refresh interval, polling timer. Wraps the existing `TrackerService` (all fetch/poll logic unchanged) and mirrors its state into Riverpod. Methods: `refreshAll()`, `setRefreshInterval()`, `fetchHistoryFor()`. |
| `themeProvider` (`ThemeNotifier`) | `ThemeMode` (light / dark / system), persisted in SharedPreferences under `unitrack_theme_mode_v1` — the same key the old `ThemeController` used. |
| `savedVehiclesProvider` (`FutureProvider`) | The saved-vehicle list (non-secret fields). Invalidate with `ref.invalidate(savedVehiclesProvider)` after adding or deleting a vehicle. |
| `secureStorageServiceProvider` (`Provider`) | The `SecureStorageService` instance, so providers (and tests) can override it. |

**The rule: shared state = Riverpod, local widget state = setState.**
`setState` remains only for truly ephemeral, per-screen state —
the search query and provider filter on the fleet list, the wizard
step / test state / secret visibility on the add-vehicle screen, and
the loaded history on the vehicle detail screen. Nothing shared
crosses screens through setState, and no screen constructs its own
`TrackerService` or theme controller any more.

## Credentials & privacy

- API keys / passwords live **only** in `flutter_secure_storage`
  (Keychain / EncryptedSharedPreferences), under
  `unitrack_secret_<vehicleId>`. They are never logged and never leave
  the device except to the provider's own API.
- The vehicle list (provider, device id, reg no, display name — no
  secrets) lives in `shared_preferences`.
- No Firebase, no backend, no analytics. Example values in code,
  tests and this README are placeholders (`YOUR_API_KEY`,
  `860000000000000`, `KL00XX0000`) — never real credentials.

## Run it

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

> **APK builds must run on your own PC.** The build VM's Gradle setup
> is broken, so this project is delivered as source + analyze + tests
> only — no APK is built here.

## Project layout

```
lib/
  main.dart               # ProviderScope + theme from themeProvider
  models/
    vehicle.dart            # one unified Vehicle for all providers
    gps_provider.dart       # the 7 providers + auth/rate-limit metadata
    provider_credentials.dart
    saved_vehicle.dart      # saved vehicle (non-secret fields only)
  providers/                # Riverpod state (see "State management")
    tracker_provider.dart   # fleet state; wraps TrackerService
    theme_provider.dart     # light / dark / system, persisted
    saved_vehicles_provider.dart
    storage_provider.dart   # the SecureStorageService instance
  services/
    secure_storage_service.dart
    tracker_service.dart    # polls all accounts, de-dupes, exposes state
    providers/
      gps_provider_client.dart      # abstract client interface
      provider_client_factory.dart
      livetrace_client.dart         # radiant — verified
      simplytrack_client.dart       # voltysoft — verified
      hashtrace_client.dart         # verified
      aargee_client.dart            # verified
      transight_client.dart         # TODO — endpoints unverified
      mercydatrack_client.dart      # TODO — endpoints unverified
      pauldeatrack_client.dart      # TODO — endpoints unverified
  screens/
    fleet_list_screen.dart
    map_screen.dart
    vehicle_detail_screen.dart
    add_vehicle_screen.dart
    settings_screen.dart
  theme/
    app_theme.dart          # bold light/dark design system
  utils/
    parsing.dart            # defensive JSON parsers shared by clients
    time_format.dart        # relative times ("2 min ago")
  widgets/
    vehicle_status_chip.dart
    app_widgets.dart        # badges, pills, empty/error states, skeleton
test/
  *_test.dart               # parser unit tests for the 4 verified
                            # providers (fake sample data only)
  providers/
    theme_provider_test.dart
    tracker_provider_test.dart
```

## Next steps

1. Run it on a real device and add one vehicle per provider with your
   own keys — use **Test connection** on the add screen.
2. Confirm the Transight / MercyDataTrack / PauldeaTrack endpoint
   paths against their API docs, implement the three TODO clients,
   and flip their `verified` flags.
3. Optional later: geofence alerts, trip replay playback, per-vehicle
   refresh control.
