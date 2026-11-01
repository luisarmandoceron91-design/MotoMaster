# Backend de Moto Master

La migracion crea la base multi-taller con cuentas, perfiles, talleres, productos, ordenes, citas, chat, almacenamiento y politicas RLS.

## Aplicar la migracion

1. Instala e inicia sesion en Supabase CLI.
2. Vincula este repositorio con el proyecto de Supabase.
3. Ejecuta `supabase db push` desde la raiz del proyecto.
4. En Authentication > URL Configuration agrega las URL web y los deep links moviles.
5. Decide si `Confirm email` estara activo. La aplicacion admite ambos casos.

## Acceso y prueba de administradores

Los talleres nuevos usan `admin` y `123456` solamente para abrir el registro
inicial. Cada administrador debe crear inmediatamente sus credenciales
personales. Al registrar el taller comienza una prueba de tres días.

1. Aplica las migraciones con `supabase db push`.
2. Crea tu usuario propietario en Authentication.
3. Inserta una unica vez su UUID en `public.platform_owners` desde el SQL Editor.
4. Configura la pasarela para confirmar el pago único en el servidor.
5. Después del pago llama `owner_set_workshop_access` con estado `active`.

Al vencer la prueba, el taller queda bloqueado sin borrar información. El estado
`active` concede acceso permanente; `suspended` permite al propietario bloquear
un taller por incumplimiento.

Las claves `service_role` existen solamente en Supabase Functions. Nunca deben
incluirse en Flutter ni mostrarse al administrador.

Nunca uses una clave `service_role` dentro de Flutter. La app solo debe recibir la clave publicable y toda autorizacion se valida con RLS.
