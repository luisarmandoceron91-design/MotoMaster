import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/password_kdf.dart';

class AdminAuthController extends ChangeNotifier {
  static const initialUsername = 'luisarmandoceron1322';
  static const _initialPasswordHash =
      'e79b1a517ab04cf8305cd47a9e11668b0720eb1b94fd9e9d2993f9231938446b';
  static const recoveryDemoCode = '123456';

  static const _usernameKey = 'platform_owner_username';
  static const _passwordHashKey = 'platform_owner_password_hash';
  static const _fullNameKey = 'platform_owner_full_name';
  static const _documentKey = 'platform_owner_document';
  static const _emailKey = 'platform_owner_email';
  static const _phoneKey = 'platform_owner_phone';
  static const _avatarBase64Key = 'platform_owner_avatar_base64';
  static const _professionalTitleKey = 'platform_owner_professional_title';
  static const _publicContactKey = 'platform_owner_public_contact';
  static const _documentCreditEnabledKey =
      'platform_owner_document_credit_enabled';
  static const _ownerTwoFactorEnabledKey = 'platform_owner_two_factor_enabled';
  static const _ownerDocumentFormatsKey = 'platform_owner_document_formats';
  static const _ownerAccentColorKey = 'platform_owner_accent_color';
  static const _ownerTextScaleKey = 'platform_owner_text_scale';
  static const _ownerBackgroundEnabledKey = 'platform_owner_background_enabled';
  static const _ownerBackgroundOpacityKey = 'platform_owner_background_opacity';
  static const _ownerCompactModeKey = 'platform_owner_compact_mode';

  String _username = initialUsername;
  String _passwordHash = _initialPasswordHash;
  bool _hasStoredCredentials = false;
  String _fullName = '';
  String _document = '';
  String _email = '';
  String _phone = '';
  String _avatarBase64 = '';
  String _professionalTitle = 'Arquitecto y desarrollador de la aplicación';
  String _publicContact = '';
  bool _documentCreditEnabled = true;
  bool _ownerTwoFactorEnabled = true;
  List<String> _ownerDocumentFormats = [
    'PDF',
    'Word (.docx)',
    'Correo',
    'WhatsApp',
    'Facturas',
    'Recibos',
  ];
  int _ownerAccentColorValue = 0xFFFF6500;
  double _ownerTextScale = 1;
  bool _ownerBackgroundEnabled = true;
  double _ownerBackgroundOpacity = .65;
  bool _ownerCompactMode = false;

  String get username => _username;
  bool get isUsingInitialCredentials => !_hasStoredCredentials;
  String get fullName => _fullName;
  String get document => _document;
  String get email => _email;
  String get phone => _phone;
  String get avatarBase64 => _avatarBase64;
  String get professionalTitle => _professionalTitle;
  String get publicContact => _publicContact;
  bool get documentCreditEnabled => _documentCreditEnabled;
  bool get ownerTwoFactorEnabled => _ownerTwoFactorEnabled;
  List<String> get ownerDocumentFormats =>
      List.unmodifiable(_ownerDocumentFormats);
  int get ownerAccentColorValue => _ownerAccentColorValue;
  double get ownerTextScale => _ownerTextScale;
  bool get ownerBackgroundEnabled => _ownerBackgroundEnabled;
  double get ownerBackgroundOpacity => _ownerBackgroundOpacity;
  bool get ownerCompactMode => _ownerCompactMode;
  bool get hasOwnerProfile =>
      _fullName.isNotEmpty && _email.isNotEmpty && _phone.isNotEmpty;

  bool authenticate({required String username, required String password}) {
    return username.trim().toLowerCase() == _username.toLowerCase() &&
        PasswordKdf.verify(password, _passwordHash);
  }

