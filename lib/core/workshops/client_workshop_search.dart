import 'workshop.dart';

List<Workshop> filterWorkshopsForClientSearch({
  required List<Workshop> workshops,
  required String? department,
  required String municipality,
  String query = '',
  Iterable<String> hiddenIds = const [],
}) {
  final city = _normalize(municipality);
  if (department == null || department.trim().isEmpty || city.isEmpty) {
    return const [];
  }
  final hidden = hiddenIds.toSet();
  final normalizedQuery = _normalize(query);
  return workshops.where((workshop) {
    if (hidden.contains(workshop.id)) return false;
    if (_normalize(workshop.department) != _normalize(department)) return false;
    if (!_normalize(workshop.municipality).contains(city)) return false;
    if (normalizedQuery.isEmpty) return true;
    return [
      workshop.name,
      workshop.department,
      workshop.municipality,
      workshop.neighborhood,
      workshop.address,
    ].any((value) => _normalize(value).contains(normalizedQuery));
  }).toList();
}

String _normalize(String value) {
  const source = 'áéíóúüñ';
  const target = 'aeiouun';
  var normalized = value.trim().toLowerCase();
  for (var index = 0; index < source.length; index++) {
    normalized = normalized.replaceAll(source[index], target[index]);
  }
  return normalized;
}
