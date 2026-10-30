import 'package:flutter_test/flutter_test.dart';
import 'package:relavoi_flutter/src/internal/phone_utils.dart';
import 'package:relavoi_flutter/src/relavoi_exception.dart';

void main() {
  group('PhoneUtils accepts every form the API accepts', () {
    // This is the half the old strict-E.164 check got wrong in the expensive
    // direction: it refused what the server takes, so someone typing their own
    // Nigerian number the normal way got a client-side error.
    const accepted = [
      '08031234567', // local
      '2348031234567', // country code, no plus
      '+2348031234567', // E.164
      '0803 123 4567', // spaces
      '+234 803 123 4567',
      '(0803) 123-4567', // brackets and a hyphen
      '0803.123.4567',
      '  +2348031234567  ', // padded
      '0803 123 4567', // non-breaking spaces, from a contact picker
      '0803–123–4567', // en dashes, from pasted text
    ];

    for (final phone in accepted) {
      test('accepts a ${phone.length}-character form', () {
        expect(PhoneUtils.looksLikeNumber(phone), isTrue);
        expect(() => PhoneUtils.requireNumberShaped(phone, 'agentPhone'),
            returnsNormally);
      });
    }

    test('does not judge the country, that is the server\'s job', () {
      // A UK number and a Nigerian landline are both number-shaped. The SDK
      // sends them and the API refuses them, which is the point: the rule can
      // change server-side without a new SDK release.
      expect(PhoneUtils.looksLikeNumber('+447911123456'), isTrue);
      expect(PhoneUtils.looksLikeNumber('+2341234567'), isTrue);
    });
  });

  group('PhoneUtils refuses only the obvious mistakes', () {
    const rejected = ['', '   ', '+', 'Ada Obi', '+234ABC5678', 'null', '()'];

    for (final phone in rejected) {
      test('rejects ${phone.isEmpty ? '(empty)' : 'a non-number'}', () {
        expect(PhoneUtils.looksLikeNumber(phone), isFalse);
        expect(() => PhoneUtils.requireNumberShaped(phone, 'agentPhone'),
            throwsA(isA<ValidationException>()));
      });
    }

    test('rejects a plus that is not leading', () {
      expect(PhoneUtils.looksLikeNumber('234+8031234567'), isFalse);
      expect(PhoneUtils.looksLikeNumber('08031234567+'), isFalse);
    });

    test('rejects non-ASCII digits', () {
      expect(PhoneUtils.looksLikeNumber('٠٨٠٣'), isFalse);
    });
  });

  group('PhoneUtils.canonicalise', () {
    test('strips separators and keeps a leading plus', () {
      expect(PhoneUtils.canonicalise('+234 803 123 4567'), '+2348031234567');
      expect(PhoneUtils.canonicalise('(0803) 123-4567'), '08031234567');
      expect(PhoneUtils.canonicalise('  +2348031234567  '), '+2348031234567');
    });

    test('requireNumberShaped returns the canonical form', () {
      expect(PhoneUtils.requireNumberShaped('0803 123 4567', 'agentPhone'),
          '08031234567');
    });
  });

  group('no part of a number reaches a message', () {
    test('the message names the field and carries no digits', () {
      // The previous implementation put the FIRST FOUR characters of the
      // rejected value into the message.
      try {
        PhoneUtils.requireNumberShaped('0803123XXXX', 'agentPhone');
        fail('expected a ValidationException');
      } on ValidationException catch (e) {
        expect(e.message, contains('agentPhone'));
        expect(e.message, isNot(contains('0803')));
        expect(e.message, isNot(contains('XXXX')));
        expect(RegExp(r'[0-9]').hasMatch(e.message), isFalse,
            reason: 'no digits of the input, and none of our own');
      }
    });

    test('an all-letters value is not echoed either', () {
      try {
        PhoneUtils.requireNumberShaped('Ada Obi', 'customerPhone');
        fail('expected a ValidationException');
      } on ValidationException catch (e) {
        expect(e.message, isNot(contains('Ada')));
        expect(e.message, contains('customerPhone'));
      }
    });
  });
}
