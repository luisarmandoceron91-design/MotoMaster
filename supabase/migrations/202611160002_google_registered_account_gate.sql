-- OAuth crea un usuario de Auth antes de mostrar el formulario. Separar el
-- perfil técnico inicial de una cuenta terminada evita que un correo nuevo de
-- Google entre como cliente sin haber completado su registro.
alter table public.profiles
  add column if not exists registration_status text not null default 'registered'
    check (registration_status in ('pending', 'registered'));

-- Los perfiles que ya existían corresponden a cuentas creadas antes de este
-- control y se preservan como cuentas registradas.
alter table public.profiles alter column registration_status set default 'pending';

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (
    user_id, full_name, email, phone, department, city, registration_status
  ) values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'department', ''),
    coalesce(new.raw_user_meta_data ->> 'city', ''),
    case when new.raw_user_meta_data ->> 'account_type' in ('client', 'admin')
      then 'registered' else 'pending' end
  ) on conflict (user_id) do nothing;
  return new;
end;
$$;
