## 0.3.3

### `NumberQuotaReachedException`

The API refuses a session when the workspace is holding every proxy number its
plan allows at once and each of them is already in a live session with one of
the two people being connected. That refusal used to arrive as a `429` and be
surfaced here as `TierLimitException`, which was wrong in the way that matters:
a caller handling a rate limit waits and retries, and this condition does not
clear by waiting. It clears when one of the workspace's sessions ends, or when
a request for more numbers is approved.

So it is now `NumberQuotaReachedException`, and the API answers it with a
`409`.

This is a patch rather than a minor, unlike the same change in the iOS and
Android SDKs. There it is source-breaking: `RelavoiError` is a Swift enum and
`RelavoiException` a Kotlin sealed class, so an exhaustive `switch` or `when`
over either stops compiling when a case is added. Dart has no exhaustiveness
over a plain class hierarchy, so existing `on RelavoiException` and
`on TierLimitException` clauses keep compiling and keep behaving as they did.

An app that wants to tell the two apart adds a clause:

```dart
on NumberQuotaReachedException catch (e) {
  // ask for more numbers; do not retry on a timer
}
```

### The slug decides, not the status

`ApiClient` matches the problem document's `type` slug before it looks at the
status code, so `number-quota-reached` maps to the new type whether it arrives
as a `409` or as the `429` an older deployment sends. An SDK that keyed on the
status would have called it a rate limit for as long as the two sides were out
of step, which is exactly the window a release creates. There are tests for
both statuses, and one that a plain `429` is still `TierLimitException`.

## 0.3.2

### One iOS floor, and it is 13.0

The README and the documentation said iOS 15.0 while the podspec and
`ios/relavoi_flutter/Package.swift` said 13.0. Three releases shipped with the
two disagreeing, and 15.0 was the stricter claim, so anyone with an iOS 13 or
14 deployment target was told to stay away from a plugin that would have
worked.

13.0 is the real floor and every surface now says it. It is what Flutter
itself requires, and what `firebase_messaging`, `url_launcher_ios` and
`shared_preferences_foundation` each declare. This plugin's own Swift needs
iOS 10, using `CXCallObserver` and nothing newer. The 15.0 was the **native
iOS SDK's** floor copied across; that SDK does require 15, and this plugin
does not depend on it, which is also why the `create()` and `list()` crash in
iOS SDK 0.3.0 and 0.3.1 never reached Flutter apps.

Nothing is tightened, so nothing breaks: this widens the devices the plugin is
documented to support.

### The iOS podspec was unedited flutter create boilerplate

It read "A new Flutter plugin project", homepage `http://example.com`, author
"Your Company" at `email@example.com`, and version `0.0.1` against a package
at 0.3.1. That is what a CocoaPods consumer reads and what `pod lib lint`
reports. It now describes the plugin, points at relavoi.com, and names the
Apache-2.0 licence added in 0.3.1.

### A release cannot disagree with its own tag

`scripts/check-release-version.sh` runs on a tag push and fails the release
unless `pubspec.yaml`, the podspec version, the README install ref and the
newest CHANGELOG section all name the tag being cut, and unless the iOS floor
reads the same in the podspec, `Package.swift` and the README.

The iOS SDK has the same check after its 0.3.2 tag had to be force-moved,
which SwiftPM then refused to resolve because it had cached the old revision.
This one also covers the podspec version, because that is the field which sat
at 0.0.1 and which no other check would have caught.

## 0.3.1

### Apache License 2.0

This repository is public and is what integrators read, and it shipped without
a licence. Nobody could use it: no licence means all rights reserved, so a
company's legal review would have stopped an integration whatever the README
promised. The `LICENSE` file here read "TODO: Add your
license here.", which is what `flutter create` leaves behind, and pub.dev
reports a package with an unrecognised licence.

The licence is Apache 2.0, the full text is in `LICENSE`, and the README says
so. Nothing about the code or the API has changed in this release.

## 0.2.0

### Phone numbers: the server decides, not the SDK

The client-side check was strict E.164 (`^\+[1-9]\d{6,14}$`). It was wrong in
both directions, and the second direction is the one that hurt:

* It **refused numbers the API accepts.** Someone typing `08031234567`, or
  pasting `0803 123 4567` out of their contacts, got a client-side error for a
  number the platform would have taken. Only the full `+234...` form worked.
* It **accepted numbers the API refuses**, such as a UK mobile or a Nigerian
  landline, so the SDK let a call to `create` through and the server refused it.

The check is now deliberately light: non-empty, digits, with an optional leading
plus. Separators (spaces, brackets, hyphens, dots, non-breaking spaces, Unicode
dashes) are stripped using the same set the server strips, so the SDK cannot
reject a value the API would accept. The server owns the rule, reads it from its
countries table, and can change it without a new SDK release.

### Two new typed exceptions

The server's refusals now arrive as types you can catch, rather than a generic
`ValidationException`:

* `NumberNotSupportedException` for a number Relavoi does not connect. Today
  that means anything other than a Nigerian mobile.
* `CrossBorderNotSupportedException` when the two parties are not in the same
  country.

Both are matched on the problem document's `type` slug, so they work against any
environment. Neither message contains the number that was refused.

### No part of a phone number in any message or log line

This SDK had the worst of the three, because two log lines carried whole numbers:

* The validation error contained the **first four characters** of the rejected
  value. Removed. The message now names the field and the expected shape.
* `Session created` logged the **proxy number in full**, and `initiateCall`
  logged the number it was dialling in full. Both now log the session id, or
  nothing.
* A failed verification logged the exception's `toString()`. Dio puts the
  request URI in its message, and `/sessions/verify` carries the subscriber's
  number in its query string, so that wrote a plaintext phone number to the
  console. It now logs the exception type and our own message, which is built
  not to carry one.
* Error responses no longer surface a **raw body**, and a connection failure no
  longer surfaces Dio's message. Only `type` and `detail` are read from a
  problem document.

### Possibly breaking

* `ValidationException` is no longer thrown for a number the server refuses.
  Catch `NumberNotSupportedException` and `CrossBorderNotSupportedException`
  first, or catch `RelavoiException` for all of them.
* Exception messages no longer contain the raw response body or Dio's message.
* `PhoneUtils.validateE164` is now `requireNumberShaped` and returns the
  canonical form; `isValidE164` is now `looksLikeNumber`.
* Numbers are sent with separators stripped. `0803 123 4567` goes out as
  `08031234567`.

## 0.1.0

* Initial release of the Relavoi Flutter SDK.
* Session CRUD, native-dialer call initiation, call verification (API + native call-state detection), WebSocket events, presence tracking, and FCM/APNs push registration.
* Android (`TelephonyManager`/`TelephonyCallback`) and iOS (`CXCallObserver`) platform channels for call-state detection and overlay permission.
