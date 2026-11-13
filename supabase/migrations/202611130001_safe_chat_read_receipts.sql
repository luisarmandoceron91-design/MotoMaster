-- Marcar mensajes como leídos sin conceder a clientes ni talleres permiso
-- para editar el contenido de mensajes ajenos. Esta RPC es segura para
-- conversaciones existentes y evita que el panel se bloquee por RLS.
create or replace function public.mark_conversation_read(target_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or not private.is_conversation_participant(target_conversation_id) then
    raise exception 'No tienes acceso a esta conversación';
  end if;

  update public.messages
     set read_at = now()
   where conversation_id = target_conversation_id
     and sender_id <> auth.uid()
     and read_at is null;
end;
$$;

revoke all on function public.mark_conversation_read(uuid) from public;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
