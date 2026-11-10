-- Las calificaciones y comentarios deben sobrevivir a cualquier dispositivo.
create table if not exists public.workshop_feedback (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops(id) on delete cascade,
  client_id uuid not null references auth.users(id) on delete cascade,
  client_name text not null default 'Cliente',
  client_email text not null default '',
  mechanic_name text not null default 'Equipo del taller',
  service_type text not null default 'Servicio',
  rating integer not null check (rating between 1 and 5),
  comment text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists workshop_feedback_workshop_created_idx
  on public.workshop_feedback (workshop_id, created_at desc);

alter table public.workshop_feedback enable row level security;

create policy "workshop_feedback_select_client_or_staff"
on public.workshop_feedback for select to authenticated using (
  client_id = (select auth.uid())
  or private.can_manage_service(workshop_id)
);

create policy "workshop_feedback_insert_client"
on public.workshop_feedback for insert to authenticated with check (
  client_id = (select auth.uid())
  and private.is_active_workshop_client(workshop_id)
);
