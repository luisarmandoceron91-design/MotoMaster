drop function if exists public.owner_list_workshops();

create function public.owner_list_workshops()
returns table (
  id uuid,
  name text,
  department text,
  municipality text,
  neighborhood text,
  status text,
  access_status text,
  created_at timestamptz,
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
      w.status, w.access_status, w.created_at, w.trial_ends_at,
      w.permanent_access, w.updated_at, w.deleted_at, w.purge_after,
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
    order by w.created_at desc, w.updated_at desc;
end;
$$;

revoke all on function public.owner_list_workshops() from public, anon;
grant execute on function public.owner_list_workshops() to authenticated;
