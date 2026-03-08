class PatientPayment {
  final int storageIndex;
  final double amount;
  final DateTime date;

  const PatientPayment({
    required this.storageIndex,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'amount': amount,
      'date': date.toUtc().toIso8601String(),
    };
  }
}

List<PatientPayment> parsePatientPayments(dynamic paymentsRaw) {
  if (paymentsRaw is! List) return const <PatientPayment>[];

  final payments = <PatientPayment>[];
  for (var index = 0; index < paymentsRaw.length; index++) {
    final payment = paymentsRaw[index];
    if (payment is! Map) continue;

    final amount = _parsePaymentAmount(payment['amount']);
    final date = _parsePaymentDate(payment['date']);
    if (amount == null || date == null) continue;

    payments.add(
      PatientPayment(storageIndex: index, amount: amount, date: date),
    );
  }

  payments.sort((a, b) {
    final dateCompare = a.date.compareTo(b.date);
    if (dateCompare != 0) return dateCompare;
    return a.storageIndex.compareTo(b.storageIndex);
  });
  return payments;
}

List<Map<String, dynamic>> clonePatientPaymentsPayload(dynamic paymentsRaw) {
  if (paymentsRaw is! List) return <Map<String, dynamic>>[];

  final payload = <Map<String, dynamic>>[];
  for (final payment in paymentsRaw) {
    if (payment is! Map) continue;
    payload.add(Map<String, dynamic>.from(payment));
  }
  return payload;
}

double totalPaidFromPayments(dynamic paymentsRaw) {
  return parsePatientPayments(
    paymentsRaw,
  ).fold(0, (sum, payment) => sum + payment.amount);
}

DateTime? firstPaymentDateFromPayments(dynamic paymentsRaw) {
  DateTime? earliest;
  for (final payment in parsePatientPayments(paymentsRaw)) {
    if (payment.amount <= 0) continue;
    if (earliest == null || payment.date.isBefore(earliest)) {
      earliest = payment.date;
    }
  }
  return earliest;
}

double? _parsePaymentAmount(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

DateTime? _parsePaymentDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
