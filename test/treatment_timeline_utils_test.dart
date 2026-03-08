import 'package:aura_pricing_app/pages/treatment_timeline_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTreatedTimelineGroups', () {
    test('filters only treated rows and groups by day desc', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 't-1',
          'treatment_type': 'Extraction',
          'tooth_number': ['16'],
          'status': 'treated',
          'date': '2026-02-21T10:10:00Z',
        },
        {
          'id': 't-2',
          'treatment_type': 'Abutment',
          'tooth_number': ['13', '21'],
          'status': 'treated',
          'date': '2026-02-21T08:05:00Z',
        },
        {
          'id': 't-3',
          'treatment_type': 'Caries',
          'tooth_number': ['12'],
          'status': 'planned',
          'date': '2026-02-20T00:00:00Z',
        },
        {
          'id': 't-4',
          'treatment_type': 'Crown',
          'tooth_number': ['12', '13'],
          'status': 'treated',
          'date': '2026-02-19T07:57:00Z',
        },
      ];

      final groups = buildTreatedTimelineGroups(rows);

      expect(groups.length, 2);
      expect(groups.first.totalEntries, 2);
      expect(groups.first.entries.first.title, 'Extraction');
      expect(groups.first.entries.first.id, 't-1');
      expect(groups.first.entries.last.id, 't-2');
      expect(groups.last.totalEntries, 1);
      expect(groups.last.entries.single.id, 't-4');
    });

    test('treats legacy rows without status as completed', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'legacy-1',
          'treatment_type': 'Implant',
          'tooth_number': ['14', '26'],
          'status': null,
          'date': '2026-02-21T10:10:00Z',
        },
      ];

      final groups = buildTreatedTimelineGroups(rows);

      expect(groups.length, 1);
      expect(groups.first.entries.single.id, 'legacy-1');
      expect(groups.first.entries.single.badge.text, 'Completed');
      expect(groups.first.entries.single.status, 'treated');
    });

    test('merges same treatment within one day', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'a1',
          'treatment_type': 'Extraction',
          'tooth_number': ['15'],
          'status': 'treated',
          'date': '2026-02-21T10:10:00Z',
        },
        {
          'id': 'a2',
          'treatment_type': 'Extraction',
          'tooth_number': ['16', '17'],
          'status': 'treated',
          'date': '2026-02-21T09:05:00Z',
        },
        {
          'id': 'b1',
          'treatment_type': 'Crown',
          'tooth_number': ['21'],
          'status': 'treated',
          'date': '2026-02-21T08:00:00Z',
        },
      ];

      final groups = buildTreatedTimelineGroups(rows);
      expect(groups.length, 1);
      expect(groups.first.totalEntries, 2);

      final extraction = groups.first.entries.firstWhere(
        (e) => e.title == 'Extraction',
      );
      expect(extraction.entriesCount, 2);
      expect(extraction.teeth, ['15', '16', '17']);
    });

    test('applies day and per-day limits for compact previews', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'a',
          'treatment_type': 'A',
          'tooth_number': ['11'],
          'status': 'treated',
          'date': '2026-02-21T10:00:00Z',
        },
        {
          'id': 'b',
          'treatment_type': 'B',
          'tooth_number': ['12'],
          'status': 'treated',
          'date': '2026-02-21T09:00:00Z',
        },
        {
          'id': 'c',
          'treatment_type': 'C',
          'tooth_number': ['13'],
          'status': 'treated',
          'date': '2026-02-20T08:00:00Z',
        },
      ];

      final groups = buildTreatedTimelineGroups(
        rows,
        maxDays: 1,
        maxEntriesPerDay: 1,
      );

      expect(groups.length, 1);
      expect(groups.first.totalEntries, 2);
      expect(groups.first.entries.length, 1);
      expect(groups.first.hiddenEntries, 1);
    });
  });

  group('date/time helpers', () {
    test('parseTimelineDate handles malformed values safely', () {
      expect(parseTimelineDate('not-a-date'), isNull);
      expect(parseTimelineDate(null), isNull);
      expect(parseTimelineDate('2026-02-21T10:10:00Z'), isA<DateTime>());
    });

    test('day labels return Today/Yesterday for matching dates', () {
      final now = DateTime(2026, 2, 22, 9, 30);
      expect(formatTimelineDayLabel(DateTime(2026, 2, 22), now: now), 'Today');
      expect(
        formatTimelineDayLabel(DateTime(2026, 2, 21), now: now),
        'Yesterday',
      );
      expect(
        formatTimelineDayLabel(DateTime(2026, 2, 20), now: now),
        'February 20, 2026',
      );
    });

    test('time label hides midnight when requested', () {
      final dt = DateTime(2026, 2, 22, 0, 0);
      expect(formatTimelineTimeLabel(dt), isNull);
      expect(formatTimelineTimeLabel(dt, hideMidnight: false), '00:00');
    });

    test('date-time label uses absolute date', () {
      final dt = DateTime(2026, 2, 20, 14, 5);
      expect(formatTimelineDateTimeLabel(dt), 'February 20, 2026, 14:05');
    });
  });
}
