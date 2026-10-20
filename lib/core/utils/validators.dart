/// Form validation helpers. Each returns an error message, or null if valid.
class Validators {
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? notEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Use both letters and numbers';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? phone(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Phone number is required' : null;
    }
    if (normalizePhone(value) == null) {
      return 'Enter a valid number, e.g. 012-345 6789 or +60123456789';
    }
    return null;
  }

  /// Converts a phone number to international format (+60...), which
  /// SMS providers need. Local Malaysian numbers like 012-345 6789
  /// become +60123456789. Returns null if the number is invalid.
  static String? normalizePhone(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '');
    if (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(cleaned)) return cleaned;
    if (RegExp(r'^0\d{8,10}$').hasMatch(cleaned)) {
      return '+60${cleaned.substring(1)}';
    }
    if (RegExp(r'^60\d{8,11}$').hasMatch(cleaned)) return '+$cleaned';
    return null;
  }
}