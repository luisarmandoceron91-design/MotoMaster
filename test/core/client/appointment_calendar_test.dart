import 'package:flutter_test/flutter_test.dart';
import 'package:moto_master/core/client/appointment_calendar.dart';

void main() {
  group('appointment calendar', () {
    final now = DateTime(2026, DateTime.october, 23, 14, 30);

    test('starts from the real current day and spans future years', () {
      expect(appointmentToday(now), DateTime(2026, 10, 23));
      expect(appointmentCalendarLastDate(now), DateTime(2036, 12, 31));
    });

    test('moves an already passed month to the following year', () {
      expect(
        appointmentInitialDateForMonth(now, DateTime.january),
        DateTime(2027, 1, 1),
      );
      expect(
        appointmentInitialDateForMonth(now, DateTime.november),
        DateTime(2026, 11, 1),
      );
    });

    test('uses the next valid year when the current month is ending', () {
      expect(
        appointmentInitialDateForMonth(
          DateTime(2026, DateTime.december, 31),
          DateTime.december,
        ),
        DateTime(2027, 12, 1),
      );
    });

    test('respects Gregorian leap years and regular years', () {
      expect(daysInGregorianMonth(2028, DateTime.february), 29);
      expect(daysInGregorianMonth(2029, DateTime.february), 28);
      expect(daysInGregorianMonth(2032, DateTime.february), 29);
      expect(daysInGregorianMonth(2100, DateTime.february), 28);
    });

    test('clamps dates to the available calendar range', () {
      expect(
        clampAppointmentDate(value: DateTime(2020), systemNow: now),
        DateTime(2026, 10, 23),
      );
      expect(
        clampAppointmentDate(value: DateTime(2040), systemNow: now),
        DateTime(2036, 12, 31),
      );
    });
  });
}
