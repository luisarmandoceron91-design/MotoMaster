import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/workshops/workshop.dart';
import 'package:moto_master/core/workshops/workshop_identity.dart';

void main() {
  Workshop workshop({
    required String id,
    required String name,
    String accessStatus = 'active',
    bool permanentAccess = true,
    String municipality = '',
  }) => Workshop(
    id: id,
    name: name,
    slug: id,
    tagline: '',
    accentColorValue: 0xFFFF6500,
    accessStatus: accessStatus,
    permanentAccess: permanentAccess,
    trialEndsAt: accessStatus == 'trial'
        ? DateTime.now().add(const Duration(days: 2))
        : null,
    municipality: municipality,
  );

  test('combina el mismo taller aunque cambien mayusculas y tildes', () {
    final result = canonicalWorkshops([
      workshop(id: 'old', name: 'Motos Ordóñez'),
      workshop(id: 'new', name: 'MOTOS ORDOÑEZ', municipality: 'La Cruz'),
    ]);

    expect(result, hasLength(1));
    expect(result.single.id, 'new');
  });

  test('prefiere el registro con acceso visible para el cliente', () {
    final result = canonicalWorkshops([
      workshop(
        id: 'expired',
        name: 'Tu Taller',
        accessStatus: 'expired',
        permanentAccess: false,
      ),
      workshop(id: 'active', name: 'TU TALLER'),
    ]);

    expect(result, hasLength(1));
    expect(result.single.id, 'active');
  });

  test('respeta el taller previamente elegido si ambos estan activos', () {
    final result = canonicalWorkshops(
      [
        workshop(id: 'first', name: 'Moto SolarTe', municipality: 'Pasto'),
        workshop(id: 'chosen', name: 'MOTO SOLARTE'),
      ],
      preferredIds: {'chosen'},
    );

    expect(result.single.id, 'chosen');
  });
}
