import 'package:flutter_test/flutter_test.dart';
import 'package:hearable/core/utils/validators.dart';

void main() {
  group('Email validation', () {
    test('accepts a valid email', () {
      expect(Validators.email('aina@example.com'), isNull);
    });
    test('rejects empty and badly formatted emails', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('aina@'), isNotNull);
      expect(Validators.email('aina.example.com'), isNotNull);
    });
  });

  group('Password validation', () {
    test('accepts 8+ characters with letters and numbers', () {
      expect(Validators.password('hearable123'), isNull);
    });
    test('rejects short or weak passwords', () {
      expect(Validators.password('abc1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
    });
    test('confirm password must match', () {
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
      expect(Validators.confirmPassword('abc12345', 'xyz12345'), isNotNull);
    });
  });

  group('Phone numbers', () {
    test('converts Malaysian numbers to international format', () {
      expect(Validators.normalizePhone('012-345 6789'), '+60123456789');
      expect(Validators.normalizePhone('04-123 4567'), '+6041234567');
      expect(Validators.normalizePhone('60123456789'), '+60123456789');
      expect(Validators.normalizePhone('+60123456789'), '+60123456789');
    });
    test('rejects invalid numbers', () {
      expect(Validators.normalizePhone('12345'), isNull);
      expect(Validators.normalizePhone('abcdefghij'), isNull);
    });
    test('optional phone can be empty, required cannot', () {
      expect(Validators.phone('', isRequired: false), isNull);
      expect(Validators.phone(''), isNotNull);
    });
  });
}