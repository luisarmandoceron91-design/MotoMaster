import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_master/core/chat/local_chat_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'crea saludo automático con el nombre del taller una sola vez',
    () async {
      final store = LocalChatStore();

      await store.sendClientMessage(
        workshopId: 'motos-jose',
        workshopName: 'Motos Jose',
        clientName: 'Diana Maritza',
        clientEmail: 'diana@cliente.com',
        body: 'Buenos días',
      );
      await store.sendClientMessage(
        workshopId: 'motos-jose',
        workshopName: 'Motos Jose',
        clientName: 'Diana Maritza',
        clientEmail: 'diana@cliente.com',
        body: 'Necesito una revisión',
      );

      final messages = await store.listMessages(
        workshopId: 'motos-jose',
        clientEmail: 'diana@cliente.com',
      );
      expect(
        messages.where((message) => message.sender == 'automatic'),
        hasLength(1),
      );
      expect(
        messages[1].body,
        '¡Hola! Bienvenido a Motos Jose, ¿en qué podemos ayudarte?',
      );
    },
  );

  test(
    'el administrador ve y responde solo conversaciones de su taller',
    () async {
      final store = LocalChatStore();
      await store.sendClientMessage(
        workshopId: 'motos-jose',
        workshopName: 'Motos Jose',
        clientName: 'Diana Maritza',
        clientEmail: 'diana@cliente.com',
        body: 'Hola',
      );
      await store.sendClientMessage(
        workshopId: 'moto-elite',
        workshopName: 'Moto Elite',
        clientName: 'Otro cliente',
        clientEmail: 'otro@cliente.com',
        body: 'Hola Elite',
      );

      final inbox = await store.listConversations('motos-jose');
      expect(inbox, hasLength(1));
      expect(inbox.single.clientName, 'Diana Maritza');

      await store.sendWorkshopMessage(
        workshopId: 'motos-jose',
        workshopName: 'Motos Jose',
        clientName: 'Diana Maritza',
        clientEmail: 'diana@cliente.com',
        body: 'Hola Diana, cuéntanos qué necesita tu moto.',
      );
      final messages = await store.listMessages(
        workshopId: 'motos-jose',
        clientEmail: 'diana@cliente.com',
      );
      expect(messages.last.sentByWorkshop, isTrue);
    },
  );
}
