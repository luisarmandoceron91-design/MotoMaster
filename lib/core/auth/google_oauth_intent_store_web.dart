import 'dart:html' as html;

const _intentKey = 'motomaster_google_login_intent';

/// Permanece en el mismo navegador mientras Google redirige a la aplicación.
Future<void> persistGoogleIntent(String intent) async {
  html.window.localStorage[_intentKey] = intent;
}

Future<String?> readGoogleIntent() async =>
    html.window.localStorage[_intentKey];

Future<void> clearGoogleIntent() async {
  html.window.localStorage.remove(_intentKey);
}
