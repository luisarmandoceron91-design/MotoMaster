-- Una moto no puede tener dos citas simultáneas con el mismo taller.
-- Cuando se entrega o cancela, el cliente podrá pedir una nueva.
-- Conservamos la cita más reciente de registros antiguos duplicados y dejamos
-- las anteriores en el historial como canceladas; no se elimina información.
with ranked_open_appointments as (
  select
    id,
    row_number() over (
      partition by workshop_id, client_id, motorcycle_id
      order by scheduled_at desc, created_at desc
    ) as position
  from public.appointments
  where motorcycle_id is not null
    and status in ('requested', 'confirmed', 'in_progress')
)
update public.appointments as appointment
set
  status = 'cancelled',
  service_stage = 'Cita cancelada',
  updated_at = now()
from ranked_open_appointments as ranked
where appointment.id = ranked.id
  and ranked.position > 1;

create unique index if not exists appointments_one_open_motorcycle_per_client
on public.appointments (workshop_id, client_id, motorcycle_id)
where motorcycle_id is not null
  and status in ('requested', 'confirmed', 'in_progress');
