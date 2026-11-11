-- Fuente compartida de mecánicos y actualizaciones en tiempo real para el
-- chat. Ningún dispositivo depende de su almacenamiento local.
create table if not exists public.workshop_mechanics (
  id text primary key,
  workshop_id uuid not null references public.workshops(id) on delete cascade,
  name text not null,
  specialty text not null default 'Mecánica general',
  phone text not null default '',
  bio text not null default '',
  experience_years integer not null default 0 check (experience_years >= 0),
  photo_base64 text,
  available boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists workshop_mechanics_workshop_idx
  on public.workshop_mechanics(workshop_id, active, name);

alter table public.workshop_mechanics enable row level security;

drop policy if exists "workshop_mechanics_select_scoped" on public.workshop_mechanics;
create policy "workshop_mechanics_select_scoped" on public.workshop_mechanics
for select to authenticated using (
  private.is_workshop_member(workshop_id)
  or private.is_active_workshop_client(workshop_id)
);

drop policy if exists "workshop_mechanics_manage_staff" on public.workshop_mechanics;
create policy "workshop_mechanics_manage_staff" on public.workshop_mechanics
for all to authenticated using (private.is_workshop_member(workshop_id))
with check (private.is_workshop_member(workshop_id));

revoke all on public.workshop_mechanics from anon;
grant select, insert, update, delete on public.workshop_mechanics to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.conversations;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.workshop_mechanics;
exception when duplicate_object then null;
end $$;
