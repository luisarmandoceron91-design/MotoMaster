-- Un taller puede atender varias motos a la misma hora con mecánicos
-- diferentes. Lo que no se permite es reservar/asignar dos veces al mismo
-- mecánico en el mismo horario.
drop index if exists public.appointments_one_active_slot;

create unique index if not exists appointments_one_active_mechanic_slot
on public.appointments (
  workshop_id,
  scheduled_at,
  coalesce(nullif(mechanic_name, ''), nullif(requested_mechanic_name, ''))
)
where status in ('requested', 'confirmed', 'in_progress')
  and coalesce(nullif(mechanic_name, ''), nullif(requested_mechanic_name, '')) is not null;
