import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/location/colombia_locations.dart';
import 'package:moto_master/core/workshops/workshop.dart';

void main() {
  const workshop = Workshop(
    id: 'workshop-1',
    name: 'Taller central',
    slug: 'taller-central',
    tagline: '',
    accentColorValue: 0xFFFF6500,
    department: 'Antioquia',
    municipality: 'Medellín',
    neighborhood: 'Laureles',
    openingHours: {
      'monday': {'open': '08:00', 'close': '18:00'},
      'tuesday': {'closed': true},
    },
  );

  test('builds the complete directory location', () {
    expect(workshop.locationLine, 'Antioquia · Medellín · Laureles');
  });

  test('reports open only inside the configured schedule', () {
    expect(workshop.isOpenAt(DateTime(2026, 10, 5, 9)), isTrue);
    expect(workshop.isOpenAt(DateTime(2026, 10, 5, 18)), isFalse);
    expect(workshop.isOpenAt(DateTime(2026, 10, 6, 9)), isFalse);
  });

  test('department selection provides its municipalities', () {
    expect(colombiaLocations, contains('Antioquia'));
    expect(colombiaLocations['Antioquia'], contains('Medellín'));
    expect(colombiaLocations['Cundinamarca'], contains('Bogotá D.C.'));
  });
}
