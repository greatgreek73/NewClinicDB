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

    test('builds sorted stage entries by queue order', () {
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
