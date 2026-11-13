-- La preferencia del cliente se guarda separada de la asignación definitiva
-- del administrador para que ambos datos sean visibles en todos los equipos.
alter table public.appointments
  add column if not exists requested_mechanic_name text not null default '';

-- Las citas creadas con la versión anterior ya conservaban mechanic_name.
-- Lo usamos también como preferencia histórica para que no pierdan contexto.
update public.appointments
set requested_mechanic_name = mechanic_name
where coalesce(requested_mechanic_name, '') = ''
  and coalesce(mechanic_name, '') <> '';
