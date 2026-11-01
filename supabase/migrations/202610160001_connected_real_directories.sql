-- Directorios reales y aislados para propietario, taller y cliente.

create or replace function public.owner_list_workshops()
returns table (
  id uuid,
  name text,
  department text,
  municipality text,
  neighborhood text,
  status text,
  access_status text,
  trial_ends_at timestamptz,
  permanent_access boolean,
  updated_at timestamptz,
  deleted_at timestamptz,
  purge_after timestamptz,
  administrator_count bigint,
  client_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_platform_owner() then
    raise exception 'Acceso exclusivo para el propietario de la plataforma';
  end if;

  return query
    select
      w.id, w.name, w.department, w.municipality, w.neighborhood,
      w.status, w.access_status, w.trial_ends_at, w.permanent_access,
      w.updated_at, w.deleted_at, w.purge_after,
      (
        select count(*)
        from public.workshop_members wm
        where wm.workshop_id = w.id and wm.status = 'active'
      ) as administrator_count,
      (
        select count(*)
        from public.client_workshops cw
        where cw.workshop_id = w.id and cw.status = 'active'
      ) as client_count
    from public.workshops w
    order by w.updated_at desc;
end;
$$;

create or replace function public.owner_list_platform_accounts()
returns table (
  user_id uuid,
  full_name text,
  email text,
  phone text,
  account_role text,
  workshop_name text,
  account_status text,
  created_at timestamptz
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
    with related_accounts as (
      select
        wm.user_id,
        case wm.role
          when 'owner' then 'Administrador'
          when 'admin' then 'Administrador'
          when 'receptionist' then 'Recepcionista'
          when 'technician' then 'Tecnico'
          when 'inventory' then 'Inventario'
          else 'Colaborador'
        end as account_role,
        w.name as workshop_name,
        wm.status as account_status,
        wm.created_at
      from public.workshop_members wm
      join public.workshops w on w.id = wm.workshop_id

      union all

      select
        cw.client_id,
        'Cliente'::text,
        w.name,
        cw.status,
        cw.joined_at
      from public.client_workshops cw
      join public.workshops w on w.id = cw.workshop_id
    )
    select distinct on (related.user_id, related.account_role, related.workshop_name)
      related.user_id,
      coalesce(nullif(trim(p.full_name), ''), nullif(trim(p.email), ''), 'Usuario') as full_name,
      p.email,
      p.phone,
      related.account_role,
      related.workshop_name,
      related.account_status,
      related.created_at
    from related_accounts related
    join public.profiles p on p.user_id = related.user_id
    order by related.user_id, related.account_role, related.workshop_name,
      related.created_at desc;
end;
$$;

create or replace function public.list_workshop_clients(target_workshop_id uuid)
returns table (
  user_id uuid,
  full_name text,
  email text,
  phone text,
  status text,
  joined_at timestamptz,
  motorcycle_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.can_manage_service(target_workshop_id) then
    raise exception 'No tienes permiso para consultar los clientes de este taller';
  end if;

  return query
    select
      p.user_id,
      coalesce(nullif(trim(p.full_name), ''), nullif(trim(p.email), ''), 'Cliente') as full_name,
      p.email,
      p.phone,
      cw.status,
      cw.joined_at,
      (
        select count(*)
        from public.motorcycles m
        where m.owner_id = cw.client_id
          and (m.workshop_id = target_workshop_id or m.workshop_id is null)
      ) as motorcycle_count
    from public.client_workshops cw
    join public.profiles p on p.user_id = cw.client_id
    where cw.workshop_id = target_workshop_id
    order by cw.joined_at desc;
end;
$$;

revoke all on function public.owner_list_workshops() from public, anon;
revoke all on function public.owner_list_platform_accounts() from public, anon;
revoke all on function public.list_workshop_clients(uuid) from public, anon;
grant execute on function public.owner_list_workshops() to authenticated;
grant execute on function public.owner_list_platform_accounts() to authenticated;
grant execute on function public.list_workshop_clients(uuid) to authenticated;

-- Las suscripciones respetan las mismas politicas RLS de cada tabla.
do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'workshops'
  ) then
    alter publication supabase_realtime add table public.workshops;
  end if;
  if not exists (
    select 1 from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'client_workshops'
  ) then
    alter publication supabase_realtime add table public.client_workshops;
  end if;
end;
$$;
