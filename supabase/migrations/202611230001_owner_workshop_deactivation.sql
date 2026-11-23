-- El propietario de la plataforma autorizó operar activación y
-- desactivación desde su panel sin depender de MFA de Supabase. La función
-- conserva la validación estricta de propietario y el registro de auditoría.
create or replace function public.owner_set_workshop_availability(
  target_workshop_id uuid, enabled boolean, change_reason text
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_platform_owner() then
    raise exception 'Acceso exclusivo para el propietario de la plataforma';
  end if;
  if length(trim(change_reason)) < 3 then
    raise exception 'El motivo es obligatorio';
  end if;

  if enabled then
    update public.workshops
    set status = 'active',
        access_status = 'active',
        suspended_at = null,
        access_note = trim(change_reason),
        updated_at = now()
    where id = target_workshop_id and deleted_at is null;
  else
    update public.workshops
    set status = 'suspended',
        access_status = 'suspended',
        suspended_at = now(),
        access_note = trim(change_reason),
        updated_at = now()
    where id = target_workshop_id and deleted_at is null;
  end if;

  if not found then
    raise exception 'Taller no encontrado';
  end if;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    case when enabled then 'workshop_activated' else 'workshop_deactivated' end,
    'workshop', target_workshop_id,
    jsonb_build_object('enabled', enabled, 'reason', trim(change_reason))
  );
end;
$$;

revoke all on function public.owner_set_workshop_availability(uuid, boolean, text)
from public, anon;
grant execute on function public.owner_set_workshop_availability(uuid, boolean, text)
to authenticated;
