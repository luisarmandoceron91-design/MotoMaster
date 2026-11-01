import 'package:flutter_test/flutter_test.dart';

import 'package:moto_master/core/workshops/client_workshop_search.dart';
import 'package:moto_master/core/workshops/workshop.dart';

void main() {
  final workshops = [
    const Workshop(
      id: 'jose',
      name: 'Motos Jose',
      slug: 'motos-jose',
      tagline: '',
      accentColorValue: 0xFFFF6500,
      department: 'Cauca',
      municipality: 'Popayán',
      neighborhood: 'La Esmeralda',
    ),
    const Workshop(
      id: 'elite',
      name: 'Moto Elite',
      slug: 'moto-elite',
      tagline: '',
      accentColorValue: 0xFFFF6500,
      department: 'Nariño',
      municipality: 'La Cruz',
    ),
  ];

  test('no publica todos los talleres antes de elegir ubicación', () {
    expect(
      filterWorkshopsForClientSearch(
        workshops: workshops,
        department: null,
        municipality: '',
      ),
      isEmpty,
    );
    expect(
      filterWorkshopsForClientSearch(
        workshops: workshops,
        department: 'Cauca',
        municipality: '',
      ),
      isEmpty,
    );
  });

  test('muestra únicamente talleres del departamento y municipio buscados', () {
    final result = filterWorkshopsForClientSearch(
      workshops: workshops,
      department: 'Cauca',
      municipality: 'Popayan',
    );
    expect(result.map((workshop) => workshop.id), ['jose']);
  });

  test('acepta el municipio escrito manualmente sin distinguir tildes', () {
    final result = filterWorkshopsForClientSearch(
      workshops: workshops,
      department: 'Cauca',
      municipality: 'popa',
    );
    expect(result.map((workshop) => workshop.id), ['jose']);
  });

  test('encuentra un taller al buscar por nombre sin filtros de ubicación', () {
    final result = filterWorkshopsForClientSearch(
      workshops: workshops,
      department: null,
      municipality: '',
      query: 'elite',
    );
    expect(result.map((workshop) => workshop.id), ['elite']);
  });

  test('combina nombre y ubicación escrita en una sola búsqueda', () {
    final result = filterWorkshopsForClientSearch(
      workshops: workshops,
      department: null,
      municipality: '',
      query: 'motos jose popayan cauca',
    );
    expect(result.map((workshop) => workshop.id), ['jose']);
  });
}
