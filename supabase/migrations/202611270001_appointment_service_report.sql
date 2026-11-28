-- Orden de servicio publicada por el administrador y visible para el cliente.
alter table public.appointments
  add column if not exists service_report jsonb not null default '{}'::jsonb;

-- Reemplaza el aviso genérico por uno claro cuando el administrador acepta.
create or replace function private.notify_appointment_participants()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  event_type text;
  event_title text;
  event_body text;
begin
  if tg_op = 'INSERT' then
    event_type := 'appointment';
    event_title := 'Nueva cita solicitada';
    event_body := coalesce(new.service_type, 'Servicio') || ' · ' ||
      to_char(new.scheduled_at at time zone 'America/Bogota', 'DD/MM HH24:MI');
    insert into public.user_notifications (
      recipient_id, workshop_id, type, title, body, reference_id
    )
    select wm.user_id, new.workshop_id, event_type, event_title, event_body, new.id
    from public.workshop_members wm
    where wm.workshop_id = new.workshop_id and wm.status = 'active';
  elsif old.status is distinct from new.status
     or old.service_stage is distinct from new.service_stage
     or old.service_report is distinct from new.service_report then
    event_type := 'appointment_status';
    if old.status is distinct from new.status and new.status = 'confirmed' then
      event_title := 'Cita aceptada';
      event_body := 'Tu cita fue aceptada para ' ||
        to_char(new.scheduled_at at time zone 'America/Bogota', 'DD/MM/YYYY HH24:MI');
    elsif old.service_report is distinct from new.service_report
      and coalesce((new.service_report ->> 'published')::boolean, false) then
      event_title := 'Orden de servicio actualizada';
      event_body := 'El taller publicó los detalles y el valor de tu servicio.';
    else
      event_title := 'Actualización de tu moto';
      event_body := coalesce(nullif(new.service_stage, ''), new.status);
    end if;
    insert into public.user_notifications (
      recipient_id, workshop_id, type, title, body, reference_id
    ) values (
      new.client_id, new.workshop_id, event_type, event_title, event_body, new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists appointments_create_notification on public.appointments;
create trigger appointments_create_notification
after insert or update of status, service_stage, service_report on public.appointments
for each row execute function private.notify_appointment_participants();

do $$
begin
  alter publication supabase_realtime add table public.appointments;
exception when duplicate_object then null;
end $$;
