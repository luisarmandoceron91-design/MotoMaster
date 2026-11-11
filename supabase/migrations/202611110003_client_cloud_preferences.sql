-- Preferencias personales que antes vivían solo en el dispositivo.
-- El historial de talleres se conserva por cliente y se comparte entre
-- celular, computador y tablet sin exponer datos de otras cuentas.
create table if not exists public.client_workshop_preferences (
  client_id uuid not null references auth.users(id) on delete cascade,
  workshop_id uuid not null references public.workshops(id) on delete cascade,
  hidden boolean not null default false,
  last_opened_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (client_id, workshop_id)
);

create index if not exists client_workshop_preferences_history_idx
  on public.client_workshop_preferences(client_id, hidden, last_opened_at desc);

alter table public.client_workshop_preferences enable row level security;

drop policy if exists "client_workshop_preferences_own" on public.client_workshop_preferences;
create policy "client_workshop_preferences_own"
on public.client_workshop_preferences for all to authenticated
using (client_id = (select auth.uid()))
with check (client_id = (select auth.uid()));

grant select, insert, update, delete on public.client_workshop_preferences to authenticated;

drop trigger if exists set_client_workshop_preferences_updated_at
  on public.client_workshop_preferences;
create trigger set_client_workshop_preferences_updated_at
before update on public.client_workshop_preferences
for each row execute procedure public.set_updated_at();
