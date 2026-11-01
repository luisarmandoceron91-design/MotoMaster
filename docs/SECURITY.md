# Seguridad de Moto Master

Moto Master es una aplicacion multi-tenant: cada taller es un tenant. Ningun
filtro de la interfaz se considera una barrera de seguridad. La separacion se
aplica en PostgreSQL con RLS y debe probarse usando identidades distintas.

## Reglas obligatorias

- Toda fila privada incluye o deriva un `workshop_id` y las politicas validan
  la pertenencia con `auth.uid()`.
- Clientes y empleados usan cuentas individuales. Nunca se comparten
  contrasenas de produccion.
- `admin / 123456` solo abre el registro local de demostracion. No es una
  cuenta del servidor y debe deshabilitarse en la compilacion publica.
- La clave `service_role` jamas se incluye en Flutter, JavaScript ni archivos
  publicos. Solo se usa en un backend o Edge Function protegido.
- Los administradores no pueden leer datos de otro taller aunque manipulen URL,
  identificadores o llamadas REST.
- Los clientes no pueden desbloquear su relacion, completar citas, cambiar
  ordenes ni editar mensajes ya enviados.
- El propietario no tiene lectura general de perfiles. Sus cambios de acceso
  requieren MFA `aal2` y quedan en `platform_audit_log`.
- Suspender o vencer un taller bloquea sus operaciones; los datos no se borran.
- Ampliar una prueba o mover un taller a la papelera requiere MFA, motivo y
  auditoria. La papelera bloquea el acceso, pero conserva el mismo
  \`workshop_id\` y todas sus relaciones para restaurarlas.
- Una solicitud de tiempo no cambia el acceso. Solo una aprobacion propietaria
  modifica `trial_ends_at`; el `workshop_id`, la marca y los datos se conservan.

## Configuracion antes de produccion

1. Aplicar migraciones con `supabase db push`.
2. Activar confirmacion de correo, proteccion de contrasenas filtradas, CAPTCHA,
   limites de intentos y MFA en Supabase Auth.
3. Configurar SMTP propio, redirecciones exactas y expiracion corta de OTP.
4. Forzar SSL, activar copias de seguridad/PITR y revisar Security Advisor.
5. Separar desarrollo, pruebas y produccion; rotar secretos y restringir el
   acceso administrativo por red cuando sea posible.
6. Servir la web con CSP estricta, HSTS, `frame-ancestors`, `nosniff` y una
   politica de permisos minima. Evitar scripts de terceros innecesarios.
7. Guardar en buckets publicos solo logos y fotos comerciales. Facturas, chats,
   perfiles y documentos siempre van en buckets privados con URL firmada corta.
8. Alertar inicios anomalos, cambios de rol, exportaciones, fallos repetidos y
   acciones del propietario.
9. Definir y comunicar una politica de retencion. Antes de una eliminacion real,
   respaldar los documentos exigidos por obligaciones contables o legales.

## Verificacion requerida

- Probar por cada tabla que el usuario A recibe cero filas del taller B.
- Probar lectura, insercion, actualizacion, eliminacion, RPC, Storage y Realtime.
- Cubrir cliente, tecnico, inventario, administrador, dueno, propietario de
  plataforma y cuenta suspendida o expirada.
- Ejecutar analisis de dependencias, SAST, DAST y una prueba de penetracion
  independiente antes de procesar datos o pagos reales.

La seguridad comparable a una entidad financiera requiere operacion continua,
monitoreo, respuesta a incidentes, copias verificadas y revisiones externas.
