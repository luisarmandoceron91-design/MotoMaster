import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controlador local de las credenciales del administrador.
///
/// Esta implementación permite que la emulación conserve las credenciales
/// después de cerrar y volver a abrir la aplicación. La contraseña no se
/// persiste en texto plano: se guarda su hash SHA-256. En una versión con
/// backend, esta capa debe ser sustituida por autenticación y recuperación
/// gestionadas por el servidor.
class AdminAuthController extends ChangeNotifier {
  static const initialUsername = 'admin';
  static const initialPassword = '123456';
  static const recoveryDemoCode = '123456';

  static const _usernameKey = 'admin_username';
  static const _passwordHashKey = 'admin_password_hash';

  // Clave heredada de la implementación incompleta de Codex. Se utiliza una
  // sola vez para migrar datos locales existentes y luego se elimina.
  static const _legacyPasswordKey = 'admin_password';

  String _username = initialUsername;
  String _passwordHash = _hashPassword(initialPassword);
  bool _hasStoredCredentials = false;

  String get username => _username;

  bool get isUsingInitialCredentials => !_hasStoredCredentials;

  bool authenticate({required String username, required String password}) {
    return username.trim().toLowerCase() == _username.toLowerCase() &&
        _hashPassword(password) == _passwordHash;
  }

  /// Código temporal para comprobar el flujo sin proveedor de SMS/correo.
  /// Debe sustituirse por un código de un solo uso emitido por el backend.
  bool verifyRecoveryCode(String code) => code.trim() == recoveryDemoCode;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    _username =
        preferences.getString(_usernameKey)?.trim() ?? initialUsername;

    final storedHash = preferences.getString(_passwordHashKey);
    if (storedHash != null && storedHash.isNotEmpty) {
      _passwordHash = storedHash;
      _hasStoredCredentials = true;
      notifyListeners();
      return;
    }

    // Migra instalaciones donde Codex ya había guardado la contraseña en
    // texto plano. Después de migrar, la clave antigua se elimina.
    final legacyPassword = preferences.getString(_legacyPasswordKey);
    if (legacyPassword != null && legacyPassword.isNotEmpty) {
      _passwordHash = _hashPassword(legacyPassword);
      _hasStoredCredentials = true;
      await preferences.setString(_passwordHashKey, _passwordHash);
      await preferences.remove(_legacyPasswordKey);
    } else {
      _username = initialUsername;
      _passwordHash = _hashPassword(initialPassword);
      _hasStoredCredentials = false;
    }

    notifyListeners();
  }

  Future<String?> changeCredentials({
    required String currentPassword,
    required String newUsername,
    required String newPassword,
  }) async {
    if (!authenticate(username: _username, password: currentPassword)) {
      return 'La contraseña actual no es correcta.';
    }
    if (newUsername.trim().length < 3) {
      return 'El usuario debe tener al menos 3 caracteres.';
    }
    if (newPassword.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    final username = newUsername.trim();
    final passwordHash = _hashPassword(newPassword);
    final preferences = await SharedPreferences.getInstance();

    // Persistimos primero. Solo actualizamos el estado en memoria cuando las
    // dos operaciones fundamentales han terminado correctamente.
    final usernameSaved = await preferences.setString(_usernameKey, username);
    final hashSaved =
        await preferences.setString(_passwordHashKey, passwordHash);
    await preferences.remove(_legacyPasswordKey);

    if (!usernameSaved || !hashSaved) {
      return 'No fue posible guardar las nuevas credenciales.';
    }

    _username = username;
    _passwordHash = passwordHash;
    _hasStoredCredentials = true;
    notifyListeners();
    return null;
  }

  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}
