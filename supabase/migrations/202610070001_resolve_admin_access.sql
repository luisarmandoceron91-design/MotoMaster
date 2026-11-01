create or replace function public.resolve_admin_access()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return null;
  end if;
  if exists (
    select 1 from public.platform_owners owner_row
    where owner_row.user_id = auth.uid()
      and owner_row.status = 'active'
  ) then
    return 'platform_owner';
  end if;
  if exists (
    select 1 from public.admin_access_grants grant_row
    where grant_row.user_id = auth.uid()
      and grant_row.status = 'active'
  ) then
    return 'workshop_owner';
  end if;
  if exists (
    select 1 from public.workshop_members member_row
    where member_row.user_id = auth.uid()
      and member_row.status = 'active'
      and member_row.role in ('owner', 'admin', 'receptionist', 'technician', 'inventory')
  ) then
    return 'workshop_staff';
  end if;
  return null;
end;
$$;

revoke all on function public.resolve_admin_access() from public;
grant execute on function public.resolve_admin_access() to authenticated;
