import '../relavoi_exception.dart';

class PhoneUtils {
  static final _e164Regex = RegExp(r'^\+[1-9]\d{6,14}$');

  static void validateE164(String phone) {
    if (!_e164Regex.hasMatch(phone)) {
      throw ValidationException(
          'Invalid phone number format: must be E.164 (e.g., +2348012345678). Got: ${phone.length > 4 ? '${phone.substring(0, 4)}...' : phone}');
    }
  }

  static bool isValidE164(String phone) => _e164Regex.hasMatch(phone);
}
