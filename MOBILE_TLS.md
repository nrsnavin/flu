# Mobile TLS cutover (go-live)

The app previously hardcoded the backend as a cleartext URL in ~60 files.
All of them now read a single source of truth — `ApiConfig.baseUrl` in
`src/core/app_config.dart` — which **defaults to the production HTTPS
endpoint** `https://api.baluelastics.com/api/v2`. TLS is live, so a plain
`flutter build` already talks HTTPS; the only remaining hardening is the
platform-level cleartext block below.

## Step 1 — Build (HTTPS is the default)

```sh
flutter build apk --release
# iOS
flutter build ipa --release
```

To point at a different backend (staging, a new domain), override at
build time — no code change:

```sh
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.staging.example.com/api/v2
```

## Step 2 — Block cleartext at the platform level

Belt-and-braces: once the API is HTTPS, forbid cleartext entirely so a
mis-set flag can't silently fall back to `http://`. The `android/` and
`ios/` platform folders are not part of this repo checkout — apply these
in the Flutter project that wraps it.

**Android** — `android/app/src/main/AndroidManifest.xml`, on `<application>`:

```xml
<application
    android:usesCleartextTraffic="false"
    ...>
```

(For a stricter, host-scoped policy use a `network_security_config.xml`
with `<base-config cleartextTrafficPermitted="false">`.)

**iOS** — `ios/Runner/Info.plist`: do **not** add an
`NSAllowsArbitraryLoads=true` ATS exception. ATS blocks cleartext by
default, so simply shipping an `https://` URL is sufficient; remove any
existing arbitrary-loads exception if present.

## Step 3 — Resubmit

HTTPS is baked into the build, so this is a rebuild + store resubmit
(Play Console / App Store). Verify against the HTTPS endpoint before
promoting to production tracks.

## Verifying

- `ApiConfig.isSecure` returns `true` when the app is pointed at HTTPS —
  use it for a debug-build guard/banner if you want a visible signal.
- A production build must fail closed: with cleartext blocked (Step 2),
  an accidental `http://` URL simply won't connect, rather than leaking
  data.
