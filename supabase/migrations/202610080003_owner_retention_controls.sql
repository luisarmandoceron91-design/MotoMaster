-- Controles propietarios para ampliar pruebas y eliminar talleres.
-- Ambas operaciones exigen MFA y generan una entrada de auditoria.

create or replace function public.owner_extend_workshop_trial(
  target_workshop_id uuid,
  additional_days integer,
  change_reason text
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_end timestamptz;
  new_end timestamptz;
  has_permanent_access boolean;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if additional_days < 1 or additional_days > 90 then
    raise exception 'La ampliacion debe estar entre 1 y 90 dias';
  end if;
  if length(trim(change_reason)) < 5 then
    raise exception 'El motivo de la ampliacion es obligatorio';
  end if;

  select trial_ends_at, permanent_access
  into current_end, has_permanent_access
  from public.workshops
  where id = target_workshop_id
  for update;

  if not found then raise exception 'Taller no encontrado'; end if;
  if has_permanent_access then
    raise exception 'El taller ya tiene acceso permanente';
  end if;

  new_end := greatest(coalesce(current_end, now()), now())
    + make_interval(days => additional_days);

  update public.workshops
  set access_status = 'trial',
      permanent_access = false,
      trial_ends_at = new_end,
      access_note = trim(change_reason),
      updated_at = now()
  where id = target_workshop_id;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    'workshop_trial_extended',
    'workshop',
    target_workshop_id,
    jsonb_build_object(
      'additional_days', additional_days,
      'previous_end', current_end,
      'new_end', new_end,
      'reason', trim(change_reason)
    )
  );
  return new_end;
end;
$$;

create or replace function public.owner_delete_workshop(
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
  workshop_creator uuid;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(deletion_reason)) < 8 then
    raise exception 'El motivo de eliminacion debe tener al menos 8 caracteres';
  end if;

  select name, created_by
  into workshop_name, workshop_creator
  from public.workshops
  where id = target_workshop_id
  for update;

  if not found then raise exception 'Taller no encontrado'; end if;
  if lower(trim(confirmation_name)) <> lower(trim(workshop_name)) then
    raise exception 'El nombre de confirmacion no coincide';
  end if;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    'workshop_deleted',
    'workshop',
    target_workshop_id,
    jsonb_build_object(
      'workshop_name', workshop_name,
      'creator_id', workshop_creator,
      'reason', trim(deletion_reason)
    )
  );

  -- Las relaciones privadas se eliminan mediante sus claves foraneas.
  -- Las motocicletas del cliente se conservan y pierden solo workshop_id.
  delete from public.workshops where id = target_workshop_id;
end;
$$;

revoke all on function public.owner_extend_workshop_trial(uuid, integer, text)
from public, anon;
revoke all on function public.owner_delete_workshop(uuid, text, text)
from public, anon;
grant execute on function public.owner_extend_workshop_trial(uuid, integer, text)
to authenticated;
grant execute on function public.owner_delete_workshop(uuid, text, text)
to authenticated;
