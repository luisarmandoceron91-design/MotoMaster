-- Adjuntos de conversaciones: sin límite específico de bucket para documentos
-- técnicos, cotizaciones y manuales pesados. El acceso sigue privado entre
-- participantes; cualquier límite físico del proveedor sigue aplicando.
update storage.buckets
set file_size_limit = null
where id = 'chat-attachments';
