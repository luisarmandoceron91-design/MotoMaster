-- Cada cliente puede activar o quitar un taller de su propia lista.
-- El aislamiento sigue ligado a auth.uid(); nunca puede editar otra cuenta.
drop policy if exists "client_workshops_update_staff_only" on public.client_workshops;
drop policy if exists "client_workshops_update_self_or_staff" on public.client_workshops;
create policy "client_workshops_update_self_or_staff" on public.client_workshops
for update to authenticated
using (
  client_id = (select auth.uid())
  or private.can_manage_service(workshop_id)
)
with check (
  (
    client_id = (select auth.uid())
    and status in ('active', 'inactive')
    and private.workshop_has_access(workshop_id)
  )
  or private.can_manage_service(workshop_id)
);
