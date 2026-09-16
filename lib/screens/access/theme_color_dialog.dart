import 'package:flutter/material.dart';

import '../../core/branding/workshop_brand.dart';

class ThemeColorDialog extends StatefulWidget {
  const ThemeColorDialog({
    super.key,
    required this.brand,
    required this.onSave,
  });

  final WorkshopBrand brand;
  final Future<void> Function(int) onSave;

  @override
  State<ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<ThemeColorDialog> {
  static const _colors = [
    0xFFFF6200,
    0xFF00B8D9,
    0xFF8E5BFF,
    0xFF20C77A,
    0xFFE83E8C,
  ];
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _colorValue = widget.brand.accentColorValue;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(_colorValue);
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1B1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Color de la aplicación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personaliza tu experiencia eligiendo un color. El nombre y el logo del taller los administra el propietario.',
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final colorValue in _colors)
                InkWell(
                  onTap: () => setState(() => _colorValue = colorValue),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Color(colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorValue == colorValue
                            ? Colors.white
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: _colorValue == colorValue
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.onSave(_colorValue);
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: const Text('Aplicar color'),
        ),
      ],
    );
  }
}
