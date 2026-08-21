import 'package:flutter_test/flutter_test.dart';
import 'package:relavoi_flutter/relavoi_flutter.dart';

void main() {
  group('Session.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'id': 'sess-1',
        'tenantId': 'tenant-1',
        'proxyNumber': '+2342017001428',
        'state': 'ACTIVE',
        'directionMode': 'BIDIRECTIONAL',
        'metadata': {'orderId': 'ORD-1'},
        'gracePeriodMinutes': 30,
        'maxDurationMinutes': 120,
        'recordingEnabled': true,
        'consentPrompt': 'DEFAULT',
        'expiresAt': '2026-08-22T12:00:00.000Z',
        'createdAt': '2026-08-22T10:00:00.000Z',
        'activatedAt': '2026-08-22T10:00:05.000Z',
        'endedAt': null,
        'expiredAt': null,
        'callCount': 3,
        'lastCallAt': '2026-08-22T11:00:00.000Z',
      };
      final s = Session.fromJson(json);
      expect(s.id, 'sess-1');
      expect(s.tenantId, 'tenant-1');
      expect(s.proxyNumber, '+2342017001428');
      expect(s.state, SessionState.active);
      expect(s.directionMode, DirectionMode.bidirectional);
      expect(s.metadata?['orderId'], 'ORD-1');
      expect(s.gracePeriodMinutes, 30);
      expect(s.recordingEnabled, true);
      expect(s.consentPrompt, 'DEFAULT');
      expect(s.callCount, 3);
      expect(s.activatedAt, isNotNull);
      expect(s.endedAt, isNull);
    });

    test('applies defaults for missing optional fields', () {
      final s = Session.fromJson({
        'id': 'sess-2',
        'tenantId': 't',
        'proxyNumber': '+2340000000000',
        'state': 'PENDING',
        'directionMode': 'A_TO_B_ONLY',
        'expiresAt': '2026-08-22T12:00:00.000Z',
        'createdAt': '2026-08-22T10:00:00.000Z',
      });
      expect(s.gracePeriodMinutes, 15);
      expect(s.maxDurationMinutes, 120);
      expect(s.recordingEnabled, false);
      expect(s.consentPrompt, 'NONE');
      expect(s.callCount, 0);
      expect(s.directionMode, DirectionMode.aToB);
    });
  });

  group('SessionState.fromString', () {
    test('handles all states', () {
      expect(SessionState.fromString('PENDING'), SessionState.pending);
      expect(SessionState.fromString('ACTIVE'), SessionState.active);
      expect(SessionState.fromString('GRACE_PERIOD'), SessionState.gracePeriod);
      expect(SessionState.fromString('EXPIRED'), SessionState.expired);
      expect(SessionState.fromString('FAILED'), SessionState.failed);
      expect(SessionState.fromString('nonsense'), SessionState.pending);
    });
  });

  group('SessionListResponse.fromJson', () {
    test('handles empty data', () {
      final r = SessionListResponse.fromJson({
        'data': [],
        'pagination': {'count': 0, 'after': null},
      });
      expect(r.data, isEmpty);
      expect(r.count, 0);
      expect(r.after, isNull);
    });

    test('handles populated data', () {
      final r = SessionListResponse.fromJson({
        'data': [
          {
            'id': 'a',
            'tenantId': 't',
            'proxyNumber': '+2340000000001',
            'state': 'ACTIVE',
            'directionMode': 'BIDIRECTIONAL',
            'expiresAt': '2026-08-22T12:00:00.000Z',
            'createdAt': '2026-08-22T10:00:00.000Z',
          },
        ],
        'pagination': {'count': 1, 'after': 'cursor-1'},
      });
      expect(r.data, hasLength(1));
      expect(r.data.first.id, 'a');
      expect(r.count, 1);
      expect(r.after, 'cursor-1');
    });
  });
}
