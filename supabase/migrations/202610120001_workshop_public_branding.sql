alter table public.workshops
  add column if not exists logo_index smallint not null default 0;

alter table public.workshops
  drop constraint if exists workshops_logo_index_check;
alter table public.workshops
  add constraint workshops_logo_index_check
  check (logo_index between 0 and 4);

drop function if exists public.list_active_workshops();
create function public.list_active_workshops()
returns table (
  id uuid, name text, slug text, tagline text, logo_path text,
  logo_index smallint, accent_color bigint, status text,
  department text, municipality text, neighborhood text, address text,
  phone text, email text, opening_hours jsonb, rating numeric,
  review_count integer
)
language sql stable security definer set search_path = '' as $$
  select w.id, w.name, w.slug, w.tagline, w.logo_path, w.logo_index,
    w.accent_color, w.status, w.department, w.municipality,
    w.neighborhood, w.address, w.phone, w.email, w.opening_hours,
    w.rating, w.review_count
  from public.workshops w
  where private.workshop_has_access(w.id)
    and w.deleted_at is null
  order by w.name;
$$;

revoke all on function public.list_active_workshops() from public, anon;
grant execute on function public.list_active_workshops() to authenticated;
