import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

/// Acciones comunes para los adjuntos del chat, tanto para clientes como para
/// administradores. Las URL recibidas son temporales y firmadas por Supabase.
class ChatAttachmentActions {
  const ChatAttachmentActions._();

  static Future<void> openImage(
    BuildContext context, {
    required String url,
    required String fileName,
  }) => showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: .7,
            maxScale: 5,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text(
                  'No fue posible cargar esta imagen.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 12,
            child: IconButton.filledTonal(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          Positioned(
            top: 16,
            right: 12,
            child: IconButton.filledTonal(
              tooltip: 'Guardar imagen',
              onPressed: () =>
                  download(dialogContext, url: url, fileName: fileName),
              icon: const Icon(Icons.download_rounded),
            ),
          ),
        ],
      ),
    ),
  );

  static Future<void> download(
    BuildContext context, {
    required String url,
    required String fileName,
  }) async {
    final extension = _extension(fileName);
    final name = extension.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - extension.length - 1);
    try {
      await FileSaver.instance.saveFile(
        name: name.isEmpty ? 'adjunto_chat' : name,
        link: LinkDetails(link: url),
        fileExtension: extension,
        mimeType: _mimeType(extension),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo enviado a tus descargas.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible descargar el archivo.')),
        );
      }
    }
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static MimeType _mimeType(String extension) => switch (extension) {
    'jpg' || 'jpeg' => MimeType.jpeg,
    'png' => MimeType.png,
    'webp' => MimeType.webp,
    'gif' => MimeType.gif,
    'pdf' => MimeType.pdf,
    'doc' || 'docx' => MimeType.microsoftWord,
    _ => MimeType.other,
  };
}
