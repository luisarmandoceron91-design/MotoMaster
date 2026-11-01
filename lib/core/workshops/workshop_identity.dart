import 'workshop.dart';

String normalizeWorkshopIdentity(String value) {
  const source = 'áéíóúüñ';
  const target = 'aeiouun';
  var normalized = value.trim().toLowerCase();
  for (var index = 0; index < source.length; index++) {
    normalized = normalized.replaceAll(source[index], target[index]);
  }
  return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String workshopIdentityKey(Workshop workshop) =>
    normalizeWorkshopIdentity(workshop.name);

int workshopIdentityPriority(Workshop workshop) {
  var score = 0;
  if (workshop.hasPlatformAccess) score += 1000;
  if (workshop.permanentAccess) score += 300;
  if (workshop.accessStatus == 'active') score += 200;
  if (workshop.accessStatus == 'trial') score += 100;
  if (workshop.department.trim().isNotEmpty) score += 10;
  if (workshop.municipality.trim().isNotEmpty) score += 10;
  if (workshop.address.trim().isNotEmpty) score += 5;
  if (workshop.phone.trim().isNotEmpty) score += 3;
  if (workshop.logoBytes != null ||
      (workshop.logoUrl?.trim().isNotEmpty ?? false) ||
      (workshop.logoPath?.trim().isNotEmpty ?? false)) {
    score += 2;
  }
  return score;
}

List<Workshop> canonicalWorkshops(
  Iterable<Workshop> workshops, {
  Set<String> preferredIds = const {},
}) {
  final byIdentity = <String, Workshop>{};
  for (final workshop in workshops) {
    final key = workshopIdentityKey(workshop);
    if (key.isEmpty) continue;
    final current = byIdentity[key];
    if (current == null) {
      byIdentity[key] = workshop;
      continue;
    }
    final currentPreferred = preferredIds.contains(current.id);
    final candidatePreferred = preferredIds.contains(workshop.id);
    if (candidatePreferred != currentPreferred) {
      if (candidatePreferred) byIdentity[key] = workshop;
      continue;
    }
    if (workshopIdentityPriority(workshop) >
        workshopIdentityPriority(current)) {
      byIdentity[key] = workshop;
    }
  }
  return byIdentity.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
