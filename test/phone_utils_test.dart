import 'package:flutter_test/flutter_test.dart';
import 'package:relavoi_flutter/src/internal/phone_utils.dart';
import 'package:relavoi_flutter/relavoi_flutter.dart' show ValidationException;

void main() {
  group('PhoneUtils.validateE164', () {
    test('valid E.164 passes', () {
      expect(() => PhoneUtils.validateE164('+2348012345678'), returnsNormally);
      expect(PhoneUtils.isValidE164('+2348012345678'), isTrue);
    });

    test('missing + prefix throws', () {
      expect(() => PhoneUtils.validateE164('2348012345678'),
          throwsA(isA<ValidationException>()));
    });

    test('too short throws', () {
      expect(() => PhoneUtils.validateE164('+123'),
          throwsA(isA<ValidationException>()));
    });

    test('letters throw', () {
      expect(() => PhoneUtils.validateE164('+234ABC5678'),
          throwsA(isA<ValidationException>()));
    });

    test('leading zero after + throws', () {
      expect(() => PhoneUtils.validateE164('+0348012345678'),
          throwsA(isA<ValidationException>()));
    });
  });
}
