import 'dart:async';

import 'package:flutter/material.dart';

/// Aviso uniforme cuando el propietario desactiva un taller desde el centro
/// de control. No elimina información: únicamente avisa y permite cerrar la
/// sesión de forma segura al terminar la cuenta regresiva.
Future<bool> showWorkshopDeactivationNotice(
  BuildContext context, {
  String supportEmail = 'luisarmandoceron91@gmail.com',
  String supportPhone = '',
  Future<bool> Function()? isStillDeactivated,
}) async {
  var secondsRemaining = 30;
  Timer? timer;
  var checkingAvailability = false;

  final finished = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        timer ??= Timer.periodic(const Duration(seconds: 1), (activeTimer) {
          if (!dialogContext.mounted) {
            activeTimer.cancel();
            return;
          }
          if (secondsRemaining <= 1) {
            activeTimer.cancel();
            Navigator.of(dialogContext).pop(true);
            return;
          }
          if (isStillDeactivated != null &&
              secondsRemaining % 3 == 0 &&
              !checkingAvailability) {
            checkingAvailability = true;
            () async {
              try {
                final stillDeactivated = await isStillDeactivated();
                if (!stillDeactivated && dialogContext.mounted) {
                  activeTimer.cancel();
                  Navigator.of(dialogContext).pop(false);
                }
              } catch (_) {
                // Si la red falla, el aviso sigue hasta poder comprobarlo.
              } finally {
                checkingAvailability = false;
              }
            }();
          }
          setDialogState(() => secondsRemaining--);
        });

        return PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.block_rounded, color: Color(0xFFFF6500)),
            title: const Text('Taller desactivado'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Este taller fue desactivado por el desarrollador del software. '
                    'Toda la información permanece guardada y protegida.',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Comunícate con el desarrollador del software:',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text('Correo: $supportEmail'),
                  if (supportPhone.trim().isNotEmpty)
                    Text('Teléfono: ${supportPhone.trim()}'),
                  const SizedBox(height: 18),
                  Text(
                    'La sesión se cerrará de forma segura en $secondsRemaining segundo${secondsRemaining == 1 ? '' : 's'}.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  timer?.cancel();
  return finished == true;
}
