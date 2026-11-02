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
