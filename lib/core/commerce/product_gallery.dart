import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Galería reutilizable para que tanto el administrador como el cliente vean
/// sin recortes las cuatro fotografías publicadas de un mismo producto.
Future<void> showProductGallery(
  BuildContext context, {
  required List<Uint8List> photos,
  required Color accent,
  int initialPage = 0,
}) async {
  if (photos.isEmpty) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ProductGalleryPage(
        photos: photos.take(4).toList(growable: false),
        accent: accent,
        initialPage: initialPage.clamp(0, photos.length - 1),
      ),
    ),
  );
}

class _ProductGalleryPage extends StatefulWidget {
  const _ProductGalleryPage({
    required this.photos,
    required this.accent,
    required this.initialPage,
  });

  final List<Uint8List> photos;
  final Color accent;
  final int initialPage;

  @override
  State<_ProductGalleryPage> createState() => _ProductGalleryPageState();
}

class _ProductGalleryPageState extends State<_ProductGalleryPage> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
  );
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (_, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.memory(
                  widget.photos[index],
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: IconButton.filled(
              tooltip: 'Cerrar galería',
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(backgroundColor: const Color(0xCC20242A)),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              right: 18,
              bottom: 26,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xD9000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.accent.withValues(alpha: .7)),
                ),
                child: Text('${_page + 1} / ${widget.photos.length}'),
              ),
            ),
        ],
      ),
    ),
  );
}
