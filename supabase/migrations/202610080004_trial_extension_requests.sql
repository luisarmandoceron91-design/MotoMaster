-- Solicitudes de tiempo adicional: el administrador solicita y el propietario
-- decide. Ninguna solicitud modifica por si sola la fecha del taller.

create table if not exists public.trial_extension_requests (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  requested_days integer not null check (requested_days between 1 and 30),
  request_reason text not null check (length(trim(request_reason)) >= 8),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  granted_days integer check (granted_days between 1 and 90),
  decision_reason text,
  decided_by uuid references auth.users(id) on delete set null,
  requested_at timestamptz not null default now(),
  decided_at timestamptz
);

create unique index if not exists trial_extension_one_pending_per_workshop
  on public.trial_extension_requests (workshop_id)
  where status = 'pending';
create index if not exists trial_extension_status_requested_idx
  on public.trial_extension_requests (status, requested_at desc);

alter table public.trial_extension_requests enable row level security;
revoke all on table public.trial_extension_requests from anon, authenticated;

create or replace function public.request_trial_extension(
  target_workshop_id uuid,
  requested_days integer,
  request_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_request_id uuid;
  has_permanent_access boolean;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesion'; end if;
  if requested_days < 1 or requested_days > 30 then
    raise exception 'La solicitud debe estar entre 1 y 30 dias';
  end if;
  if length(trim(request_reason)) < 8 then
    raise exception 'Explica por que necesitas mas tiempo';
  end if;
  if not exists (
    select 1 from public.workshop_members wm
    where wm.workshop_id = target_workshop_id
      and wm.user_id = (select auth.uid())
      and wm.status = 'active'
      and wm.role in ('owner', 'admin')
  ) then
    raise exception 'No administras este taller';
  end if;

  select permanent_access into has_permanent_access
  from public.workshops where id = target_workshop_id;
  if not found then raise exception 'Taller no encontrado'; end if;
  if has_permanent_access then
    raise exception 'El taller ya tiene acceso permanente';
  end if;
  if exists (
    select 1 from public.trial_extension_requests request
    where request.workshop_id = target_workshop_id
      and request.status = 'pending'
  ) then
    raise exception 'Ya existe una solicitud pendiente';
  end if;

  insert into public.trial_extension_requests (
    workshop_id, requester_id, requested_days, request_reason
  ) values (
    target_workshop_id, (select auth.uid()), requested_days,
    trim(request_reason)
  ) returning id into new_request_id;

  return new_request_id;
end;
$$;

create or replace function public.owner_list_trial_extension_requests()
returns table (
  request_id uuid,
  workshop_id uuid,
  workshop_name text,
  requested_days integer,
  request_reason text,
  requested_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  return query
    select request.id, request.workshop_id, workshop.name,
      request.requested_days, request.request_reason, request.requested_at
    from public.trial_extension_requests request
    join public.workshops workshop on workshop.id = request.workshop_id
    where request.status = 'pending'
    order by request.requested_at;
end;
$$;

create or replace function public.owner_decide_trial_extension(
  target_request_id uuid,
  approve_request boolean,
  granted_days integer,
  decision_reason text
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_row public.trial_extension_requests%rowtype;
  current_end timestamptz;
  new_end timestamptz;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(decision_reason)) < 5 then
    raise exception 'El motivo de la decision es obligatorio';
  end if;
  if approve_request and (granted_days < 1 or granted_days > 90) then
    raise exception 'La ampliacion debe estar entre 1 y 90 dias';
  end if;

  select * into request_row
  from public.trial_extension_requests
  where id = target_request_id
  for update;
  if not found then raise exception 'Solicitud no encontrada'; end if;
  if request_row.status <> 'pending' then
    raise exception 'La solicitud ya fue atendida';
  end if;

  if approve_request then
    select trial_ends_at into current_end
    from public.workshops
    where id = request_row.workshop_id
    for update;
    if not found then raise exception 'Taller no encontrado'; end if;

    new_end := greatest(coalesce(current_end, now()), now())
      + make_interval(days => granted_days);
    update public.workshops
    set access_status = 'trial',
        permanent_access = false,
        trial_ends_at = new_end,
        access_note = trim(decision_reason),
        updated_at = now()
    where id = request_row.workshop_id;
  end if;

  update public.trial_extension_requests
  set status = case when approve_request then 'approved' else 'rejected' end,
      granted_days = case when approve_request then granted_days else null end,
      decision_reason = trim(decision_reason),
      decided_by = (select auth.uid()),
      decided_at = now()
  where id = target_request_id;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    case when approve_request
      then 'trial_extension_approved'
      else 'trial_extension_rejected' end,
    'trial_extension_request',
    target_request_id,
    jsonb_build_object(
      'workshop_id', request_row.workshop_id,
      'requested_days', request_row.requested_days,
      'granted_days', case when approve_request then granted_days else null end,
      'reason', trim(decision_reason)
    )
  );
  return new_end;
end;
$$;

revoke all on function public.request_trial_extension(uuid, integer, text)
from public, anon;
revoke all on function public.owner_list_trial_extension_requests()
from public, anon;
revoke all on function public.owner_decide_trial_extension(uuid, boolean, integer, text)
from public, anon;
grant execute on function public.request_trial_extension(uuid, integer, text)
to authenticated;
grant execute on function public.owner_list_trial_extension_requests()
to authenticated;
grant execute on function public.owner_decide_trial_extension(uuid, boolean, integer, text)
to authenticated;
