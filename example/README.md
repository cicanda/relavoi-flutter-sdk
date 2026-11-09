# Relavoi Flutter Sample App

Developer test harness for the Relavoi Flutter SDK. Buttons that each exercise one
SDK feature against the live backend (`https://api.relavoi.com/v1`).

## Credentials: use a workspace of your own

This harness does not ship with a workspace, and the keys to ours are not
shared. A sandbox key is free and takes about a minute, and it means the
sessions you create while trying the SDK are yours rather than mixed into
somebody else's test data.

1. Sign up at <https://app.relavoi.com/signup>.
2. Open **API & Keys** in the dashboard and press **Generate sandbox keys**.
   The key and the secret are shown once, when they are generated, so copy
   both before leaving the page. Regenerating invalidates the previous pair.
3. Copy the workspace id from the **Workspace ID** field at the top of that
   same page. It is not a secret, unlike the two above it.

Sandbox keys talk to the same backend as live ones and need no approval. What
they will not do is place a real call: a sandbox session is routed and recorded
exactly as a live one but never reaches the carrier, which is what makes it
safe to run this harness against the numbers below.

Nothing is hardcoded here. Launch the app and paste the key, the secret and the
workspace id into the "API Key", "API Secret" and "Tenant ID" fields at the
top, then tap **Initialize SDK**. The test phone numbers are pre-filled.

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
