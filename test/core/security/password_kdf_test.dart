import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/security/password_kdf.dart';

void main() {
  test('uses a random salt and verifies without exposing the password', () {
    const password = 'Una-frase-segura-2026';
    final first = PasswordKdf.hash(password);
    final second = PasswordKdf.hash(password);

    expect(first, isNot(second));
    expect(first, isNot(contains(password)));
    expect(PasswordKdf.verify(password, first), isTrue);
    expect(PasswordKdf.verify('incorrecta', first), isFalse);
    expect(PasswordKdf.needsUpgrade(first), isFalse);
  });

  test('accepts a legacy SHA-256 hash only for automatic migration', () {
    const legacy =
        'e79b1a517ab04cf8305cd47a9e11668b0720eb1b94fd9e9d2993f9231938446b';

    expect(PasswordKdf.verify('luisceron2912', legacy), isTrue);
    expect(PasswordKdf.needsUpgrade(legacy), isTrue);
  });
}
