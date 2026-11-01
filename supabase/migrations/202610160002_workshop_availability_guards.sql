alter table public.workshops
  add column if not exists availability_previous_access_status text;

alter table public.workshops
  drop constraint if exists workshops_previous_access_status_check;
alter table public.workshops
  add constraint workshops_previous_access_status_check
  check (
    availability_previous_access_status is null
    or availability_previous_access_status in ('trial', 'active', 'expired')
  );

create or replace function public.owner_set_workshop_availability(
  target_workshop_id uuid,
  enabled boolean,
  change_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  restored_access text;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(change_reason)) < 3 then
    raise exception 'El motivo es obligatorio';
  end if;

  if enabled then
    select coalesce(
      w.availability_previous_access_status,
      case
        when w.permanent_access then 'active'
        when w.access_status = 'trial' and now() < w.trial_ends_at then 'trial'
        when w.access_status = 'active' then 'active'
        else 'expired'
      end
    )
    into restored_access
    from public.workshops w
    where w.id = target_workshop_id and w.deleted_at is null
    for update;

    if not found then raise exception 'Taller no encontrado'; end if;

    update public.workshops
    set status = 'active',
        access_status = restored_access,
        suspended_at = null,
        availability_previous_access_status = null,
        access_note = trim(change_reason),
        updated_at = now()
    where id = target_workshop_id;
  else
    update public.workshops
    set availability_previous_access_status = case
          when access_status in ('trial', 'active', 'expired') then access_status
          else coalesce(availability_previous_access_status, 'expired')
        end,
        status = 'suspended',
        access_status = 'suspended',
        suspended_at = now(),
        access_note = trim(change_reason),
        updated_at = now()
    where id = target_workshop_id and deleted_at is null;

    if not found then raise exception 'Taller no encontrado'; end if;
  end if;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    case when enabled then 'workshop_reactivated' else 'workshop_suspended' end,
    'workshop',
    target_workshop_id,
    jsonb_build_object(
      'enabled', enabled,
      'reason', trim(change_reason),
      'data_retained', true
    )
  );
end;
$$;

revoke all on function public.owner_set_workshop_availability(uuid, boolean, text)
from public, anon;
grant execute on function public.owner_set_workshop_availability(uuid, boolean, text)
to authenticated;

create or replace function public.resolve_admin_access()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then return null; end if;
  if private.is_platform_owner() then return 'platform_owner'; end if;

  if exists (
    select 1
    from public.workshop_members wm
    where wm.user_id = (select auth.uid())
      and wm.status = 'active'
      and wm.role in ('owner', 'admin', 'receptionist', 'technician', 'inventory')
      and private.workshop_has_access(wm.workshop_id)
  ) then
    return 'workshop_staff';
  end if;

  if exists (
    select 1
    from public.workshop_members wm
    join public.workshops w on w.id = wm.workshop_id
    where wm.user_id = (select auth.uid())
      and wm.status = 'active'
      and wm.role in ('owner', 'admin', 'receptionist', 'technician', 'inventory')
      and w.deleted_at is null
      and (w.status = 'suspended' or w.access_status = 'suspended')
  ) then
    return 'workshop_suspended';
  end if;

  if exists (
    select 1
    from public.workshop_members wm
    join public.workshops w on w.id = wm.workshop_id
    where wm.user_id = (select auth.uid())
      and wm.status = 'active'
      and wm.role in ('owner', 'admin', 'receptionist', 'technician', 'inventory')
      and w.deleted_at is null
  ) then
    return 'workshop_expired';
  end if;

  return null;
end;
$$;

revoke all on function public.resolve_admin_access() from public, anon;
grant execute on function public.resolve_admin_access() to authenticated;
