import 'patient_payment_service.dart';

const Duration clinicWorkdayStart = Duration(hours: 8, minutes: 15);
const Duration clinicWorkdayEnd = Duration(hours: 15, minutes: 15);

double totalPaymentsInRange(
  dynamic paymentsRaw, {
  required DateTime startInclusive,
  required DateTime endExclusive,
}) {
  var total = 0.0;
  for (final payment in parsePatientPayments(paymentsRaw)) {
    final date = payment.date.toUtc();
    if (date.isBefore(startInclusive) || !date.isBefore(endExclusive)) {
      continue;
    }
    total += payment.amount;
  }
  return total;
}

double totalPaymentsInRangeFromRows(
  Iterable<Map<String, dynamic>> rows, {
  required DateTime startInclusive,
  required DateTime endExclusive,
}) {
  var total = 0.0;
  for (final row in rows) {
    total += totalPaymentsInRange(
      row['payments'],
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    );
  }
  return total;
}

double elapsedWorkingHoursToday(
  DateTime now, {
  Duration workdayStart = clinicWorkdayStart,
  Duration workdayEnd = clinicWorkdayEnd,
}) {
  final localNow = now.toLocal();
  final start = DateTime(
    localNow.year,
    localNow.month,
    localNow.day,
  ).add(workdayStart);
  final end = DateTime(
    localNow.year,
    localNow.month,
    localNow.day,
  ).add(workdayEnd);

  if (!localNow.isAfter(start)) return 0;
  if (!localNow.isBefore(end)) {
    return end.difference(start).inMinutes / 60.0;
  }

  return localNow.difference(start).inMinutes / 60.0;
}

double? revenuePerWorkingHourToday(
  double revenueToday,
  DateTime now, {
  Duration workdayStart = clinicWorkdayStart,
  Duration workdayEnd = clinicWorkdayEnd,
}) {
  final elapsedHours = elapsedWorkingHoursToday(
    now,
    workdayStart: workdayStart,
    workdayEnd: workdayEnd,
  );
  if (elapsedHours <= 0) return null;
  return revenueToday / elapsedHours;
}
