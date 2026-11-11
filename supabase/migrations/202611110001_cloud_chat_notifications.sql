-- Alertas persistentes compartidas por todos los dispositivos de una cuenta.
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  workshop_id uuid references public.workshops(id) on delete cascade,
  type text not null default 'general',
  title text not null,
  body text not null default '',
  reference_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists user_notifications_recipient_idx
  on public.user_notifications(recipient_id, read_at, created_at desc);

alter table public.user_notifications enable row level security;

drop policy if exists "user_notifications_select_own" on public.user_notifications;
create policy "user_notifications_select_own" on public.user_notifications
for select to authenticated using (recipient_id = (select auth.uid()));

drop policy if exists "user_notifications_update_own" on public.user_notifications;
create policy "user_notifications_update_own" on public.user_notifications
for update to authenticated using (recipient_id = (select auth.uid()))
with check (recipient_id = (select auth.uid()));

revoke all on public.user_notifications from anon;
grant select, update on public.user_notifications to authenticated;

-- Un cliente puede reactivar por sí mismo la relación con un taller activo.
-- Esto evita que un historial antiguo le impida volver a escribir al taller.
drop policy if exists "client_workshops_update_self_active" on public.client_workshops;
create policy "client_workshops_update_self_active" on public.client_workshops
for update to authenticated using (
  client_id = (select auth.uid()) and private.workshop_has_access(workshop_id)
) with check (
  client_id = (select auth.uid()) and status = 'active'
  and private.workshop_has_access(workshop_id)
);

-- Un mensaje de cliente avisa a los miembros activos del taller. Un mensaje
-- del taller avisa al cliente de esa conversación. El contenido y el aviso
-- quedan en la misma base de datos, nunca solo en un dispositivo.
create or replace function private.notify_message_recipient()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  conversation_record public.conversations%rowtype;
  preview text;
begin
  select * into conversation_record
  from public.conversations
  where id = new.conversation_id;

  if not found then return new; end if;
  preview := coalesce(nullif(left(trim(new.body), 180), ''), 'Te envió un archivo adjunto.');

  if new.sender_id = conversation_record.client_id then
    insert into public.user_notifications (
      recipient_id, workshop_id, type, title, body, reference_id
    )
    select wm.user_id, conversation_record.workshop_id, 'chat_message',
      'Nuevo mensaje de cliente', preview, new.conversation_id
    from public.workshop_members wm
    where wm.workshop_id = conversation_record.workshop_id
      and wm.status = 'active'
      and wm.user_id <> new.sender_id;
  else
    insert into public.user_notifications (
      recipient_id, workshop_id, type, title, body, reference_id
    ) values (
      conversation_record.client_id, conversation_record.workshop_id,
      'chat_message', 'Nuevo mensaje del taller', preview, new.conversation_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists messages_create_notification on public.messages;
create trigger messages_create_notification
after insert on public.messages
for each row execute function private.notify_message_recipient();

-- Avisos por citas y por cambios en el estado del servicio de la moto.
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
    event_body := coalesce(new.service_type, 'Servicio') || ' · ' || to_char(new.scheduled_at at time zone 'America/Bogota', 'DD/MM HH24:MI');
    insert into public.user_notifications (recipient_id, workshop_id, type, title, body, reference_id)
    select wm.user_id, new.workshop_id, event_type, event_title, event_body, new.id
    from public.workshop_members wm
    where wm.workshop_id = new.workshop_id and wm.status = 'active';
  elsif old.status is distinct from new.status or old.service_stage is distinct from new.service_stage then
    event_type := 'appointment_status';
    event_title := 'Actualización de tu moto';
    event_body := coalesce(nullif(new.service_stage, ''), new.status);
    insert into public.user_notifications (recipient_id, workshop_id, type, title, body, reference_id)
    values (new.client_id, new.workshop_id, event_type, event_title, event_body, new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists appointments_create_notification on public.appointments;
create trigger appointments_create_notification
after insert or update of status, service_stage on public.appointments
for each row execute function private.notify_appointment_participants();

do $$
begin
  alter publication supabase_realtime add table public.user_notifications;
exception when duplicate_object then null;
end $$;
