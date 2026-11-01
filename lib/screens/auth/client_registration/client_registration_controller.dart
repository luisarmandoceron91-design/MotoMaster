import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/client/client_profile.dart';
import '../../../core/client/client_profile_repository.dart';
import '../../../core/client/local_client_profile_store.dart';
import '../../../core/networking/api_client.dart';

class ClientRegistrationController extends ChangeNotifier {
  ClientRegistrationController({
    AuthService? authService,
    ClientProfileRepository? profileRepository,
    LocalClientProfileStore? localProfileStore,
  }) : _authService = authService ?? AuthService(),
       _profileRepository = profileRepository ?? ClientProfileRepository(),
       _localProfileStore = localProfileStore ?? LocalClientProfileStore();

  final AuthService _authService;
  final ClientProfileRepository _profileRepository;
  final LocalClientProfileStore _localProfileStore;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool requiresEmailConfirmation = false;
  ClientProfile? savedProfile;
  bool savedLocally = false;

  Future<String?> registerClient({
    required String fullName,
    required String email,
    required String phone,
    required String department,
    required String city,
    required String password,
    bool existingGoogleAccount = false,
    Uint8List? profilePhotoBytes,
    String? profilePhotoFileName,
  }) async {
    _setLoading(true);
    savedLocally = false;
    if (!ApiClient.cloudEnabled) {
      try {
        await _saveLocalProfile(
          fullName: fullName,
          email: email,
          phone: phone,
          department: department,
          city: city,
          password: password,
          profilePhotoBytes: profilePhotoBytes,
          profilePhotoFileName: profilePhotoFileName,
        );
        return null;
      } finally {
        _setLoading(false);
      }
    }
    try {
      if (existingGoogleAccount) {
        await _authService.updateProfileMetadata(
          accountType: 'client',
          fullName: fullName,
          phone: phone,
          department: department,
          city: city,
        );
        requiresEmailConfirmation = false;
        savedProfile = await _profileRepository.save(
          fullName: fullName,
          email: email,
          phone: phone,
          department: department,
          city: city,
          photoBytes: profilePhotoBytes,
          photoFileName: profilePhotoFileName,
        );
        await _localProfileStore.save(savedProfile!);
        return null;
      }
      final response = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        department: department,
        city: city,
      );
      requiresEmailConfirmation = response.session == null;
      if (requiresEmailConfirmation) {
        savedProfile = ClientProfile(
          userId: response.user?.id,
          fullName: fullName.trim(),
          email: email.trim().toLowerCase(),
          phone: phone.trim(),
          department: department.trim(),
          city: city.trim(),
          profilePhotoBytes: profilePhotoBytes,
          profilePhotoFileName: profilePhotoFileName,
        );
        unawaited(_localProfileStore.save(savedProfile!));
        return null;
      }
      savedProfile = await _profileRepository.save(
        fullName: fullName,
        email: email,
        phone: phone,
        department: department,
        city: city,
        photoBytes: profilePhotoBytes,
        photoFileName: profilePhotoFileName,
      );
      await _localProfileStore.save(savedProfile!);
      return null;
    } on AuthException catch (error) {
      if (_isConnectionFailure(error)) {
        return 'No hay conexión con el servidor. Revisa Internet e inténtalo de nuevo; la cuenta no fue creada.';
      }
      return _authMessage(error.message);
    } catch (error) {
      if (_isConnectionFailure(error)) {
        return 'No hay conexión con el servidor. Revisa Internet e inténtalo de nuevo; la cuenta no fue creada.';
      }
      return 'No fue posible crear la cuenta: $error';
    } finally {
      _setLoading(false);
    }
  }

  bool _isConnectionFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed to fetch') ||
        message.contains('socketexception') ||
        message.contains('host desconocido') ||
        message.contains('network');
  }

  Future<void> _saveLocalProfile({
    required String fullName,
    required String email,
    required String phone,
    required String department,
    required String city,
    String? password,
    Uint8List? profilePhotoBytes,
    String? profilePhotoFileName,
  }) async {
    savedLocally = true;
    requiresEmailConfirmation = false;
    savedProfile = ClientProfile(
      userId: 'local:${email.trim().toLowerCase()}',
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      department: department.trim(),
      city: city.trim(),
      profilePhotoBytes: profilePhotoBytes,
      profilePhotoFileName: profilePhotoFileName,
    );
    await _localProfileStore.save(savedProfile!);
    if (password != null && password.isNotEmpty) {
      await _localProfileStore.saveCredentials(
        email: email,
        password: password,
      );
    }
  }

  Future<String?> updateClient({
    required String fullName,
    required String email,
    required String phone,
    required String department,
    required String city,
    Uint8List? profilePhotoBytes,
    String? profilePhotoFileName,
  }) async {
    _setLoading(true);
    savedLocally = false;
    try {
      savedProfile = await _profileRepository.save(
        fullName: fullName,
        email: email,
        phone: phone,
        department: department,
        city: city,
        photoBytes: profilePhotoBytes,
        photoFileName: profilePhotoFileName,
      );
      await _localProfileStore.save(savedProfile!);
      return null;
    } on AuthException catch (error) {
      if (_isConnectionFailure(error)) {
        await _saveLocalProfile(
          fullName: fullName,
          email: email,
          phone: phone,
          department: department,
          city: city,
          profilePhotoBytes: profilePhotoBytes,
          profilePhotoFileName: profilePhotoFileName,
        );
        return null;
      }
      return _authMessage(error.message);
    } catch (error) {
      if (_isConnectionFailure(error)) {
        await _saveLocalProfile(
          fullName: fullName,
          email: email,
          phone: phone,
          department: department,
          city: city,
          profilePhotoBytes: profilePhotoBytes,
          profilePhotoFileName: profilePhotoFileName,
        );
        return null;
      }
      return 'No fue posible actualizar tus datos: $error';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _authMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('already registered')) {
      return 'Este correo ya está registrado. Inicia sesión.';
    }
    if (normalized.contains('password')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return message;
  }
}
