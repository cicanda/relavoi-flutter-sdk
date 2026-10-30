import '../relavoi_exception.dart';

/// Phone-number handling at the SDK boundary.
///
/// This used to enforce strict E.164 with `^\+[1-9]\d{6,14}$`, and that was
/// wrong in both directions. It accepted numbers the API refuses, such as a +44
/// mobile or a Nigerian landline, so the SDK promised a session it could not
/// get. More awkwardly it REFUSED the forms the API accepts: someone typing
/// `08031234567`, or pasting `0803 123 4567` out of a contact list, got a
/// client-side error for a number the server would have taken.
///
/// So the client-side check is now deliberately light. The server owns the rule,
/// reads it from the countries table, and can change it without a new SDK
/// release. This only catches what is obviously not a phone number, such as an
/// empty field or a name typed in the wrong box. Anything number-shaped goes to
/// the server, and the server's refusal comes back as a
/// [NumberNotSupportedException].
///
/// Separators are stripped using the same set the server strips, so a value the
/// API would accept is never rejected here. Keeping the two lists in step is the
/// whole point; if the server's set changes, change this one.
///
/// Nothing here ever puts any part of a number into a message. The caller passed
/// the value in, so repeating it buys nothing, and these strings reach the
/// console and crash reporters. The previous version put the FIRST FOUR
/// characters of the rejected value into the exception message.
class PhoneUtils {
  /// Spaces, brackets, hyphens, dots, the non-breaking space and the Unicode
  /// dash range. Mirrors `strip()` in the backend's phone service.
  static final _separators = RegExp(r'[\s()\-. ‐-―]');

  /// Optional leading plus, then at least one ASCII digit, and nothing else.
  static final _numberShaped = RegExp(r'^\+?[0-9]+$');

  /// Remove the separators a person types or a contact list carries. The result
  /// is what gets sent, so the value in a URL or a JSON body is always plain
  /// digits with an optional plus.
  static String canonicalise(String phone) =>
      phone.trim().replaceAll(_separators, '');

  /// Whether [phone] could be a phone number. Says nothing about which country.
  static bool looksLikeNumber(String phone) =>
      _numberShaped.hasMatch(canonicalise(phone));

  /// Returns the canonical form of [phone], or throws a [ValidationException]
  /// if it is not number-shaped.
  ///
  /// The message names the field and describes the expected shape. It does not
  /// contain the value, not even a few characters of it.
  static String requireNumberShaped(String phone, String fieldName) {
    final canonical = canonicalise(phone);
    if (!_numberShaped.hasMatch(canonical)) {
      throw ValidationException(
          "$fieldName is not a phone number. Expected digits, optionally starting with '+'.");
    }
    return canonical;
  }
}
