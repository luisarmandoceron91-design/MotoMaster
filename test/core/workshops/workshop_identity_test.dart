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

  test('conserva talleres diferentes aunque compartan el mismo nombre', () {
    final result = canonicalWorkshops([
      workshop(id: 'old', name: 'Motos Ordóñez'),
      workshop(id: 'new', name: 'MOTOS ORDOÑEZ', municipality: 'La Cruz'),
    ]);

    expect(result.map((item) => item.id), unorderedEquals(['new', 'old']));
  });

  test('combina copias del mismo taller y prefiere el registro visible', () {
    final result = canonicalWorkshops([
      workshop(
        id: 'same',
        name: 'Tu Taller',
        accessStatus: 'expired',
        permanentAccess: false,
      ),
      workshop(id: 'same', name: 'TU TALLER'),
    ]);

    expect(result, hasLength(1));
    expect(result.single.accessStatus, 'active');
  });

  test('mantiene cada registro elegido aunque coincida su nombre', () {
    final result = canonicalWorkshops(
      [
        workshop(id: 'first', name: 'Moto SolarTe', municipality: 'Pasto'),
        workshop(id: 'chosen', name: 'MOTO SOLARTE'),
      ],
      preferredIds: {'chosen'},
    );

    expect(result.map((item) => item.id), unorderedEquals(['first', 'chosen']));
  });
}
