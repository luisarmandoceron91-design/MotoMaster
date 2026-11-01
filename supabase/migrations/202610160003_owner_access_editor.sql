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
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(change_reason)) < 3 then
    raise exception 'El motivo es obligatorio';
  end if;

  if enabled then
    update public.workshops
    set status = 'active',
        access_status = 'active',
        permanent_access = true,
        activated_at = coalesce(activated_at, now()),
        suspended_at = null,
        availability_previous_access_status = null,
        access_note = trim(change_reason),
        updated_at = now()
    where id = target_workshop_id and deleted_at is null;
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
  end if;

  if not found then raise exception 'Taller no encontrado'; end if;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    case when enabled then 'workshop_activated' else 'workshop_suspended' end,
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
