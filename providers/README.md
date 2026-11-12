# Provider registry

`registry.json` describes GPS providers in config form so a new provider can
be added (or a provider's endpoints updated) **without an app update**.
It contains **no real keys** — only placeholders (`{secret}`, `{userId}`,
`{username}`, `{password}`, `{deviceId}`, `{imei}`, `{from}`, `{to}`,
`{fromEpoch}`, `{toEpoch}`).

The app fetches it over HTTPS from the fixed URL

```
https://raw.githubusercontent.com/nuvishh/UniTrack/main/providers/registry.json
```

and caches it on-device for 24 hours (SharedPreferences). If the fetch
fails or the JSON is invalid, the app keeps the last good cache — and if
there is no cache at all, it uses the built-in providers only. The app
never breaks when offline.

## Rules (enforced in code)

1. **Built-ins are the source of truth.** The 8 shipped providers
   (LiveTrace, SimplyTrack, HashTrace, Aargee, MercyDataTrack,
   MercyDataTrack (4G), PauldeaTrack, Transight) are served by their
   built-in Dart clients.
   A registry entry can override a built-in's `baseUrl`/endpoints
   **only** when it is marked `"genericCompatible": true` **and**
   `"overrideBuiltin": true` **and** its base URL is HTTPS. Otherwise
   the built-in client wins. (Note: LiveTrace's real base URL is
   `http://`, so a LiveTrace entry can never override the built-in —
   that is deliberate, because the generic client only serves HTTPS.)
2. **A registry entry can ADD a new provider** (a key that is not one
   of the 8 built-ins). It is served by the generic client
   (`RemoteProviderClient`) and shown in the add-vehicle list with a
   **"Remote"** badge. New providers must use HTTPS.
3. **Credentials only ever go to the baseUrl of the provider the user
   configured.** A registry entry cannot redirect a built-in
   provider's credentials anywhere except through rule 1, and the
   registry URL itself is fixed in code — it is never configurable
   from the registry.
4. **Invalid entries are skipped, never fatal.** An entry missing its
   `key`, `baseUrl`, fleet endpoint or field mappings is ignored with
   a warning; the rest of the registry still loads.

## Entry fields

| Field | Meaning |
| --- | --- |
| `key` | Lowercase provider key, e.g. `aargee`. Must match the built-in key to override. |
| `displayName` | Name shown in the UI. |
| `baseUrl` | API root, no trailing slash. |
| `auth.style` | `query` (one query param), `header` (one header), or `body` (one body field). |
| `auth.param` / `auth.headerName` / `auth.bodyField` | The param/header/field name the secret goes in. |
| `auth.secretFormat` | `key` (the whole secret), `userId:key` (split on the first `:`), or `username:password` (split on the first `:`). |
| `deviceIdLabel` / `deviceIdHint`, `secretLabel` / `secretHint` | Labels shown in the add-vehicle wizard. |
| `authKind` | `apiKey`, `userIdAndKey`, or `usernamePassword` (drives the wizard copy). |
| `supportsHistory` | Whether the `history` endpoint exists. |
| `verified` | Whether the endpoint contract was verified live. |
| `genericCompatible` | The generic client can fully serve this entry (rule 1). |
| `overrideBuiltin` | This entry may replace the built-in client (rule 1). |
| `timeoutSeconds`, `minPollIntervalSeconds` | Request timeout and minimum poll gap. |
| `rateLimitNote` | Shown in Settings and the wizard. |
| `fleet` / `vehicle` / `history` | `{method, path, query?, body?}`. Templates use `{secret}`, `{userId}`, `{username}`, `{password}`, `{deviceId}`, `{imei}`, `{from}`/`{to}` (yyyy-MM-dd HH:mm:ss), `{fromEpoch}`/`{toEpoch}` (seconds). |
| `historyDeviceParam` | Which body/query field selects the vehicle for history (`vehicleIdParam` for a vehicle id, `imeiParam` for an IMEI). |
| `fields` | JSON paths (dot-separated, e.g. `response.LiveData`) for `id`, `displayName`, `imei`, `latitude`, `longitude`, `speed`, `ignition`, `lastUpdated`, plus `trueValues`/`falseValues` for ignition mapping. |
| `listPath` | Dot path to the vehicle array in the response; omit when the response itself is the array. |
| `locationField` | When set, lat/lon come from one `"lat lon"` string field. |
| `successCheck` | `{field, equals}` — a response whose field does not equal the value is treated as an error. |
| `deviceMatching` | `strict` (the fetched vehicles must contain the entered device id) or `fleet` (the whole fleet counts as a match). |

## Versioning

Bump the top-level `version` whenever the file changes. The app caches
by version + fetch time and re-fetches at most once every 24 hours
(or on demand from Settings → "Refresh providers").
