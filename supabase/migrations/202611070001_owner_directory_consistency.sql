-- Mantiene conectados el control del propietario, la papelera y el
-- directorio público de clientes.

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

drop function if exists public.owner_list_workshops();
create function public.owner_list_workshops()
returns table (
  id uuid, name text, department text, municipality text, neighborhood text,
  status text, access_status text, created_at timestamptz,
  trial_ends_at timestamptz, permanent_access boolean, updated_at timestamptz,
  deleted_at timestamptz, purge_after timestamptz,
  administrator_count bigint, client_count bigint
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_platform_owner() then
    raise exception 'Acceso exclusivo para el propietario de la plataforma';
  end if;
  return query
    select w.id, w.name, w.department, w.municipality, w.neighborhood,
      w.status, w.access_status, w.created_at, w.trial_ends_at,
      w.permanent_access, w.updated_at, w.deleted_at, w.purge_after,
      (select count(*) from public.workshop_members wm
       where wm.workshop_id = w.id and wm.status = 'active'),
      (select count(*) from public.client_workshops cw
       where cw.workshop_id = w.id and cw.status = 'active')
    from public.workshops w
    order by w.created_at desc, w.updated_at desc;
end;
$$;

create or replace function public.owner_delete_workshop(
  target_workshop_id uuid, confirmation_name text, deletion_reason text
)
returns void language plpgsql security definer set search_path = '' as $$
declare workshop_row public.workshops%rowtype;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(deletion_reason)) < 8 then
    raise exception 'El motivo de eliminacion debe tener al menos 8 caracteres';
  end if;
  select * into workshop_row from public.workshops
  where id = target_workshop_id for update;
  if not found then raise exception 'Taller no encontrado'; end if;
  if workshop_row.deleted_at is not null then
    raise exception 'El taller ya se encuentra en la papelera';
  end if;
  if lower(trim(confirmation_name)) <> lower(trim(workshop_row.name)) then
    raise exception 'El nombre de confirmacion no coincide';
  end if;
  update public.workshops
  set previous_status = status, previous_access_status = access_status,
      status = 'inactive', access_status = 'suspended', deleted_at = now(),
      purge_after = now() + interval '30 days', deleted_by = (select auth.uid()),
      deletion_reason = trim(deletion_reason),
      access_note = 'Taller en papelera: ' || trim(deletion_reason), updated_at = now()
  where id = target_workshop_id;
end;
$$;

create or replace function public.owner_restore_workshop(
  target_workshop_id uuid, restore_reason text
)
returns void language plpgsql security definer set search_path = '' as $$
declare workshop_row public.workshops%rowtype; restored_access text;
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if length(trim(restore_reason)) < 5 then
    raise exception 'El motivo de recuperacion es obligatorio';
  end if;
  select * into workshop_row from public.workshops
  where id = target_workshop_id for update;
  if not found then raise exception 'Taller no encontrado'; end if;
  if workshop_row.deleted_at is null then
    raise exception 'El taller no se encuentra en la papelera';
  end if;
  restored_access := coalesce(workshop_row.previous_access_status, 'expired');
  if workshop_row.permanent_access then restored_access := 'active'; end if;
  if restored_access = 'trial' and now() >= workshop_row.trial_ends_at then
    restored_access := 'expired';
  end if;
  update public.workshops
  set status = coalesce(workshop_row.previous_status, 'active'),
      access_status = restored_access, deleted_at = null, purge_after = null,
      deleted_by = null, deletion_reason = null, previous_status = null,
      previous_access_status = null, access_note = trim(restore_reason), updated_at = now()
  where id = target_workshop_id;
end;
$$;

drop function if exists public.list_active_workshops();
create function public.list_active_workshops()
returns table (
  id uuid, name text, slug text, tagline text, logo_path text,
  logo_index smallint, accent_color bigint, status text,
  department text, municipality text, neighborhood text, address text,
  phone text, email text, opening_hours jsonb, rating numeric,
  review_count integer, access_status text, trial_ends_at timestamptz,
  permanent_access boolean
)
language sql stable security definer set search_path = '' as $$
  select w.id, w.name, w.slug, w.tagline, w.logo_path, w.logo_index,
    w.accent_color, w.status, w.department, w.municipality, w.neighborhood,
    w.address, w.phone, w.email, w.opening_hours, w.rating, w.review_count,
    w.access_status, w.trial_ends_at, w.permanent_access
  from public.workshops w
  where w.status = 'active' and w.deleted_at is null
  order by w.name;
$$;

revoke all on function public.owner_list_workshops() from public, anon;
revoke all on function public.list_active_workshops() from public, anon;
grant execute on function public.owner_list_workshops() to authenticated;
grant execute on function public.owner_delete_workshop(uuid, text, text) to authenticated;
grant execute on function public.owner_restore_workshop(uuid, text) to authenticated;
grant execute on function public.list_active_workshops() to authenticated;
