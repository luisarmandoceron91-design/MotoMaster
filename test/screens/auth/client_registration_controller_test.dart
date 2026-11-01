import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/auth/auth_service.dart';
import 'package:moto_master/core/client/client_profile_repository.dart';
import 'package:moto_master/core/client/local_client_profile_store.dart';
import 'package:moto_master/screens/auth/client_registration/client_registration_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'does not create a local shadow account when Supabase is unreachable',
    () async {
      final client = SupabaseClient('http://localhost:54321', 'test-key');
      final localStore = LocalClientProfileStore();
      final controller = ClientRegistrationController(
        authService: _FailingAuthService(client),
        profileRepository: ClientProfileRepository(client: client),
        localProfileStore: localStore,
      );

      final error = await controller.registerClient(
        fullName: 'Cliente local',
        email: 'cliente@example.com',
        phone: '3000000000',
        department: 'Nariño',
        city: 'La Cruz',
        password: 'password-segura',
      );

      expect(error, contains('cuenta no fue creada'));
      expect(controller.savedLocally, isFalse);
      expect(controller.savedProfile, isNull);
      expect(await localStore.load(), isNull);
    },
  );
}

class _FailingAuthService extends AuthService {
  _FailingAuthService(SupabaseClient client) : super(client: client);

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String department,
    required String city,
    String accountType = 'client',
  }) {
    throw const AuthException('ClientException: Failed to fetch');
  }
}
