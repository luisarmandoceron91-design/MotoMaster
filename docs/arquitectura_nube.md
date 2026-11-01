# Arquitectura en nube de Moto Master

## Identidad y acceso

Supabase Auth es la fuente de identidad. Cada cuenta recibe un `user_id` UUID permanente. El correo sirve para iniciar sesion, pero las motos, mensajes, ordenes y talleres se relacionan con el UUID; por eso los datos no se pierden al entrar desde otro dispositivo.

Flujo del cliente:

1. Un usuario nuevo crea cuenta una sola vez.
2. Si la confirmacion de correo esta activa, confirma el enlace recibido.
3. En dispositivos nuevos inicia sesion con correo y contrasena.
4. La app recupera `profiles` y muestra la seleccion de talleres.
5. Al elegir uno crea o reactiva `client_workshops` y entra al panel.
6. Los cambios de perfil se hacen desde el panel y se guardan en nube.

Flujo del administrador:

1. El propietario crea una cuenta de administrador.
2. Personaliza y crea su taller; queda registrado como `owner`.
3. En accesos posteriores la app recupera sus membresias en `workshop_members`.
4. Los productos, clientes, ordenes y conversaciones siempre llevan `workshop_id`.

## Capas Flutter

- `core/auth`: sesion, registro, acceso, recuperacion y cierre de sesion.
- `core/client`: perfil global del usuario y foto privada.
- `core/workshops`: talleres, propietarios, equipo y vinculacion del cliente.
- `core/catalog`: inventario y productos por taller.
- `core/chat`: conversaciones y mensajes en tiempo real.
- `core/tenant`: taller activo en el dispositivo.
- `core/networking`: inicializacion unica de Supabase.

## Seguridad

La migracion activa Row Level Security en todas las tablas expuestas. Las reglas permiten:

- al cliente leer y editar su perfil;
- al personal leer clientes vinculados a su taller;
- a cada taller administrar solamente sus productos, citas y ordenes;
- a cliente y personal participar solamente en sus conversaciones;
- al propietario y administradores gestionar miembros y configuracion.

La clave publicable puede estar en la aplicacion. Una clave `service_role` nunca debe incluirse en Flutter.

## Configuracion

Para produccion usa parametros de compilacion:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICABLE
```

Aplica primero la migracion documentada en `supabase/README.md`. Hasta aplicarla, las pantallas conectadas mostraran errores de tablas inexistentes.
