import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/client/client_service_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('el avance del taller aparece en la cita del cliente', () async {
    final store = ClientServiceStore();
    final appointment = ClientAppointment(
      id: 'appointment-1',
      motorcycleId: 'motorcycle-1',
      motorcycleName: 'Honda CBR · ABC123',
      serviceType: 'Mantenimiento',
      date: DateTime(2026, 10, 21),
      time: '08:00',
      notes: 'Cambio de aceite',
    );

    await store.saveAppointment('workshop-1', 'client-1', appointment);
    final workshopItems = await store.listWorkshopAppointments('workshop-1');

    expect(workshopItems, hasLength(1));
    expect(workshopItems.single.serviceStage, 'Cita solicitada');

    await store.updateAppointmentStage(
      workshopItems.single,
      'En reparación',
      mechanicName: 'Carlos',
    );

    final clientItems = await store.listAppointments('workshop-1', 'client-1');
    expect(clientItems.single.serviceStage, 'En reparación');
    expect(clientItems.single.mechanicName, 'Carlos');
    expect(clientItems.single.updatedAt, isNotNull);
  });

  test('impide reservar dos veces el mismo horario del taller', () async {
    final store = ClientServiceStore();
    final date = DateTime.now().add(const Duration(days: 5));
    final first = ClientAppointment(
      id: 'appointment-1',
      motorcycleId: 'motorcycle-1',
      motorcycleName: 'Yamaha MT-03 · ABC123',
      serviceType: 'Diagnóstico',
      date: date,
      time: '10:00',
      notes: '',
    );
    final second = ClientAppointment(
      id: 'appointment-2',
      motorcycleId: 'motorcycle-2',
      motorcycleName: 'Honda CB · DEF456',
      serviceType: 'Mantenimiento',
      date: date,
      time: '10:00',
      notes: '',
    );

    await store.saveAppointment('workshop-1', 'client-1', first);

    expect(
      () => store.saveAppointment('workshop-1', 'client-2', second),
      throwsA(isA<AppointmentSlotUnavailableException>()),
    );
    expect(await store.isSlotAvailable('workshop-1', date, '10:00'), isFalse);
    expect(await store.isSlotAvailable('workshop-2', date, '10:00'), isTrue);
  });

  test('cancelar con anticipación libera el horario', () async {
    final store = ClientServiceStore();
    final date = DateTime.now().add(const Duration(days: 3));
    final appointment = ClientAppointment(
      id: 'appointment-cancel',
      motorcycleId: 'motorcycle-1',
      motorcycleName: 'Yamaha MT-03 · ABC123',
      serviceType: 'Diagnóstico',
      date: date,
      time: '14:00',
      notes: '',
    );
    await store.saveAppointment('workshop-1', 'client-1', appointment);
    final saved = (await store.listAppointments(
      'workshop-1',
      'client-1',
    )).single;

    await store.cancelAppointment(saved);

    final cancelled = (await store.listAppointments(
      'workshop-1',
      'client-1',
    )).single;
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.serviceStage, 'Cita cancelada');
    expect(await store.isSlotAvailable('workshop-1', date, '14:00'), isTrue);
  });

  test('no permite cancelar faltando menos de 24 horas', () async {
    final store = ClientServiceStore();
    final soon = DateTime.now().add(const Duration(hours: 12));
    final appointment = ClientAppointment(
      id: 'appointment-soon',
      motorcycleId: 'motorcycle-1',
      motorcycleName: 'Yamaha MT-03 · ABC123',
      serviceType: 'Diagnóstico',
      date: soon,
      time:
          '${soon.hour.toString().padLeft(2, '0')}:${soon.minute.toString().padLeft(2, '0')}',
      notes: '',
      workshopId: 'workshop-1',
      clientId: 'client-1',
    );

    expect(
      () => store.cancelAppointment(appointment),
      throwsA(isA<AppointmentCancellationNotAllowedException>()),
    );
  });
}
