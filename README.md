# Relavoi Flutter SDK

Privacy-preserving call and SMS masking for Flutter apps. Works on both Android and iOS.

## Installation

Add to your pubspec.yaml:
```yaml
dependencies:
  relavoi_flutter: ^0.1.0
```

Or from Git (until published to pub.dev):
```yaml
dependencies:
  relavoi_flutter:
    git:
      url: https://github.com/cicanda/relavoi-flutter-sdk.git
      ref: main
```

## Quick Start

```dart
import 'package:relavoi_flutter/relavoi_flutter.dart';

// Initialize once at app startup
await Relavoi.initialize(
  apiKey: 'rk_live_...',
  apiSecret: 'rs_...',
  tenantId: 'your-tenant-uuid',
  config: RelavoiConfig(enableLogging: true),
);

// Create a masking session when an order is assigned
final session = await Relavoi.instance.sessions.create(
  agentPhone: '+2348012345678',
  customerPhone: '+2348087654321',
  metadata: {'orderId': 'ORD-123', 'type': 'delivery'},
);

// Driver taps "Call Customer" - opens native dialer
await Relavoi.instance.sessions.initiateCall(session.proxyNumber);

// Check if incoming call is verified
final result = await Relavoi.instance.verification.verify('+2348012345678');
if (result.verified) {
  // Show green "Verified call" banner
}

// When delivery is complete
await Relavoi.instance.sessions.end(session.id);
```

## Features

| Feature | Description | Requires Native |
|---------|-------------|-----------------|
| Session CRUD | Create, get, list, end masking sessions | No |
| Call initiation | Opens native dialer with proxy number | No |
| Call verification | Check if active call is from the platform | API: No, Detection: Yes |
| Real-time events | WebSocket event stream for call lifecycle | No |
| Push notifications | FCM/APNs for incoming call alerts | No (uses firebase_messaging) |
| Presence tracking | Auto online/background/offline reporting | No |
| Call state detection | Detect if phone call is active | Yes (platform channel) |
| Overlay permission | Floating verification bubble (Android) | Yes (Android only) |

## Permissions

### Android
Add to your AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
```

### iOS
No additional permissions required. CXCallObserver works without user prompt.

## Requirements
- Flutter >= 3.10
- Dart >= 3.0
- Android minSdkVersion 24
- iOS 15.0+

## Documentation
https://docs.relavoi.com
