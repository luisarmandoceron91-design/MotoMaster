-- Papelera recuperable para talleres. Reemplaza la eliminacion fisica inmediata.

alter table public.workshops
  add column if not exists deleted_at timestamptz,
  add column if not exists purge_after timestamptz,
  add column if not exists deleted_by uuid references auth.users(id) on delete set null,
  add column if not exists deletion_reason text,
  add column if not exists previous_status text,
  add column if not exists previous_access_status text;

create index if not exists workshops_deleted_at_idx
  on public.workshops (deleted_at)
  where deleted_at is not null;

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
  workshop_row public.workshops%rowtype;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(deletion_reason)) < 8 then
    raise exception 'El motivo debe tener al menos 8 caracteres';
  end if;

  select * into workshop_row
  from public.workshops
  where id = target_workshop_id
  for update;
  if not found then raise exception 'Taller no encontrado'; end if;
  if workshop_row.deleted_at is not null then
    raise exception 'El taller ya se encuentra en la papelera';
  end if;
  if lower(trim(confirmation_name)) <> lower(trim(workshop_row.name)) then
    raise exception 'El nombre de confirmacion no coincide';
  end if;

  update public.workshops
  set previous_status = status,
      previous_access_status = access_status,
      status = 'inactive',
      access_status = 'suspended',
      deleted_at = now(),
      purge_after = now() + interval '30 days',
      deleted_by = (select auth.uid()),
      deletion_reason = trim(deletion_reason),
      access_note = 'Taller en papelera: ' || trim(deletion_reason),
      updated_at = now()
  where id = target_workshop_id;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    'workshop_moved_to_trash',
    'workshop',
    target_workshop_id,
    jsonb_build_object(
      'workshop_name', workshop_row.name,
      'purge_after', now() + interval '30 days',
      'reason', trim(deletion_reason)
    )
  );
end;
$$;

create or replace function public.owner_restore_workshop(
  target_workshop_id uuid,
  restore_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  workshop_row public.workshops%rowtype;
  restored_access text;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(restore_reason)) < 5 then
    raise exception 'El motivo de recuperacion es obligatorio';
  end if;

  select * into workshop_row
  from public.workshops
  where id = target_workshop_id
  for update;
  if not found then raise exception 'Taller no encontrado'; end if;
  if workshop_row.deleted_at is null then
    raise exception 'El taller no se encuentra en la papelera';
  end if;

  restored_access := coalesce(workshop_row.previous_access_status, 'expired');
  if restored_access = 'trial' and now() >= workshop_row.trial_ends_at then
    restored_access := 'expired';
  end if;
  if workshop_row.permanent_access then restored_access := 'active'; end if;

  update public.workshops
  set status = coalesce(workshop_row.previous_status, 'active'),
      access_status = restored_access,
      deleted_at = null,
      purge_after = null,
      deleted_by = null,
      deletion_reason = null,
      previous_status = null,
      previous_access_status = null,
      access_note = trim(restore_reason),
      updated_at = now()
  where id = target_workshop_id;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    'workshop_restored',
    'workshop',
    target_workshop_id,
    jsonb_build_object(
      'workshop_name', workshop_row.name,
      'restored_access_status', restored_access,
      'reason', trim(restore_reason)
    )
  );
end;
$$;

revoke all on function public.owner_restore_workshop(uuid, text)
from public, anon;
grant execute on function public.owner_restore_workshop(uuid, text)
to authenticated;
