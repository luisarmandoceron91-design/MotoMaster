create table if not exists public.platform_settings (
  setting_key text primary key,
  setting_value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

insert into public.platform_settings (setting_key, setting_value)
values (
  'developer_support_contact',
  '{"email":"luisarmandoceron91@gmail.com","phone":"3207539325"}'::jsonb
)
on conflict (setting_key) do nothing;

alter table public.platform_settings enable row level security;

create or replace function public.get_developer_support_contact()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select setting_value
  from public.platform_settings
  where setting_key = 'developer_support_contact';
$$;

create or replace function public.owner_update_developer_support_contact(
  new_email text,
  new_phone text
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
  if position('@' in trim(new_email)) = 0 then
    raise exception 'Correo de soporte no válido';
  end if;
  if length(regexp_replace(new_phone, '[^0-9]', '', 'g')) < 7 then
    raise exception 'Teléfono de soporte no válido';
  end if;
  insert into public.platform_settings (
    setting_key, setting_value, updated_at, updated_by
  ) values (
    'developer_support_contact',
    jsonb_build_object('email', trim(lower(new_email)), 'phone', trim(new_phone)),
    now(), auth.uid()
  ) on conflict (setting_key) do update set
    setting_value = excluded.setting_value,
    updated_at = excluded.updated_at,
    updated_by = excluded.updated_by;
end;
$$;

revoke all on function public.get_developer_support_contact() from public;
grant execute on function public.get_developer_support_contact() to anon, authenticated;
revoke all on function public.owner_update_developer_support_contact(text, text) from public, anon;
grant execute on function public.owner_update_developer_support_contact(text, text) to authenticated;
