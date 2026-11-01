create or replace function private.is_platform_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.platform_owners owner_row
    where owner_row.user_id = (select auth.uid())
      and owner_row.status = 'active'
  );
$$;

grant execute on function private.is_platform_owner() to authenticated;

create table if not exists public.platform_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists platform_audit_log_created_idx
  on public.platform_audit_log (created_at desc);

alter table public.platform_audit_log enable row level security;

create policy "platform_owner_read_workshops" on public.workshops
for select to authenticated using (private.is_platform_owner());

create policy "platform_owner_update_workshops" on public.workshops
for update to authenticated using (private.is_platform_owner())
with check (private.is_platform_owner());

create policy "platform_owner_read_members" on public.workshop_members
for select to authenticated using (private.is_platform_owner());

create policy "platform_owner_read_profiles" on public.profiles
for select to authenticated using (private.is_platform_owner());

create policy "platform_owner_read_audit" on public.platform_audit_log
for select to authenticated using (private.is_platform_owner());

create or replace function public.owner_set_workshop_status(
  target_workshop_id uuid,
  new_status text,
  change_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_platform_owner() then
    raise exception 'Acceso exclusivo para el propietario de la plataforma';
  end if;
  if new_status not in ('active', 'inactive', 'suspended') then
    raise exception 'Estado de taller no válido';
  end if;
  if length(trim(change_reason)) < 3 then
    raise exception 'El motivo es obligatorio';
  end if;

  update public.workshops
  set status = new_status, updated_at = now()
  where id = target_workshop_id;

  if not found then
    raise exception 'Taller no encontrado';
  end if;

  insert into public.platform_audit_log (
    actor_id,
    action,
    entity_type,
    entity_id,
    detail
  ) values (
    (select auth.uid()),
    'workshop_status_changed',
    'workshop',
    target_workshop_id,
    jsonb_build_object('status', new_status, 'reason', trim(change_reason))
  );
end;
$$;

revoke all on function public.owner_set_workshop_status(uuid, text, text)
from public;
grant execute on function public.owner_set_workshop_status(uuid, text, text)
to authenticated;
