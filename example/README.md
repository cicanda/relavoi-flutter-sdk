# Relavoi Flutter Sample App

Developer test harness for the Relavoi Flutter SDK. Buttons that each exercise one
SDK feature against the live backend (`https://api.relavoi.com/v1`).

## Configure credentials

Credentials are **not** hardcoded. Launch the app and paste the **Bolt Nigeria
test** API key and secret (shared out-of-band) into the "API Key" / "API Secret"
fields at the top, then tap **Initialize SDK**. The tenant ID
(`f656ac1b-3b5d-4af0-8ff1-c4cbc1076144`) and test phone numbers are pre-filled.

## Run

```
cd example
flutter pub get
flutter run          # on a connected device or emulator
```

Tap the buttons top-to-bottom: Initialize SDK → Create Session → Get Session →
Initiate Call → Verify → Connect Events → Update Presence → End Session. Results
stream into the log view at the bottom.

## Notes

- **Android** needs `INTERNET` and `READ_PHONE_STATE` (already declared in
  `android/app/src/main/AndroidManifest.xml`). Grant `READ_PHONE_STATE` at runtime
  for call-state detection.
- **iOS** needs no extra permissions. `CXCallObserver` works without a prompt.
- Push (FCM/APNs) is part of the SDK but not exercised by this harness; it needs
  Firebase configuration (`google-services.json` / `GoogleService-Info.plist`).
