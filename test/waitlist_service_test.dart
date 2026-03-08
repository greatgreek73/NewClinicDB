import 'package:aura_pricing_app/services/waitlist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('waitlist parsing', () {
    test('reads waitlist stage and order from row data', () {
      final assignment = waitlistAssignmentFromData({
        'waitlist_stage': '3',
        'waitlist_order': 7,
      });

      expect(assignment.stageId, 3);
      expect(assignment.order, 7);
    });

    test('falls back to legacy priority bucket data', () {
      final assignment = waitlistAssignmentFromData({'priority_bucket': '2'});

      expect(assignment.stageId, 2);
      expect(assignment.order, isNull);
    });

    test('falls back to queue order when payment age is unavailable', () {
      final entries = waitlistEntriesForStage([
        {
          'id': 'b',
          'name': 'Bob',
          'surname': 'Bravo',
          'waitlist_stage': 1,
          'waitlist_order': 2,
        },
        {
          'id': 'a',
          'name': 'Alice',
          'surname': 'Alpha',
          'waitlist_stage': 1,
          'waitlist_order': 1,
        },
        {
          'id': 'x',
          'name': 'Xenia',
          'surname': 'Other',
          'waitlist_stage': 2,
          'waitlist_order': 1,
        },
      ], 1);

      expect(entries.map((entry) => entry.id), ['a', 'b']);
    });

    test('sorts stage entries by longest days since first payment first', () {
      final entries = waitlistEntriesForStage([
        {
          'id': 'newer',
          'name': 'Newer',
          'surname': 'Patient',
          'waitlist_stage': 1,
          'waitlist_order': 1,
          'payments': [
            {'date': '2025-06-20T09:00:00Z', 'amount': 1000},
          ],
        },
        {
          'id': 'older',
          'name': 'Older',
          'surname': 'Patient',
          'waitlist_stage': 1,
          'waitlist_order': 3,
          'payments': [
            {'date': '2025-06-01T09:00:00Z', 'amount': 1000},
          ],
        },
        {
          'id': 'no-payment',
          'name': 'No',
          'surname': 'Payment',
          'waitlist_stage': 1,
          'waitlist_order': 2,
        },
      ], 1);

      expect(entries.map((entry) => entry.id), [
        'older',
        'newer',
        'no-payment',
      ]);
    });

    test('extracts earliest first payment date from unsorted payments', () {
      final firstPayment = firstPaymentDateFromData({
        'payments': [
          {'date': '2025-08-13T21:00:00Z', 'amount': 200000},
          {'date': '2025-06-04T21:00:00Z', 'amount': 100000},
          {'date': '2025-06-30T21:00:00Z', 'amount': 100000},
        ],
      });

      expect(firstPayment, DateTime.parse('2025-06-04T21:00:00Z'));
    });

    test('stores first payment date in waitlist entry', () {
      final entry = waitlistEntryFromRow({
        'id': 'a',
        'name': 'Alice',
        'surname': 'Alpha',
        'waitlist_stage': 1,
        'waitlist_order': 1,
        'payments': [
          {'date': '2025-03-10T09:00:00Z', 'amount': 50000},
          {'date': '2025-02-10T09:00:00Z', 'amount': 50000},
        ],
      });

      expect(entry.firstPaymentDate, DateTime.parse('2025-02-10T09:00:00Z'));
    });
  });

  group('waitlist queue helpers', () {
    test('next waitlist order appends to the end of a stage', () {
      final entries = [
        waitlistEntryFromRow({
          'id': 'a',
          'name': 'Alice',
          'waitlist_stage': 1,
          'waitlist_order': 1,
        }),
        waitlistEntryFromRow({
          'id': 'b',
          'name': 'Bob',
          'waitlist_stage': 1,
          'waitlist_order': 2,
        }),
      ];

      expect(nextWaitlistOrder(entries), 3);
    });

    test('move patches reindex entries after moving up', () {
      final patches = buildWaitlistMovePatches(
        [
          waitlistEntryFromRow({
            'id': 'a',
            'name': 'Alice',
            'waitlist_stage': 1,
            'waitlist_order': 1,
          }),
          waitlistEntryFromRow({
            'id': 'b',
            'name': 'Bob',
            'waitlist_stage': 1,
            'waitlist_order': 2,
          }),
          waitlistEntryFromRow({
            'id': 'c',
            'name': 'Cara',
            'waitlist_stage': 1,
            'waitlist_order': 3,
          }),
        ],
        'c',
        -1,
      );

      expect(patches.map((patch) => '${patch.patientId}:${patch.order}'), [
        'c:2',
        'b:3',
      ]);
    });

    test('compaction removes gaps and null orders after removal', () {
      final patches = compactWaitlistStage([
        waitlistEntryFromRow({
          'id': 'a',
          'name': 'Alice',
          'waitlist_stage': 1,
          'waitlist_order': 2,
        }),
        waitlistEntryFromRow({
          'id': 'b',
          'name': 'Bob',
          'waitlist_stage': 1,
          'waitlist_order': null,
        }),
      ]);

      expect(patches.map((patch) => '${patch.patientId}:${patch.order}'), [
        'a:1',
        'b:2',
      ]);
    });
  });
}
