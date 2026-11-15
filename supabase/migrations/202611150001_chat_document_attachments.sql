-- Los chats admiten fotos y documentos compartidos entre cliente y taller.
-- Antes el bucket sólo aceptaba PDF, por lo que Word fallaba aunque el
-- selector mostrara .doc y .docx como opciones válidas.
update storage.buckets
set
  file_size_limit = 26214400,
  allowed_mime_types = array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
where id = 'chat-attachments';
