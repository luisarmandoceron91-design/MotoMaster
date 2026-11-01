create or replace function public.owner_purge_workshop(
  target_workshop_id uuid,
  confirmation_name text,
  deletion_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  workshop_name text;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(deletion_reason)) < 8 then
    raise exception 'El motivo debe tener al menos 8 caracteres';
  end if;

  select name into workshop_name
  from public.workshops
  where id = target_workshop_id and deleted_at is not null
  for update;

  if not found then
    raise exception 'El taller debe estar en la papelera';
  end if;
  if lower(trim(confirmation_name)) <> lower(trim(workshop_name)) then
    raise exception 'El nombre de confirmacion no coincide';
  end if;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    'workshop_purged',
    'workshop',
    target_workshop_id,
    jsonb_build_object(
      'name', workshop_name,
      'reason', trim(deletion_reason),
      'irreversible', true
    )
  );

  delete from public.workshops where id = target_workshop_id;
end;
$$;

revoke all on function public.owner_purge_workshop(uuid, text, text)
from public, anon;
grant execute on function public.owner_purge_workshop(uuid, text, text)
to authenticated;
