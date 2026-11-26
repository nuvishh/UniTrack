# UniTrack — Universal GPS Tracker

Track vehicles from different GPS providers in one app — one fleet list,
one map, one vehicle view.

UniTrack connects to each provider's own API, normalises the result into
a single vehicle model, and polls it on a schedule you set in Settings.
Add a vehicle with that provider's credentials and it just shows up
alongside the rest of your fleet.

## Download

Get the latest APK from the
[Releases page](https://github.com/nuvishh/UniTrack/releases/latest).
No account, no sign-up — install it and add your vehicles.

## Features

- **9 GPS providers, one fleet** — LiveTrace, SimplyTrack, HashTrace,
  Aargee, Transight, Mercydatrack, Mercydatrack 4G, PauldeaTrack and AVLView.
- **Live map** — OpenStreetMap by default, or Google Maps with your own
  API key (entered in Settings). Switch between them anytime.
- **Fleet list** — live / idle / offline status, search, and filters by
  provider and vehicle category (bus, car, truck, bike).
- **Vehicle detail** — live location, speed, ignition, today's route,
  and trip playback with play / pause, scrub and 1x–4x speed.
- **Share live location** — send a Google Maps link for any live vehicle.
- **Alerts** — ignition on / off, overspeed above 80 km/h, and offline
  notifications (toggle each one in Settings).
- **Your language, your theme** — English and Malayalam, 5 colour themes,
  light and dark mode.
- **Backup & restore** — export your fleet as one JSON file and import it
  on another device.

## Providers

| Provider | Sign-in | Trip history |
| --- | --- | --- |
| Aargee GPS | API key | Yes |
| AVLView | API key | Yes |
| HashTrace | Auth key | No |
| LiveTrace | User ID + key | No |
| Mercydatrack | Username + password | Yes |
| Mercydatrack 4G | Username + password | Yes |
| PauldeaTrack | Username + password | Yes |
| SimplyTrack | API key + user ID | Yes |
| Transight GPS | API key | Yes |

All nine providers are verified against their live APIs. Trip history
is shown where the provider supports it; the others show live location
only.

## Adding a vehicle

1. Open the **Add** tab and pick the provider.
2. Enter the credentials (API key, or username and password).
3. Tap **Test connection** — UniTrack checks that the vehicle actually
   exists on that account before saving.

A test that fails tells you what to check, in plain words.

## Privacy

- API keys and passwords are stored **only on your device**, in secure
  storage (Keychain / EncryptedSharedPreferences). They are never logged.
- The vehicle list (provider, device ID, registration, display name —
  no secrets) is stored in local app storage.
- No account, no backend, no analytics, no ads.

## Build from source

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```
