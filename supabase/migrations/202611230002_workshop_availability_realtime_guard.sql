create or replace function public.is_workshop_available(target_workshop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.workshops w
    where w.id = target_workshop_id
      and w.status = 'active'
      and w.deleted_at is null
  );
$$;

revoke all on function public.is_workshop_available(uuid) from public;
grant execute on function public.is_workshop_available(uuid) to anon, authenticated;
