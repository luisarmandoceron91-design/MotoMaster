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
  select
    w.id, w.name, w.slug, w.tagline, w.logo_path, w.logo_index,
    w.accent_color, w.status, w.department, w.municipality,
    w.neighborhood, w.address, w.phone, w.email, w.opening_hours,
    w.rating, w.review_count, w.access_status, w.trial_ends_at,
    w.permanent_access
  from public.workshops w
  where w.status = 'active' and w.deleted_at is null
  order by w.name;
$$;

revoke all on function public.list_active_workshops() from public, anon;
grant execute on function public.list_active_workshops() to authenticated;