  bool verifyRecoveryCode(String code) => code.trim() == recoveryDemoCode;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    _username = preferences.getString(_usernameKey)?.trim() ?? initialUsername;
    _fullName = preferences.getString(_fullNameKey)?.trim() ?? '';
    _document = preferences.getString(_documentKey)?.trim() ?? '';
    _email = preferences.getString(_emailKey)?.trim() ?? '';
    _phone = preferences.getString(_phoneKey)?.trim() ?? '';
    _avatarBase64 = preferences.getString(_avatarBase64Key) ?? '';
    _professionalTitle =
        preferences.getString(_professionalTitleKey)?.trim() ??
        'Arquitecto y desarrollador de la aplicación';
    _publicContact = preferences.getString(_publicContactKey)?.trim() ?? '';
    _documentCreditEnabled =
        preferences.getBool(_documentCreditEnabledKey) ?? true;
    _ownerTwoFactorEnabled =
        preferences.getBool(_ownerTwoFactorEnabledKey) ?? true;
    _ownerDocumentFormats =
        preferences.getStringList(_ownerDocumentFormatsKey) ??
        _ownerDocumentFormats;
    _ownerAccentColorValue =
        preferences.getInt(_ownerAccentColorKey) ?? 0xFFFF6500;
    _ownerTextScale = preferences.getDouble(_ownerTextScaleKey) ?? 1;
    _ownerBackgroundEnabled =
        preferences.getBool(_ownerBackgroundEnabledKey) ?? true;
    _ownerBackgroundOpacity =
        (preferences.getDouble(_ownerBackgroundOpacityKey) ?? .65).clamp(
          .2,
          1.0,
        );
    _ownerCompactMode = preferences.getBool(_ownerCompactModeKey) ?? false;

    final storedHash = preferences.getString(_passwordHashKey);
    if (storedHash != null && storedHash.isNotEmpty) {
      _passwordHash = storedHash;
      _hasStoredCredentials = true;
      notifyListeners();
      return;
    }

    _username = initialUsername;
    _passwordHash = _initialPasswordHash;
    _hasStoredCredentials = false;

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
    if (newPassword.isNotEmpty && newPassword.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    final username = newUsername.trim();
    final passwordHash = newPassword.isEmpty
        ? _passwordHash
        : _hashPassword(newPassword);
    final preferences = await SharedPreferences.getInstance();

    final usernameSaved = await preferences.setString(_usernameKey, username);
    final hashSaved = await preferences.setString(
      _passwordHashKey,
      passwordHash,
    );
    if (!usernameSaved || !hashSaved) {
      return 'No fue posible guardar las nuevas credenciales.';
    }

    _username = username;
    _passwordHash = passwordHash;
    _hasStoredCredentials = true;
    notifyListeners();
    return null;
  }

