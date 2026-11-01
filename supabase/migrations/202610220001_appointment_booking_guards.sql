alter table public.appointments
  add column if not exists service_type text not null default 'Mantenimiento',
  add column if not exists motorcycle_name text not null default '',
  add column if not exists service_stage text not null default 'Cita solicitada',
  add column if not exists mechanic_name text not null default '';

create unique index if not exists appointments_one_active_slot
on public.appointments (workshop_id, scheduled_at)
where status <> 'cancelled';

create or replace function private.enforce_client_appointment_cancellation()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if old.client_id = (select auth.uid())
     and old.status <> 'cancelled'
     and new.status = 'cancelled'
     and old.scheduled_at < now() + interval '24 hours' then
    raise exception using
      errcode = 'P0001',
      message = 'La cita solo puede cancelarse con 24 horas de anticipación.';
  end if;
  return new;
end;
$$;

drop trigger if exists appointments_client_cancellation_guard
on public.appointments;
create trigger appointments_client_cancellation_guard
before update of status on public.appointments
for each row execute function private.enforce_client_appointment_cancellation();

create table if not exists public.appointment_reminders (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments(id) on delete cascade,
  channel text not null check (channel in ('email', 'sms', 'push')),
  scheduled_for timestamptz not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  sent_at timestamptz,
  error_message text not null default '',
  created_at timestamptz not null default now(),
  unique (appointment_id, channel)
);

alter table public.appointment_reminders enable row level security;

drop policy if exists "appointment_reminders_select_participants"
on public.appointment_reminders;
create policy "appointment_reminders_select_participants"
on public.appointment_reminders
for select to authenticated using (
  exists (
    select 1
    from public.appointments appointment
    where appointment.id = appointment_id
      and (
        appointment.client_id = (select auth.uid())
        or private.is_workshop_member(appointment.workshop_id)
      )
  )
);

create or replace function private.schedule_appointment_reminders()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if new.status = 'cancelled' then
    update public.appointment_reminders
       set status = 'cancelled'
     where appointment_id = new.id
       and status = 'pending';
    return new;
  end if;

  insert into public.appointment_reminders (
    appointment_id,
    channel,
    scheduled_for
  )
  values
    (new.id, 'email', new.scheduled_at - interval '24 hours'),
    (new.id, 'push', new.scheduled_at - interval '24 hours')
  on conflict (appointment_id, channel) do update
    set scheduled_for = excluded.scheduled_for,
        status = 'pending',
        sent_at = null,
        error_message = '';

  return new;
end;
$$;

drop trigger if exists appointments_schedule_reminders on public.appointments;
create trigger appointments_schedule_reminders
after insert or update of scheduled_at, status on public.appointments
for each row execute function private.schedule_appointment_reminders();

revoke all on public.appointment_reminders from anon;
grant select on public.appointment_reminders to authenticated;
