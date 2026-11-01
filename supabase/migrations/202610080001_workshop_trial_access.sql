-- Prueba de 3 días y acceso permanente controlado por el propietario.
alter table public.workshops
  add column if not exists access_status text not null default 'trial',
  add column if not exists trial_started_at timestamptz not null default now(),
  add column if not exists trial_ends_at timestamptz not null default (now() + interval '3 days'),
  add column if not exists permanent_access boolean not null default false,
  add column if not exists payment_status text not null default 'not_required',
  add column if not exists activated_at timestamptz,
  add column if not exists suspended_at timestamptz,
  add column if not exists access_note text not null default '';

alter table public.workshops
  drop constraint if exists workshops_access_status_check;
alter table public.workshops
  add constraint workshops_access_status_check
  check (access_status in ('trial', 'active', 'expired', 'suspended'));

alter table public.workshops
  drop constraint if exists workshops_payment_status_check;
alter table public.workshops
  add constraint workshops_payment_status_check
  check (payment_status in ('not_required', 'pending', 'paid', 'failed', 'refunded'));

-- Política adicional: el registro abierto crea únicamente un taller en prueba.
drop policy if exists "workshops_insert_trial_creator" on public.workshops;
create policy "workshops_insert_trial_creator" on public.workshops
for insert to authenticated with check (
  created_by = (select auth.uid())
  and access_status = 'trial'
  and permanent_access = false
);

create or replace function public.owner_set_workshop_access(
  target_workshop_id uuid,
  new_access_status text,
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
  if new_access_status not in ('trial', 'active', 'expired', 'suspended') then
    raise exception 'Estado de acceso no válido';
  end if;
  if length(trim(change_reason)) < 3 then
    raise exception 'El motivo es obligatorio';
  end if;

  update public.workshops
  set access_status = new_access_status,
      permanent_access = new_access_status = 'active',
      payment_status = case
        when new_access_status = 'active' then 'paid'
        else payment_status
      end,
      activated_at = case
        when new_access_status = 'active' then now()
        else activated_at
      end,
      suspended_at = case
        when new_access_status = 'suspended' then now()
        else null
      end,
      access_note = trim(change_reason),
      updated_at = now()
  where id = target_workshop_id;

  if not found then raise exception 'Taller no encontrado'; end if;

  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()),
    'workshop_access_changed',
    'workshop',
    target_workshop_id,
    jsonb_build_object('access_status', new_access_status, 'reason', trim(change_reason))
  );
end;
$$;

revoke all on function public.owner_set_workshop_access(uuid, text, text) from public;
grant execute on function public.owner_set_workshop_access(uuid, text, text) to authenticated;

create or replace function private.workshop_has_access(target_workshop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.workshops workshop
    where workshop.id = target_workshop_id
      and workshop.status = 'active'
      and (
        workshop.permanent_access
        or workshop.access_status = 'active'
        or (
          workshop.access_status = 'trial'
          and now() < workshop.trial_ends_at
        )
      )
  );
$$;

grant execute on function private.workshop_has_access(uuid) to authenticated;
