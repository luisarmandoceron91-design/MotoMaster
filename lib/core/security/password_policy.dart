String? validateStrongPassword(String? value) {
  final password = value ?? '';
  if (password.length < 6) {
    return 'Usa al menos 6 caracteres.';
  }
  return null;
}
