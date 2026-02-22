# Local setup

## 1. Copy environment file and fill in values

Sensitive configuration (API keys, Google Client IDs, etc.) is stored in a `.env` file at the repo root. This file is not committed.

```bash
cp .env.example .env
```

Edit `.env` and fill in your values. See `.env.example` for the list of keys.

## 2. Generate iOS config from .env

The app and Xcode build configurations read from generated files, not from `.env` directly. After editing `.env`, run:

```bash
node scripts/generate_config_from_env.js
```

This creates/updates:

- `Config.plist` (API keys, Mapbox, hosting URLs)
- `nose/Configs/Development.xcconfig`, `Staging.xcconfig`, `Production.xcconfig` (Google OAuth client IDs)
- `noseUITests/Helpers/TestConfig.generated.swift` (UI test user emails, if set in `.env`)

Run this script again whenever you change `.env`.

## 3. Firebase and service account (optional)

- **GoogleService-Info plists:** Get `GoogleService-Info-Development.plist`, `GoogleService-Info-Staging.plist`, and `GoogleService-Info-Production.plist` from the Firebase Console and place them in `FirebaseConfig/`. These are gitignored.
- **Firebase Admin (scripts):** For `scripts/migrate_collection_icons.js`, place a service account key JSON in the repo root as `serviceAccountKey.json` or `serviceAccountKey-{env}.json` (e.g. `serviceAccountKey-dev.json`). Alternatively set `FIREBASE_SERVICE_ACCOUNT_PATH` in `.env` to the path to your key file. These files are gitignored.

## 4. Build

Open the workspace in Xcode and build. Ensure you have run step 2 so that `Config.plist` and the xcconfig files exist.
