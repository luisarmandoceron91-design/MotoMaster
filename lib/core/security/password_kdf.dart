import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Derivacion para el modo local de demostracion.
///
/// En produccion las contrasenas pertenecen exclusivamente a Supabase Auth y
/// nunca deben almacenarse en SharedPreferences.
class PasswordKdf {
  static const _algorithm = 'pbkdf2_sha256';
  static const _iterations = 60000;
  static const _saltLength = 16;
  static const _derivedLength = 32;

  static String hash(String password) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final derived = _derive(utf8.encode(password), salt, _iterations);
    return [
      _algorithm,
      _iterations,
      base64UrlEncode(salt),
      base64UrlEncode(derived),
    ].join(r'$');
  }

  static bool verify(String password, String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length == 4 && parts.first == _algorithm) {
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 10000 || iterations > 1000000) {
        return false;
      }
      try {
        final salt = base64Url.decode(parts[2]);
        final expected = base64Url.decode(parts[3]);
        final actual = _derive(utf8.encode(password), salt, iterations);
        return _constantTimeEquals(actual, expected);
      } catch (_) {
        return false;
      }
    }

    // Compatibilidad de una sola vez con el SHA-256 usado por prototipos.
    final legacy = sha256.convert(utf8.encode(password)).bytes;
    try {
      return _constantTimeEquals(legacy, _decodeHex(encoded));
    } catch (_) {
      return false;
    }
  }

  static bool needsUpgrade(String encoded) =>
      !encoded.startsWith('$_algorithm\$');

  static Uint8List _derive(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    final firstInput = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..setRange(salt.length, salt.length + 4, const [0, 0, 0, 1]);
    var block = Uint8List.fromList(hmac.convert(firstInput).bytes);
    final output = Uint8List.fromList(block);
    for (var round = 1; round < iterations; round++) {
      block = Uint8List.fromList(hmac.convert(block).bytes);
      for (var index = 0; index < output.length; index++) {
        output[index] ^= block[index];
      }
    }
    return Uint8List.sublistView(output, 0, _derivedLength);
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  static Uint8List _decodeHex(String value) {
    if (value.length.isOdd) throw const FormatException();
    return Uint8List.fromList([
      for (var index = 0; index < value.length; index += 2)
        int.parse(value.substring(index, index + 2), radix: 16),
    ]);
  }
}
