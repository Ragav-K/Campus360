/// Form validators. Return null when valid (Flutter's convention).
abstract final class Validators {
  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? required(String? v, {String field = 'This field'}) =>
      (v == null || v.trim().isEmpty) ? '$field is required.' : null;

  /// [allowedDomains] comes from `config/app` at runtime; empty ⇒ any domain.
  static String? email(String? v, {List<String> allowedDomains = const []}) {
    final value = v?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return 'Email is required.';
    if (!_emailRe.hasMatch(value)) return 'Enter a valid email address.';
    if (allowedDomains.isEmpty) return null;

    final domain = value.split('@').last;
    final ok = allowedDomains.any((d) {
      final clean = d.toLowerCase().replaceFirst(RegExp(r'^@'), '');
      return domain == clean || domain.endsWith('.$clean');
    });
    if (!ok) {
      return allowedDomains.length == 1
          ? 'Use your @${allowedDomains.single.replaceFirst(RegExp(r'^@'), '')} college email.'
          : 'Use your college email address.';
    }
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Use at least 8 characters.';
    if (!value.contains(RegExp(r'[A-Za-z]')) || !value.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) =>
      v == original ? null : "Passwords don't match.";

  static String? name(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Name is required.';
    if (value.length < 2) return 'Enter your full name.';
    return null;
  }

  /// Accepts "all", "2-7", "1,3,5-9". Returns null when valid.
  static String? pageRange(String? v, {int? maxPage}) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Enter a page range, e.g. 2-7.';
    if (!RegExp(r'^\d+(-\d+)?(\s*,\s*\d+(-\d+)?)*$').hasMatch(value)) {
      return 'Use a format like 2-7 or 1,3,5-9.';
    }
    for (final part in value.split(',')) {
      final bounds = part.trim().split('-').map(int.parse).toList();
      if (bounds.any((p) => p < 1)) return 'Pages start at 1.';
      if (bounds.length == 2 && bounds[0] > bounds[1]) return 'Ranges must go from low to high.';
      if (maxPage != null && bounds.any((p) => p > maxPage)) {
        return 'This document has only $maxPage pages.';
      }
    }
    return null;
  }

  static String? otp(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Enter the pickup code.';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return 'The pickup code is 6 digits.';
    return null;
  }
}
