# Moto Master

Aplicación Flutter multi-taller con autenticación y datos en Supabase.

## Acceso de administradores de talleres

El flujo distingue dos momentos:

1. El primer acceso usa `admin` y `123456` y abre obligatoriamente el registro.
2. El administrador crea sus credenciales personales e inicia una prueba de
   tres días. Al vencer, los datos se conservan y se solicita el pago único.

El propietario puede activar definitivamente, suspender o reactivar cada taller
desde su centro de control. Las credenciales iniciales nunca abren información
de un taller existente.

### Configuración requerida

1. En Google Cloud crea un cliente OAuth web.
2. Agrega como URI de redirección autorizada:
   `https://<PROJECT_REF>.supabase.co/auth/v1/callback`.
3. En Supabase abre Authentication > Providers > Google, habilita el proveedor
   y registra el Client ID y Client Secret de Google.
4. En Authentication > URL Configuration agrega la URL web de producción y,
   durante desarrollo, `http://127.0.0.1:57164` a Redirect URLs.
5. Despliega las migraciones:

```bash
supabase db push
```

La migración `202610080001_workshop_trial_access.sql` crea los estados de prueba,
vencido, activo y suspendido. El servidor calcula la vigencia; Flutter no puede
conceder acceso permanente por sí mismo.

## Verificación local

```bash
flutter analyze
flutter test
flutter run -d chrome
```

## Recuperación de cuentas

Administradores de talleres y clientes comparten un flujo de recuperación con
dos métodos:

- Código de seis dígitos enviado al correo registrado.
- Código de seis dígitos enviado por SMS al celular verificado.

Después de validar el código, la sesión solo permite crear una contraseña nueva
y luego se cierra. Las solicitudes OTP usan `shouldCreateUser: false`, por lo
que nunca crean una cuenta desconocida durante una recuperación.

Para producción, configura en Supabase la plantilla de correo OTP para mostrar
`{{ .Token }}`, habilita Phone Auth y conecta un proveedor SMS. El celular debe
guardarse como identidad verificada del usuario durante el registro; conservarlo
únicamente como dato de perfil no es suficiente para recuperar la cuenta.
