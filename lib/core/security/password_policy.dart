String? validateStrongPassword(String? value) {
  final password = value ?? '';
  if (password.length < 8) {
    return 'Usa al menos 8 caracteres.';
  }
  if (!RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(password) ||
      !RegExp(r'\d').hasMatch(password)) {
    return 'Combina al menos una letra y un número.';
  }
  const commonPasswords = {
    '123456',
    '12345678',
    'password',
    'contraseña',
    'qwerty',
    'abcdef',
  };
  if (commonPasswords.contains(password.toLowerCase())) {
    return 'Esta contraseña es muy fácil de adivinar. Elige otra.';
  }
  return null;
}
