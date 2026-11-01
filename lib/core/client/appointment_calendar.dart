DateTime appointmentToday(DateTime systemNow) =>
    DateTime(systemNow.year, systemNow.month, systemNow.day);

DateTime appointmentCalendarLastDate(
  DateTime systemNow, {
  int yearsAhead = 10,
}) {
  final today = appointmentToday(systemNow);
  return DateTime(today.year + yearsAhead, 12, 31);
}

DateTime appointmentInitialDateForMonth(DateTime systemNow, int month) {
  if (month < DateTime.january || month > DateTime.december) {
    throw RangeError.range(month, DateTime.january, DateTime.december, 'month');
  }
  final today = appointmentToday(systemNow);
  final nextDay = today.add(const Duration(days: 1));
  if (month == today.month && nextDay.month == month) return nextDay;

  final year = month <= today.month ? today.year + 1 : today.year;
  return DateTime(year, month);
}

DateTime clampAppointmentDate({
  required DateTime value,
  required DateTime systemNow,
  int yearsAhead = 10,
}) {
  final firstDate = appointmentToday(systemNow);
  final lastDate = appointmentCalendarLastDate(
    systemNow,
    yearsAhead: yearsAhead,
  );
  if (value.isBefore(firstDate)) return firstDate;
  if (value.isAfter(lastDate)) return lastDate;
  return DateTime(value.year, value.month, value.day);
}

int daysInGregorianMonth(int year, int month) {
  if (month < DateTime.january || month > DateTime.december) {
    throw RangeError.range(month, DateTime.january, DateTime.december, 'month');
  }
  return DateTime(year, month + 1, 0).day;
}
