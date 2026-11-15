-- Todo chat nuevo comienza con la bienvenida oficial del taller. Se genera en
-- la base de datos para que no dependa del celular donde se abrió el chat.
create or replace function private.create_conversation_welcome()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  sender uuid;
  workshop_name text;
begin
  select wm.user_id into sender
  from public.workshop_members wm
  where wm.workshop_id = new.workshop_id and wm.status = 'active'
  order by wm.created_at asc
  limit 1;
  if sender is null then return new; end if;
  select name into workshop_name from public.workshops where id = new.workshop_id;
  insert into public.messages (conversation_id, sender_id, body)
  values (
    new.id,
    sender,
    '¡Hola! Bienvenido a ' || coalesce(nullif(trim(workshop_name), ''), 'nuestro taller') ||
      ', ¿en qué podemos ayudarte?'
  );
  return new;
end;
$$;

drop trigger if exists conversations_create_welcome on public.conversations;
create trigger conversations_create_welcome
after insert on public.conversations
for each row execute function private.create_conversation_welcome();
