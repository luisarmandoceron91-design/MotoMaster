create extension if not exists pgcrypto with schema extensions;

create table if not exists public.platform_owners (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now()
);

alter table public.platform_owners enable row level security;

create table if not exists public.admin_invitations (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  code_suffix text not null,
  plan text not null default 'standard',
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_access_grants (
  user_id uuid primary key references auth.users(id) on delete cascade,
  invitation_id uuid not null unique references public.admin_invitations(id),
  status text not null default 'active' check (status in ('active', 'suspended', 'revoked')),
  created_at timestamptz not null default now()
);

alter table public.admin_invitations enable row level security;
alter table public.admin_access_grants enable row level security;

create policy "admin_grants_select_own" on public.admin_access_grants
for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "workshops_insert_creator" on public.workshops;
create policy "workshops_insert_authorized_owner" on public.workshops
for insert to authenticated with check (
  created_by = (select auth.uid())
  and exists (
    select 1 from public.admin_access_grants grant_row
    where grant_row.user_id = (select auth.uid())
      and grant_row.status = 'active'
  )
);

create or replace function public.create_admin_invitation(
  requested_plan text default 'standard',
  valid_for interval default interval '7 days'
)
returns table (invitation_id uuid, activation_code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  raw_code text;
  new_id uuid;
  expiration timestamptz;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Solo el propietario de la plataforma puede crear invitaciones';
  end if;
  raw_code := upper(encode(extensions.gen_random_bytes(9), 'hex'));
  expiration := now() + valid_for;
  insert into public.admin_invitations (
    code_hash,
    code_suffix,
    plan,
    expires_at
  ) values (
    encode(extensions.digest(raw_code, 'sha256'), 'hex'),
    right(raw_code, 4),
    requested_plan,
    expiration
  ) returning id into new_id;
  return query select new_id, raw_code, expiration;
end;
$$;

revoke all on function public.create_admin_invitation(text, interval) from public;
grant execute on function public.create_admin_invitation(text, interval) to service_role;
