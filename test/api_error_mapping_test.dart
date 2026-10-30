import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relavoi_flutter/src/client/api_client.dart';
import 'package:relavoi_flutter/src/relavoi_config.dart';
import 'package:relavoi_flutter/src/relavoi_exception.dart';

/// The server owns the number rule, so these two refusals are the SDK's only
/// way to tell a caller "that number cannot be used" as opposed to "your
/// request was malformed".
void main() {
  late ApiClient client;

  setUp(() {
    client = ApiClient(const RelavoiConfig(
      apiKey: 'k',
      apiSecret: 's',
      tenantId: 't',
      baseUrl: 'https://api.example.test/v1',
    ));
  });

  DioException responseError(int status, Object? body) => DioException(
        requestOptions: RequestOptions(path: '/sessions'),
        response: Response(
          requestOptions: RequestOptions(path: '/sessions'),
          statusCode: status,
          data: body,
        ),
        type: DioExceptionType.badResponse,
      );

  Map<String, Object> problem(String slug, String detail) => {
        'type': 'https://api.relavoi.com/errors/$slug',
        'title': 'Unprocessable Entity',
        'status': 422,
        'detail': detail,
      };

  // mapErrorForTest exposes the private mapper; see ApiClient.
  test('maps number-not-supported to NumberNotSupportedException', () {
    final e = client.mapErrorForTest(responseError(
        422,
        problem('number-not-supported',
            'Relavoi currently connects Nigerian mobile numbers only.')));
    expect(e, isA<NumberNotSupportedException>());
    expect(e.message, 'Relavoi currently connects Nigerian mobile numbers only.');
  });

  test('maps cross-border-not-supported to CrossBorderNotSupportedException', () {
    final e = client.mapErrorForTest(responseError(
        422,
        problem('cross-border-not-supported',
            'Both people in a session must have numbers from the same country.')));
    expect(e, isA<CrossBorderNotSupportedException>());
    expect(e.message, contains('same country'));
  });

  test('maps any other 422 to ValidationException', () {
    final e = client.mapErrorForTest(
        responseError(422, problem('validation', 'agentPhone is not valid.')));
    expect(e, isA<ValidationException>());
    expect(e.message, contains('agentPhone'));
  });

  test('matches the slug on any host', () {
    // The type URL's host differs between environments; the slug does not.
    final e = client.mapErrorForTest(responseError(422, {
      'type': 'https://staging.example.test/errors/number-not-supported',
      'detail': 'nope',
    }));
    expect(e, isA<NumberNotSupportedException>());
  });

  test('a 422 that is not a problem document is still a ValidationException', () {
    final e = client.mapErrorForTest(responseError(422, '<html>gateway</html>'));
    expect(e, isA<ValidationException>());
    expect(e.message, isNot(contains('<html>')));
  });

  group('no number reaches an exception message', () {
    // /sessions/verify carries a subscriber's number in its query string, so an
    // error page that echoes the request URI, or Dio's own message, would put a
    // phone number into a crash report.
    const number = '2348031234567';

    test('a raw error body is not surfaced', () {
      final e = client.mapErrorForTest(responseError(502,
          '<html>bad gateway /v1/sessions/verify?userPhone=%2B$number</html>'));
      expect(e.message, isNot(contains(number)));
    });

    test("Dio's own message is not surfaced on a connection error", () {
      final e = client.mapErrorForTest(DioException(
        requestOptions: RequestOptions(
            path: '/sessions/verify?userPhone=%2B$number'),
        type: DioExceptionType.connectionError,
        message:
            'The connection errored: uri=https://api.example.test/v1/sessions/verify?userPhone=%2B$number',
      ));
      expect(e, isA<NetworkException>());
      expect(e.message, isNot(contains(number)));
      expect(e.message, contains('connectionError'));
    });

    test('a timeout does not surface the URI either', () {
      final e = client.mapErrorForTest(DioException(
        requestOptions: RequestOptions(path: '/sessions/verify'),
        type: DioExceptionType.receiveTimeout,
        message: 'timeout on .../verify?userPhone=%2B$number',
      ));
      expect(e, isA<NetworkException>());
      expect(e.message, isNot(contains(number)));
    });
  });
}
