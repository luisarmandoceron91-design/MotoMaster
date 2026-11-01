import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/client/client_profile.dart';
import 'package:moto_master/core/client/local_client_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stores and restores a local client profile', () async {
    final store = LocalClientProfileStore();
    final profile = ClientProfile(
      userId: 'local:cliente@example.com',
      fullName: 'Cliente de prueba',
      email: 'cliente@example.com',
      phone: '3000000000',
      department: 'Nariño',
      city: 'La Cruz',
      profilePhotoBytes: Uint8List.fromList([1, 2, 3]),
      profilePhotoFileName: 'perfil.jpg',
    );

    await store.save(profile);
    await store.saveCredentials(
      email: profile.email,
      password: 'ClaveSegura123',
    );
    final restored = await store.load();
    final authenticated = await LocalClientProfileStore().authenticate(
      email: 'CLIENTE@example.com',
      password: 'ClaveSegura123',
    );

    expect(restored?.fullName, profile.fullName);
    expect(restored?.department, 'Nariño');
    expect(restored?.city, 'La Cruz');
    expect(restored?.profilePhotoBytes, profile.profilePhotoBytes);
    expect(authenticated?.email, profile.email);
  });

  test('separa perfiles y sesiones de clientes por correo', () async {
    final store = LocalClientProfileStore();
    const first = ClientProfile(
      userId: 'local:uno@example.com',
      fullName: 'Cliente Uno',
      email: 'uno@example.com',
      phone: '3000000001',
      department: 'Nariño',
      city: 'Pasto',
    );
    const second = ClientProfile(
      userId: 'local:dos@example.com',
      fullName: 'Cliente Dos',
      email: 'dos@example.com',
      phone: '3000000002',
      department: 'Antioquia',
      city: 'Medellín',
    );
    await store.save(first);
    await store.saveCredentials(
      email: first.email,
      password: 'ClaveClienteUno',
    );
    await store.save(second);
    await store.saveCredentials(
      email: second.email,
      password: 'ClaveClienteDos',
    );

    final restoredFirst = await store.authenticate(
      email: first.email,
      password: 'ClaveClienteUno',
    );
    final restoredSecond = await store.authenticate(
      email: second.email,
      password: 'ClaveClienteDos',
    );
    expect(restoredFirst?.fullName, 'Cliente Uno');
    expect(restoredSecond?.fullName, 'Cliente Dos');

    await store.signOut();
    expect(await store.loadActive(), isNull);
  });
}
