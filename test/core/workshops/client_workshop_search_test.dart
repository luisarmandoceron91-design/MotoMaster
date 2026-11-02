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
    const Workshop(
      id: 'cruz-2',
      name: 'Repuestos La Cruz',
      slug: 'repuestos-la-cruz',
      tagline: '',
      accentColorValue: 0xFFFF6500,
      department: 'Nariño',
      municipality: 'La Cruz',
    ),
    const Workshop(
      id: 'bernardo',
      name: 'Motos San Bernardo',
      slug: 'motos-san-bernardo',
      tagline: '',
      accentColorValue: 0xFFFF6500,
      department: 'Nariño',
      municipality: 'San Bernardo',
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

  test('encuentra todos los talleres del municipio escrito manualmente', () {
    final result = filterWorkshopsForClientSearch(
      workshops: workshops,
      department: 'Nariño',
      municipality: 'la cruz',
    );
    expect(result.map((workshop) => workshop.id), ['elite', 'cruz-2']);
  });

  test('no mezcla talleres de otro municipio del mismo departamento', () {
    final result = filterWorkshopsForClientSearch(
      workshops: workshops,
      department: 'Nariño',
      municipality: 'La Cruz',
    );
    expect(result.map((workshop) => workshop.id), isNot(contains('bernardo')));
  });

  test('va mostrando los talleres mientras se escribe el municipio', () {
    final result = filterWorkshopsForClientSearch(
      workshops: workshops,
      department: 'Nariño',
      municipality: 'La C',
    );
    expect(result.map((workshop) => workshop.id), ['elite', 'cruz-2']);
  });

  test('no devuelve resultados cuando no hay talleres en la ubicación', () {
    final result = filterWorkshopsForClientSearch(
      workshops: workshops,
      department: 'Caquetá',
      municipality: 'El Doncello',
    );
    expect(result, isEmpty);
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
