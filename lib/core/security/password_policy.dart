String? validateStrongPassword(String? value) {
  final password = value ?? '';
  // La regla mínima de Supabase es seis caracteres. No imponemos requisitos
  // extra de mayúsculas, números o símbolos en el formulario: el servicio
  // conserva sus propias protecciones contra claves filtradas.
  if (password.length < 6) {
    return 'Usa al menos 6 caracteres.';
  }
  return null;
}
