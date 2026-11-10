-- Cada participante puede retirar únicamente sus propios mensajes.
-- Al desaparecer el mensaje, el cliente elimina también su archivo adjunto.
drop policy if exists "messages_delete_sender_only" on public.messages;
create policy "messages_delete_sender_only" on public.messages
for delete to authenticated using (sender_id = (select auth.uid()));
