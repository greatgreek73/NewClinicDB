import 'package:aura_pricing_app/services/daily_revenue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('daily revenue service', () {
    test('sums only payments inside the requested day window', () {
      final total = totalPaymentsInRangeFromRows(
        [
          {
            'payments': [
              {'date': '2026-03-09T08:30:00Z', 'amount': 1000},
              {'date': '2026-03-09T12:00:00Z', 'amount': 2500.5},
              {'date': '2026-03-08T23:59:59Z', 'amount': 999},
            ],
          },
          {
            'payments': [
              {'date': '2026-03-10T00:00:00Z', 'amount': 3000},
              {'date': '2026-03-09T14:15:00Z', 'amount': 500},
            ],
          },
        ],
        startInclusive: DateTime.utc(2026, 3, 9),
        endExclusive: DateTime.utc(2026, 3, 10),
      );

      expect(total, 4000.5);
    });

    test('returns zero working hours before the workday starts', () {
      final elapsed = elapsedWorkingHoursToday(DateTime(2026, 3, 9, 8, 0));

      expect(elapsed, 0);
    });

    test(
      'tracks elapsed working hours during the day and caps after close',
      () {
        final during = elapsedWorkingHoursToday(DateTime(2026, 3, 9, 10, 15));
        final afterClose = elapsedWorkingHoursToday(
          DateTime(2026, 3, 9, 17, 0),
        );

        expect(during, 2.0);
        expect(afterClose, 7.0);
      },
    );

    test('calculates hourly revenue pace from elapsed working hours', () {
      final beforeStart = revenuePerWorkingHourToday(
        700,
        DateTime(2026, 3, 9, 8, 0),
      );
      final during = revenuePerWorkingHourToday(
        700,
        DateTime(2026, 3, 9, 10, 15),
      );

      expect(beforeStart, isNull);
      expect(during, 350);
    });
  });
}
