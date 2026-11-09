import 'dart:typed_data';

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
  }) => _openFullScreenImage(
    context,
    image: Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Text(
        'No fue posible cargar esta imagen.',
        style: TextStyle(color: Colors.white),
      ),
    ),
    onDownload: (viewerContext) =>
        download(viewerContext, url: url, fileName: fileName),
  );

  static Future<void> openImageBytes(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
  }) => _openFullScreenImage(
    context,
    image: Image.memory(bytes, fit: BoxFit.contain),
    onDownload: (viewerContext) =>
        downloadBytes(viewerContext, bytes: bytes, fileName: fileName),
  );

  static Future<void> _openFullScreenImage(
    BuildContext context, {
    required Widget image,
    required Future<void> Function(BuildContext) onDownload,
  }) => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (viewerContext) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: .7,
                maxScale: 5,
                child: Center(child: image),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(viewerContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Guardar imagen',
                  onPressed: () => onDownload(viewerContext),
                  icon: const Icon(Icons.download_rounded),
                ),
              ),
            ],
          ),
        ),
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

  static Future<void> downloadBytes(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
  }) async {
    final extension = _extension(fileName);
    final name = extension.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - extension.length - 1);
    try {
      await FileSaver.instance.saveFile(
        name: name.isEmpty ? 'adjunto_chat' : name,
        bytes: bytes,
        fileExtension: extension,
        mimeType: _mimeType(extension),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen enviada a tus descargas.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible guardar la imagen.')),
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
