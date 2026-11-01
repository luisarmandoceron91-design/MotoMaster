-- Aislamiento multi-tenant y privilegios minimos.
-- La interfaz nunca se considera una frontera de seguridad.

create or replace function private.workshop_has_access(target_workshop_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.workshops w
    where w.id = target_workshop_id and w.status = 'active'
      and (w.permanent_access or w.access_status = 'active'
        or (w.access_status = 'trial' and now() < w.trial_ends_at))
  );
$$;

create or replace function private.is_workshop_member(target_workshop_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.workshop_has_access(target_workshop_id) and exists (
    select 1 from public.workshop_members wm
    where wm.workshop_id = target_workshop_id
      and wm.user_id = (select auth.uid()) and wm.status = 'active'
  );
$$;

create or replace function private.is_workshop_owner(target_workshop_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.workshop_has_access(target_workshop_id) and exists (
    select 1 from public.workshop_members wm
    where wm.workshop_id = target_workshop_id
      and wm.user_id = (select auth.uid()) and wm.status = 'active'
      and wm.role = 'owner'
  );
$$;

create or replace function private.can_manage_workshop(target_workshop_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.workshop_has_access(target_workshop_id) and exists (
    select 1 from public.workshop_members wm
    where wm.workshop_id = target_workshop_id
      and wm.user_id = (select auth.uid()) and wm.status = 'active'
      and wm.role in ('owner', 'admin')
  );
$$;

create or replace function private.can_manage_service(target_workshop_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.workshop_has_access(target_workshop_id) and exists (
    select 1 from public.workshop_members wm
    where wm.workshop_id = target_workshop_id
      and wm.user_id = (select auth.uid()) and wm.status = 'active'
      and wm.role in ('owner', 'admin', 'receptionist', 'technician')
  );
$$;

create or replace function private.can_manage_inventory(target_workshop_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.workshop_has_access(target_workshop_id) and exists (
    select 1 from public.workshop_members wm
    where wm.workshop_id = target_workshop_id
      and wm.user_id = (select auth.uid()) and wm.status = 'active'
      and wm.role in ('owner', 'admin', 'inventory')
  );
$$;

create or replace function private.is_active_workshop_client(
  target_workshop_id uuid, target_client_id uuid default auth.uid()
)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.workshop_has_access(target_workshop_id) and exists (
    select 1 from public.client_workshops cw
    where cw.workshop_id = target_workshop_id
      and cw.client_id = target_client_id and cw.status = 'active'
  );
$$;

create or replace function private.is_conversation_participant(target_conversation_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversations c
    where c.id = target_conversation_id
      and (c.client_id = (select auth.uid()) or private.is_workshop_member(c.workshop_id))
  );
$$;

create or replace function private.has_mfa()
returns boolean language sql stable set search_path = '' as $$
  select coalesce((select auth.jwt()) ->> 'aal', 'aal1') = 'aal2';
$$;

revoke all on function private.is_workshop_owner(uuid) from public, anon;
revoke all on function private.can_manage_service(uuid) from public, anon;
revoke all on function private.can_manage_inventory(uuid) from public, anon;
revoke all on function private.is_active_workshop_client(uuid, uuid) from public, anon;
revoke all on function private.has_mfa() from public, anon;
grant execute on function private.is_workshop_owner(uuid) to authenticated;
grant execute on function private.can_manage_service(uuid) to authenticated;
grant execute on function private.can_manage_inventory(uuid) to authenticated;
grant execute on function private.is_active_workshop_client(uuid, uuid) to authenticated;
grant execute on function private.has_mfa() to authenticated;

-- El directorio expone solo campos publicos y oculta talleres vencidos.
create or replace function public.list_active_workshops()
returns table (
  id uuid, name text, slug text, tagline text, logo_path text,
  accent_color bigint, status text, department text, municipality text,
  neighborhood text, address text, opening_hours jsonb,
  rating numeric, review_count integer
)
language sql stable security definer set search_path = '' as $$
  select w.id, w.name, w.slug, w.tagline, w.logo_path, w.accent_color,
    w.status, w.department, w.municipality, w.neighborhood, w.address,
    w.opening_hours, w.rating, w.review_count
  from public.workshops w
  where private.workshop_has_access(w.id)
  order by w.name;
$$;

create unique index if not exists workshops_created_by_unique
  on public.workshops (created_by);

drop policy if exists "workshops_select_active_or_member" on public.workshops;
drop policy if exists "workshops_insert_authorized_owner" on public.workshops;
drop policy if exists "workshops_insert_trial_creator" on public.workshops;
drop policy if exists "workshops_update_managers" on public.workshops;
drop policy if exists "platform_owner_update_workshops" on public.workshops;
drop policy if exists "platform_owner_read_workshops" on public.workshops;
create policy "workshops_select_scoped" on public.workshops
for select to authenticated using (
  created_by = (select auth.uid())
  or exists (
    select 1 from public.workshop_members wm
    where wm.workshop_id = workshops.id and wm.user_id = (select auth.uid())
  )
  or (private.is_platform_owner() and private.has_mfa())
);
create policy "workshops_insert_single_trial" on public.workshops
for insert to authenticated with check (
  created_by = (select auth.uid()) and access_status = 'trial'
  and permanent_access = false
  and not exists (
    select 1 from public.workshops existing
    where existing.created_by = (select auth.uid())
  )
);
create policy "workshops_update_active_managers" on public.workshops
for update to authenticated using (private.can_manage_workshop(id))
with check (private.can_manage_workshop(id));

-- El propietario no obtiene acceso general a datos personales.
drop policy if exists "platform_owner_read_profiles" on public.profiles;
drop policy if exists "platform_owner_read_members" on public.workshop_members;
drop policy if exists "platform_owner_read_audit" on public.platform_audit_log;
create policy "platform_owner_read_workshops_mfa" on public.workshops
for select to authenticated using (private.is_platform_owner() and private.has_mfa());
create policy "platform_owner_read_members_mfa" on public.workshop_members
for select to authenticated using (private.is_platform_owner() and private.has_mfa());
create policy "platform_owner_read_audit_mfa" on public.platform_audit_log
for select to authenticated using (private.is_platform_owner() and private.has_mfa());

drop policy if exists "members_select_self_or_managers" on public.workshop_members;
drop policy if exists "members_insert_creator_or_managers" on public.workshop_members;
drop policy if exists "members_update_managers" on public.workshop_members;
drop policy if exists "members_delete_managers" on public.workshop_members;
create policy "members_select_scoped" on public.workshop_members
for select to authenticated using (
  user_id = (select auth.uid()) or private.can_manage_workshop(workshop_id)
  or (private.is_platform_owner() and private.has_mfa())
);
create policy "members_insert_owner_controlled" on public.workshop_members
for insert to authenticated with check (
  (
    user_id = (select auth.uid()) and role = 'owner' and status = 'active'
    and exists (
      select 1 from public.workshops w
      where w.id = workshop_id and w.created_by = (select auth.uid())
    )
  )
  or (private.is_workshop_owner(workshop_id) and role <> 'owner')
);
create policy "members_update_owner_only" on public.workshop_members
for update to authenticated using (private.is_workshop_owner(workshop_id))
with check (private.is_workshop_owner(workshop_id));
create policy "members_delete_owner_only" on public.workshop_members
for delete to authenticated using (private.is_workshop_owner(workshop_id));

create or replace function private.protect_last_workshop_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.role = 'owner' and old.status = 'active'
     and (tg_op = 'DELETE' or new.role <> 'owner' or new.status <> 'active')
     and not exists (
       select 1 from public.workshop_members other_owner
       where other_owner.workshop_id = old.workshop_id
         and other_owner.user_id <> old.user_id
         and other_owner.role = 'owner' and other_owner.status = 'active'
     ) then
    raise exception 'El taller debe conservar al menos un propietario activo';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
drop trigger if exists protect_last_workshop_owner on public.workshop_members;
create trigger protect_last_workshop_owner
before update or delete on public.workshop_members
for each row execute function private.protect_last_workshop_owner();

drop policy if exists "client_workshops_select_participants" on public.client_workshops;
drop policy if exists "client_workshops_join_self" on public.client_workshops;
drop policy if exists "client_workshops_update_participants" on public.client_workshops;
create policy "client_workshops_select_scoped" on public.client_workshops
for select to authenticated using (
  client_id = (select auth.uid()) or private.can_manage_service(workshop_id)
);
create policy "client_workshops_join_self_active" on public.client_workshops
for insert to authenticated with check (
  (client_id = (select auth.uid()) and status = 'active'
    and private.workshop_has_access(workshop_id))
  or private.can_manage_service(workshop_id)
);
create policy "client_workshops_update_staff_only" on public.client_workshops
for update to authenticated using (private.can_manage_service(workshop_id))
with check (private.can_manage_service(workshop_id));

drop policy if exists "motorcycles_select_owner_or_staff" on public.motorcycles;
drop policy if exists "motorcycles_insert_owner_or_staff" on public.motorcycles;
drop policy if exists "motorcycles_update_owner_or_staff" on public.motorcycles;
create policy "motorcycles_select_scoped" on public.motorcycles
for select to authenticated using (
  owner_id = (select auth.uid()) or private.can_manage_service(workshop_id)
);
create policy "motorcycles_insert_scoped" on public.motorcycles
for insert to authenticated with check (
  (owner_id = (select auth.uid()) and
    (workshop_id is null or private.is_active_workshop_client(workshop_id)))
  or (private.can_manage_service(workshop_id)
    and private.is_active_workshop_client(workshop_id, owner_id))
);
create policy "motorcycles_update_scoped" on public.motorcycles
for update to authenticated using (
  owner_id = (select auth.uid()) or private.can_manage_service(workshop_id)
)
with check (
  (owner_id = (select auth.uid()) and
    (workshop_id is null or private.is_active_workshop_client(workshop_id)))
  or (private.can_manage_service(workshop_id)
    and private.is_active_workshop_client(workshop_id, owner_id))
);

drop policy if exists "products_select_active_or_staff" on public.products;
drop policy if exists "products_manage_staff" on public.products;
create policy "products_select_scoped" on public.products
for select to authenticated using (
  private.is_workshop_member(workshop_id)
  or (is_active and private.is_active_workshop_client(workshop_id))
);
create policy "products_insert_inventory" on public.products
for insert to authenticated with check (private.can_manage_inventory(workshop_id));
create policy "products_update_inventory" on public.products
for update to authenticated using (private.can_manage_inventory(workshop_id))
with check (private.can_manage_inventory(workshop_id));
create policy "products_delete_inventory" on public.products
for delete to authenticated using (private.can_manage_inventory(workshop_id));

drop policy if exists "appointments_select_participants" on public.appointments;
drop policy if exists "appointments_insert_participants" on public.appointments;
drop policy if exists "appointments_update_participants" on public.appointments;
create policy "appointments_select_scoped" on public.appointments
for select to authenticated using (
  client_id = (select auth.uid()) or private.can_manage_service(workshop_id)
);
create policy "appointments_insert_scoped" on public.appointments
for insert to authenticated with check (
  (client_id = (select auth.uid()) and status = 'requested'
    and private.is_active_workshop_client(workshop_id))
  or (private.can_manage_service(workshop_id)
    and private.is_active_workshop_client(workshop_id, client_id))
);
create policy "appointments_update_staff" on public.appointments
for update to authenticated using (private.can_manage_service(workshop_id))
with check (private.can_manage_service(workshop_id));

drop policy if exists "work_orders_select_participants" on public.work_orders;
drop policy if exists "work_orders_manage_staff" on public.work_orders;
create policy "work_orders_select_scoped" on public.work_orders
for select to authenticated using (
  client_id = (select auth.uid()) or private.can_manage_service(workshop_id)
);
create policy "work_orders_insert_staff" on public.work_orders
for insert to authenticated with check (
  private.can_manage_service(workshop_id)
  and private.is_active_workshop_client(workshop_id, client_id)
);
create policy "work_orders_update_staff" on public.work_orders
for update to authenticated using (private.can_manage_service(workshop_id))
with check (private.can_manage_service(workshop_id));
create policy "work_orders_delete_managers" on public.work_orders
for delete to authenticated using (private.can_manage_workshop(workshop_id));

drop policy if exists "conversations_select_participants" on public.conversations;
drop policy if exists "conversations_insert_participants" on public.conversations;
drop policy if exists "conversations_update_participants" on public.conversations;
create policy "conversations_select_scoped" on public.conversations
for select to authenticated using (
  client_id = (select auth.uid()) or private.is_workshop_member(workshop_id)
);
create policy "conversations_insert_scoped" on public.conversations
for insert to authenticated with check (
  (client_id = (select auth.uid()) and private.is_active_workshop_client(workshop_id))
  or (private.can_manage_service(workshop_id)
    and private.is_active_workshop_client(workshop_id, client_id))
);
create policy "conversations_update_staff" on public.conversations
for update to authenticated using (private.can_manage_service(workshop_id))
with check (private.can_manage_service(workshop_id));

drop policy if exists "messages_select_participants" on public.messages;
drop policy if exists "messages_insert_sender" on public.messages;
drop policy if exists "messages_update_participants" on public.messages;
create policy "messages_select_scoped" on public.messages
for select to authenticated using (private.is_conversation_participant(conversation_id));
create policy "messages_insert_sender_only" on public.messages
for insert to authenticated with check (
  sender_id = (select auth.uid())
  and private.is_conversation_participant(conversation_id)
);

create or replace function private.touch_conversation_from_message()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;
drop trigger if exists touch_conversation_from_message on public.messages;
create trigger touch_conversation_from_message
after insert on public.messages
for each row execute function private.touch_conversation_from_message();

-- Un UPDATE de Storage no puede cambiar la ruta para escapar del tenant.
drop policy if exists "profile_photos_update_own" on storage.objects;
create policy "profile_photos_update_own" on storage.objects
for update to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "workshop_assets_update_staff" on storage.objects;
drop policy if exists "workshop_assets_write_staff" on storage.objects;
create policy "workshop_assets_write_managers" on storage.objects
for insert to authenticated with check (
  bucket_id = 'workshop-assets'
  and private.can_manage_workshop(((storage.foldername(name))[1])::uuid)
);
create policy "workshop_assets_update_staff" on storage.objects
for update to authenticated
using (
  bucket_id = 'workshop-assets'
  and private.can_manage_workshop(((storage.foldername(name))[1])::uuid)
)
with check (
  bucket_id = 'workshop-assets'
  and private.can_manage_workshop(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "product_images_update_staff" on storage.objects;
drop policy if exists "product_images_write_staff" on storage.objects;
create policy "product_images_write_inventory" on storage.objects
for insert to authenticated with check (
  bucket_id = 'product-images'
  and private.can_manage_inventory(((storage.foldername(name))[1])::uuid)
);
create policy "product_images_update_staff" on storage.objects
for update to authenticated
using (
  bucket_id = 'product-images'
  and private.can_manage_inventory(((storage.foldername(name))[1])::uuid)
)
with check (
  bucket_id = 'product-images'
  and private.can_manage_inventory(((storage.foldername(name))[1])::uuid)
);

update storage.buckets
set allowed_mime_types = array[
  'image/jpeg', 'image/png', 'image/webp', 'application/pdf'
]
where id = 'chat-attachments';

drop policy if exists "chat_attachments_write_participants" on storage.objects;
create policy "chat_attachments_write_participants" on storage.objects
for insert to authenticated with check (
  bucket_id = 'chat-attachments'
  and owner_id = (select auth.uid())::text
  and private.is_conversation_participant(
    ((storage.foldername(name))[1])::uuid
  )
);

-- Grants minimos: RLS sigue validando cada fila.
revoke all on table public.profiles, public.workshops, public.workshop_members,
  public.client_workshops, public.motorcycles, public.products,
  public.appointments, public.work_orders, public.conversations,
  public.messages, public.platform_audit_log from anon;
revoke all on table public.profiles, public.workshops, public.workshop_members,
  public.client_workshops, public.motorcycles, public.products,
  public.appointments, public.work_orders, public.conversations,
  public.messages, public.platform_audit_log from authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.workshops to authenticated;
grant select, insert, update, delete on public.workshop_members to authenticated;
grant select, insert, update on public.client_workshops to authenticated;
grant select, insert, update on public.motorcycles to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update on public.appointments to authenticated;
grant select, insert, update, delete on public.work_orders to authenticated;
grant select, insert, update on public.conversations to authenticated;
grant select, insert on public.messages to authenticated;
grant select on public.platform_audit_log to authenticated;

-- Acciones propietarias: MFA obligatorio, motivo y auditoria inmutable.
create or replace function public.owner_set_workshop_status(
  target_workshop_id uuid, new_status text, change_reason text
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if new_status not in ('active', 'inactive', 'suspended') then
    raise exception 'Estado de taller no valido';
  end if;
  if length(trim(change_reason)) < 3 then
    raise exception 'El motivo es obligatorio';
  end if;
  update public.workshops set status = new_status, updated_at = now()
  where id = target_workshop_id;
  if not found then raise exception 'Taller no encontrado'; end if;
  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()), 'workshop_status_changed', 'workshop',
    target_workshop_id,
    jsonb_build_object('status', new_status, 'reason', trim(change_reason))
  );
end;
$$;

create or replace function public.owner_set_workshop_access(
  target_workshop_id uuid, new_access_status text, change_reason text
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_platform_owner() or not private.has_mfa() then
    raise exception 'Se requiere una sesion de propietario con verificacion en dos pasos';
  end if;
  if new_access_status not in ('trial', 'active', 'expired', 'suspended') then
    raise exception 'Estado de acceso no valido';
  end if;
  if length(trim(change_reason)) < 3 then
    raise exception 'El motivo es obligatorio';
  end if;
  update public.workshops
  set access_status = new_access_status,
      permanent_access = new_access_status = 'active',
      payment_status = case
        when new_access_status = 'active' then 'paid' else payment_status end,
      activated_at = case
        when new_access_status = 'active' then now() else activated_at end,
      suspended_at = case
        when new_access_status = 'suspended' then now() else null end,
      access_note = trim(change_reason), updated_at = now()
  where id = target_workshop_id;
  if not found then raise exception 'Taller no encontrado'; end if;
  insert into public.platform_audit_log (
    actor_id, action, entity_type, entity_id, detail
  ) values (
    (select auth.uid()), 'workshop_access_changed', 'workshop',
    target_workshop_id,
    jsonb_build_object(
      'access_status', new_access_status, 'reason', trim(change_reason)
    )
  );
end;
$$;

revoke all on function public.owner_set_workshop_status(uuid, text, text)
from public, anon;
revoke all on function public.owner_set_workshop_access(uuid, text, text)
from public, anon;
grant execute on function public.owner_set_workshop_status(uuid, text, text)
to authenticated;
grant execute on function public.owner_set_workshop_access(uuid, text, text)
to authenticated;

-- Las antiguas invitaciones no conceden por si solas acceso a datos.
create or replace function public.resolve_admin_access()
returns text language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then return null; end if;
  if private.is_platform_owner() then return 'platform_owner'; end if;
  if exists (
    select 1 from public.workshop_members wm
    where wm.user_id = auth.uid() and wm.status = 'active'
      and wm.role in ('owner', 'admin', 'receptionist', 'technician', 'inventory')
      and private.workshop_has_access(wm.workshop_id)
  ) then
    return 'workshop_staff';
  end if;
  return null;
end;
$$;