  Future<String?> saveOwnerProfile({
    required String fullName,
    required String document,
    required String email,
    required String phone,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.trim();
    if (normalizedName.length < 3) return 'Ingresa tu nombre completo.';
    if (!normalizedEmail.contains('@')) return 'Ingresa un correo válido.';
    if (normalizedPhone.replaceAll(RegExp(r'\D'), '').length < 7) {
      return 'Ingresa un número de celular válido.';
    }

    final preferences = await SharedPreferences.getInstance();
    final results = await Future.wait([
      preferences.setString(_fullNameKey, normalizedName),
      preferences.setString(_documentKey, document.trim()),
      preferences.setString(_emailKey, normalizedEmail),
      preferences.setString(_phoneKey, normalizedPhone),
    ]);
    if (results.any((saved) => !saved)) {
      return 'No fue posible guardar el perfil del propietario.';
    }
    _fullName = normalizedName;
    _document = document.trim();
    _email = normalizedEmail;
    _phone = normalizedPhone;
    notifyListeners();
    return null;
  }

  Future<String?> saveOwnerPresentation({
    required String fullName,
    required String document,
    required String email,
    required String phone,
    required String professionalTitle,
    required String publicContact,
    required bool documentCreditEnabled,
    required bool twoFactorEnabled,
    required List<String> documentFormats,
    String? avatarBase64,
  }) async {
    final profileError = await saveOwnerProfile(
      fullName: fullName,
      document: document,
      email: email,
      phone: phone,
    );
    if (profileError != null) return profileError;
    if (professionalTitle.trim().length < 3) {
      return 'Ingresa un título profesional válido.';
    }
    if (publicContact.trim().isEmpty) {
      return 'Ingresa el correo o teléfono que aparecerá en los documentos.';
    }
    if (documentFormats.isEmpty) {
      return 'Selecciona al menos un formato de documento.';
    }

    final preferences = await SharedPreferences.getInstance();
    final results = await Future.wait([
      preferences.setString(_professionalTitleKey, professionalTitle.trim()),
      preferences.setString(_publicContactKey, publicContact.trim()),
      preferences.setBool(_documentCreditEnabledKey, documentCreditEnabled),
      preferences.setBool(_ownerTwoFactorEnabledKey, twoFactorEnabled),
      preferences.setStringList(_ownerDocumentFormatsKey, documentFormats),
      if (avatarBase64 != null)
        preferences.setString(_avatarBase64Key, avatarBase64),
    ]);
    if (results.any((saved) => !saved)) {
      return 'No fue posible guardar la configuración del propietario.';
    }
    _professionalTitle = professionalTitle.trim();
    _publicContact = publicContact.trim();
    _documentCreditEnabled = documentCreditEnabled;
    _ownerTwoFactorEnabled = twoFactorEnabled;
    _ownerDocumentFormats = List.of(documentFormats);
    if (avatarBase64 != null) _avatarBase64 = avatarBase64;
    notifyListeners();
    return null;
  }

  Future<String?> saveOwnerAppearance({
    required int accentColorValue,
    required double textScale,
    required bool backgroundEnabled,
    required double backgroundOpacity,
    required bool compactMode,
  }) async {
    if (textScale < .8 || textScale > 1.4) {
      return 'El tamaño del texto no es válido.';
    }
    if (backgroundOpacity < .2 || backgroundOpacity > 1) {
      return 'La intensidad del fondo no es válida.';
    }
    final preferences = await SharedPreferences.getInstance();
    final results = await Future.wait([
      preferences.setInt(_ownerAccentColorKey, accentColorValue),
      preferences.setDouble(_ownerTextScaleKey, textScale),
      preferences.setBool(_ownerBackgroundEnabledKey, backgroundEnabled),
      preferences.setDouble(_ownerBackgroundOpacityKey, backgroundOpacity),
      preferences.setBool(_ownerCompactModeKey, compactMode),
    ]);
    if (results.any((saved) => !saved)) {
      return 'No fue posible guardar la personalización.';
    }
    _ownerAccentColorValue = accentColorValue;
    _ownerTextScale = textScale;
    _ownerBackgroundEnabled = backgroundEnabled;
    _ownerBackgroundOpacity = backgroundOpacity;
    _ownerCompactMode = compactMode;
    notifyListeners();
    return null;
  }

  void previewOwnerAppearance({
    required int accentColorValue,
    required double textScale,
    required bool backgroundEnabled,
    required double backgroundOpacity,
    required bool compactMode,
  }) {
    _ownerAccentColorValue = accentColorValue;
    _ownerTextScale = textScale.clamp(.8, 1.4);
    _ownerBackgroundEnabled = backgroundEnabled;
    _ownerBackgroundOpacity = backgroundOpacity.clamp(.2, 1.0);
    _ownerCompactMode = compactMode;
    notifyListeners();
  }

  bool matchesRecoveryDestination(String destination) {
    final normalized = destination.trim().toLowerCase();
    if (normalized.contains('@')) return normalized == _email.toLowerCase();
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    return digits.isNotEmpty && digits == _phone.replaceAll(RegExp(r'\D'), '');
  }

  Future<String?> resetPasswordWithRecovery({
    required String code,
    required String newPassword,
  }) async {
    if (!verifyRecoveryCode(code)) return 'El código no es válido.';
    if (newPassword.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    final passwordHash = _hashPassword(newPassword);
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_passwordHashKey, passwordHash)) {
      return 'No fue posible guardar la nueva contraseña.';
    }
    _passwordHash = passwordHash;
    _hasStoredCredentials = true;
    notifyListeners();
    return null;
  }

  static String _hashPassword(String password) {
    return PasswordKdf.hash(password);
  }
}
