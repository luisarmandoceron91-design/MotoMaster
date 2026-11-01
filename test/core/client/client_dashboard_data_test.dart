import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_master/core/client/client_service_store.dart';
import 'package:moto_master/core/workshops/workshop_feedback_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps motorcycles and appointments scoped to client and workshop', () async {
    final store = ClientServiceStore();
    const motorcycle = ClientMotorcycle(
      id: 'moto-1',
      brand: 'Honda',
      model: 'CBR 600',
      plate: 'ABC123',
      year: '2024',
      color: 'Negro',
    );
    await store.saveMotorcycle('workshop-1', 'client-1', motorcycle);
    await store.saveAppointment(
      'workshop-1',
      'client-1',
      ClientAppointment(
        id: 'appointment-1',
        motorcycleId: motorcycle.id,
        motorcycleName: motorcycle.displayName,
        serviceType: 'Mantenimiento',
        date: DateTime(2026, 10, 21),
        time: '08:00',
        notes: 'Cambio de aceite',
      ),
    );

    expect(await store.listMotorcycles('workshop-1', 'client-1'), hasLength(1));
    expect(await store.listAppointments('workshop-1', 'client-1'), hasLength(1));
    expect(await store.listMotorcycles('workshop-2', 'client-1'), isEmpty);
  });

  test('delivers feedback only to the selected workshop', () async {
    final store = WorkshopFeedbackStore();
    await store.add(
      WorkshopFeedback(
        id: 'feedback-1',
        workshopId: 'workshop-1',
        clientName: 'Diana',
        clientEmail: 'diana@example.com',
        mechanicName: 'Carlos',
        serviceType: 'Diagnóstico',
        rating: 5,
        comment: 'Excelente atención',
        createdAt: DateTime(2026, 10, 20),
      ),
    );

    final feedback = await store.list('workshop-1');
    expect(feedback, hasLength(1));
    expect(feedback.single.rating, 5);
    expect(feedback.single.mechanicName, 'Carlos');
    expect(await store.list('workshop-2'), isEmpty);
  });
}
