# Relavoi Flutter Sample App

Developer test harness for the Relavoi Flutter SDK. Buttons that each exercise one
SDK feature against the live backend (`https://api.relavoi.com/v1`).

## Configure credentials

Credentials are **not** hardcoded. Launch the app and paste the shared **test
workspace's** API key, secret and workspace id into the "API Key", "API Secret"
and "Tenant ID" fields at the top, then tap **Initialize SDK**. The test phone
numbers are pre-filled.

The workspace id is not a secret, but it is ours and this repository is public,
so it is not pre-filled. It is shared out of band with the key and secret, and the dashboard
shows it beside the ready-made snippets on its API keys page.

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
