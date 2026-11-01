create or replace function public.list_active_workshops()
returns table (
  id uuid,
  name text,
  slug text,
  tagline text,
  logo_path text,
  accent_color bigint,
  status text,
  department text,
  municipality text,
  neighborhood text,
  address text,
  opening_hours jsonb,
  rating numeric,
  review_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    w.id,
    w.name,
    w.slug,
    w.tagline,
    w.logo_path,
    w.accent_color,
    w.status,
    w.department,
    w.municipality,
    w.neighborhood,
    w.address,
    w.opening_hours,
    w.rating,
    w.review_count
  from public.workshops w
  where w.status = 'active'
  order by w.name;
$$;

revoke all on function public.list_active_workshops() from public;
grant execute on function public.list_active_workshops() to anon, authenticated;
