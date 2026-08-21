import 'package:flutter_test/flutter_test.dart';
import 'package:relavoi_flutter/relavoi_flutter.dart';

void main() {
  test('isInitialized is false before initialize', () {
    expect(Relavoi.isInitialized, isFalse);
  });

  test('Relavoi.instance throws before initialization', () {
    expect(() => Relavoi.instance, throwsA(isA<AssertionError>()));
  });

  test('initialize rejects empty apiKey', () async {
    await expectLater(
      Relavoi.initialize(apiKey: '', apiSecret: 's', tenantId: 't'),
      throwsA(isA<AssertionError>()),
    );
  });

  test('initialize rejects empty apiSecret', () async {
    await expectLater(
      Relavoi.initialize(apiKey: 'k', apiSecret: '', tenantId: 't'),
      throwsA(isA<AssertionError>()),
    );
  });

  test('initialize rejects empty tenantId', () async {
    await expectLater(
      Relavoi.initialize(apiKey: 'k', apiSecret: 's', tenantId: ''),
      throwsA(isA<AssertionError>()),
    );
  });
}
