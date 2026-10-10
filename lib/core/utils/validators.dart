/// Form validators shared across features. Server rules re-validate the same
/// limits (see firestore.rules); keep the two in sync.
abstract final class Limits {
  static const titleMax = 140;
  static const shortTextMax = 120;
  static const descriptionMax = 2000;
  static const feedbackMin = 10;
  static const feedbackMax = 2000;
  static const questionBodyMax = 4000;
  static const answerBodyMax = 20000;
  static const articleBodyMax = 60000;
}

abstract final class Validators {
  static String? required(String? v, {String field = 'This field'}) =>
      (v == null || v.trim().isEmpty) ? '$field is required.' : null;

  static String? maxLength(String? v, int max) =>
      (v != null && v.trim().length > max)
      ? 'Keep this under $max characters.'
      : null;

  static String? title(String? v) =>
      required(v, field: 'Title') ?? maxLength(v, Limits.titleMax);

  static String? optionalShort(String? v) => maxLength(v, Limits.shortTextMax);

  static String? description(String? v) => maxLength(v, Limits.descriptionMax);

  static String? email(String? v) {
    final r = required(v, field: 'Email');
    if (r != null) return r;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
        ? null
        : 'Enter a valid email address.';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? feedback(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < Limits.feedbackMin) {
      return 'Please give at least ${Limits.feedbackMin} characters of feedback.';
    }
    return maxLength(v, Limits.feedbackMax);
  }
}
