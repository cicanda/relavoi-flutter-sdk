import 'package:flutter_test/flutter_test.dart';
import 'package:relavoi_flutter/relavoi_flutter.dart';

void main() {
  // shutdown() stops the presence observer, which needs the widgets binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isInitialized is false before initialize', () {
    expect(Relavoi.isInitialized, isFalse);
  });

  test('Relavoi.instance throws before initialization', () {
    expect(() => Relavoi.instance, throwsA(isA<AssertionError>()));
  });

  // These are ArgumentError rather than AssertionError on purpose. An assert
  // is stripped from a release build, so the old checks did nothing in the
  // builds that matter: an empty key sailed through and failed later, at the
  // token endpoint, as a 401 nobody could explain.

  test('initialize refuses an empty apiKey', () async {
    await expectLater(
      Relavoi.initialize(apiKey: '', apiSecret: 's', tenantId: 't'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('initialize refuses an empty apiSecret', () async {
    await expectLater(
      Relavoi.initialize(apiKey: 'k', apiSecret: '', tenantId: 't'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('initialize rejects empty tenantId', () async {
    await expectLater(
      Relavoi.initialize(apiKey: 'k', apiSecret: 's', tenantId: ''),
      throwsA(isA<AssertionError>()),
    );
  });

  test('initialize refuses neither form', () async {
    await expectLater(
      Relavoi.initialize(tenantId: 't'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('initialize refuses both forms at once', () async {
    await expectLater(
      Relavoi.initialize(
        tenantId: 't',
        apiKey: 'k',
        apiSecret: 's',
        tokenProvider: () async =>
            const RelavoiToken(accessToken: 'x', expiresInSeconds: 900),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('the token provider form needs no secret at all', () async {
    var asked = 0;
    await Relavoi.initialize(
      tenantId: 'tenant-uuid',
      tokenProvider: () async {
        asked += 1;
        return const RelavoiToken(accessToken: 'device-token', expiresInSeconds: 900);
      },
    );
    // Asked once during initialize, and the SDK is up without a secret ever
    // existing in the process.
    expect(asked, 1);
    expect(Relavoi.isInitialized, isTrue);
    Relavoi.shutdown();
  });
}
