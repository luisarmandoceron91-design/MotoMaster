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
    // Match each municipality word from its beginning. Results can appear as
    // the client types "La C...", while "La Cruz" still cannot match a
    // different municipality such as San Bernardo.
    if (city.isNotEmpty && !_matchesMunicipality(workshop.municipality, city)) {
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

bool _matchesMunicipality(String municipality, String requested) {
  final municipalityWords = _normalize(
    municipality,
  ).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  final requestedWords = requested
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return requestedWords.every(
    (requestedWord) => municipalityWords.any(
      (municipalityWord) => municipalityWord.startsWith(requestedWord),
    ),
  );
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
