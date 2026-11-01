import 'workshop.dart';

List<Workshop> filterWorkshopsForClientSearch({
  required List<Workshop> workshops,
  required String? department,
  required String municipality,
  String query = '',
  Iterable<String> hiddenIds = const [],
}) {
  final city = _normalize(municipality);
  final selectedDepartment = _normalize(department ?? '');
  final normalizedQuery = _normalize(query);
  final hasLocationSearch = selectedDepartment.isNotEmpty && city.isNotEmpty;
  if (!hasLocationSearch && normalizedQuery.isEmpty) {
    return const [];
  }
  final hidden = hiddenIds.toSet();
  final searchTerms = normalizedQuery
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty);
  return workshops.where((workshop) {
    if (hidden.contains(workshop.id)) return false;
    if (selectedDepartment.isNotEmpty &&
        _normalize(workshop.department) != selectedDepartment) {
      return false;
    }
    // A location filter is an exact municipality search. This prevents a
    // client who chose La Cruz, Nariño from seeing a workshop registered in
    // another municipality just because both names contain a similar word.
    if (city.isNotEmpty && _normalize(workshop.municipality) != city) {
      return false;
    }
    if (normalizedQuery.isEmpty) return true;
    final searchableText = _normalize(
      [
        workshop.name,
        workshop.department,
        workshop.municipality,
        workshop.neighborhood,
        workshop.address,
      ].join(' '),
    );
    return searchTerms.every(searchableText.contains);
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
