-- Vincula la cuenta de Google autorizada del desarrollador al Centro de
-- control. La condición se limita al correo indicado y no concede acceso a
-- ningún otro usuario.
insert into public.platform_owners (user_id, status)
select id, 'active'
from auth.users
where lower(email) = 'luisarmandoceron91@gmail.com'
on conflict (user_id) do update set status = 'active';
