import 'package:aura_pricing_app/services/patient_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('patient payments', () {
    test('parses and sorts payments chronologically', () {
      final payments = parsePatientPayments([
        {'date': '2025-06-20T09:00:00Z', 'amount': 2000},
        {'date': '2025-06-01T09:00:00Z', 'amount': 1000},
      ]);

      expect(payments.map((payment) => payment.amount), [1000, 2000]);
      expect(payments.map((payment) => payment.storageIndex), [1, 0]);
    });

    test('sums total paid from valid payments', () {
      final total = totalPaidFromPayments([
        {'date': '2025-06-20T09:00:00Z', 'amount': 2000},
        {'date': '2025-06-01T09:00:00Z', 'amount': 1000.5},
        {'date': 'invalid', 'amount': 999},
      ]);

      expect(total, 3000.5);
    });

    test('returns earliest positive payment date', () {
      final firstPaymentDate = firstPaymentDateFromPayments([
        {'date': '2025-06-20T09:00:00Z', 'amount': 2000},
        {'date': '2025-06-01T09:00:00Z', 'amount': 1000},
        {'date': '2025-05-01T09:00:00Z', 'amount': 0},
      ]);

      expect(firstPaymentDate, DateTime.parse('2025-06-01T09:00:00Z'));
    });

    test('clones raw payment payload for editing', () {
      final payload = clonePatientPaymentsPayload([
        {'date': '2025-06-20T09:00:00Z', 'amount': 2000},
      ]);

      payload[0]['amount'] = 3000;

      final freshPayload = clonePatientPaymentsPayload([
        {'date': '2025-06-20T09:00:00Z', 'amount': 2000},
      ]);

      expect(freshPayload[0]['amount'], 2000);
    });
  });
}
