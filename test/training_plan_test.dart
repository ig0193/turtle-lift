import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/training_plan.dart';
import 'package:turtle_lift/src/ui/schedule_pane.dart' show weekCaption;

/// The dated training plan and the week summary derived from it.
///
/// October 2026 is used throughout: the 1st is a Thursday, so Monday is the
/// 5th, 12th, 19th and 26th, and the week of the 19th runs to Sunday the 25th.
void main() {
  LocalDate oct(int day) => LocalDate(2026, 10, day);

  const monWedFri = <int>{0, 2, 4};

  TrainingPlanEntry plan(int from, Set<int> days) =>
      TrainingPlanEntry(effectiveFrom: oct(from), weekdays: days);

  Set<LocalDate> trained(Iterable<int> days) => days.map(oct).toSet();

  WeekSummary week({
    required int today,
    required Iterable<int> sessions,
    List<TrainingPlanEntry>? entries,
    int start = 19,
  }) =>
      weekSummaryFor(
        weekStart: oct(start),
        today: oct(today),
        plan: entries ?? <TrainingPlanEntry>[plan(1, monWedFri)],
        trained: trained(sessions),
      );

  group('which weekdays are in force', () {
    test('none before the first plan was saved', () {
      expect(weekdaysInEffectOn(<TrainingPlanEntry>[plan(10, monWedFri)], oct(9)),
          isEmpty);
    });

    test('a plan governs the day it was saved and every day after', () {
      final entries = <TrainingPlanEntry>[plan(10, monWedFri)];
      expect(weekdaysInEffectOn(entries, oct(10)), monWedFri);
      expect(weekdaysInEffectOn(entries, oct(30)), monWedFri);
    });

    test('the latest entry on or before the date wins, in any list order', () {
      final entries = <TrainingPlanEntry>[
        plan(20, const <int>{1, 3}),
        plan(1, monWedFri),
      ];
      expect(weekdaysInEffectOn(entries, oct(19)), monWedFri);
      expect(weekdaysInEffectOn(entries, oct(20)), const <int>{1, 3});
    });

    test('an empty plan is a real answer and clears the days from then on', () {
      final entries = <TrainingPlanEntry>[
        plan(1, monWedFri),
        plan(15, const <int>{}),
      ];
      expect(weekdaysInEffectOn(entries, oct(14)), monWedFri);
      expect(weekdaysInEffectOn(entries, oct(15)), isEmpty);
    });

    test('the bitmask round-trips, Monday as bit zero', () {
      expect(TrainingPlanEntry.maskOf(monWedFri), 0x15);
      expect(TrainingPlanEntry.weekdaysOf(0x15), monWedFri);
      expect(TrainingPlanEntry.maskOf(const <int>{}), 0);
      expect(TrainingPlanEntry.weekdaysOf(127), <int>{0, 1, 2, 3, 4, 5, 6});
    });
  });

  group('the week starts on Monday', () {
    test('any day of the week resolves to that Monday', () {
      for (final day in <int>[19, 20, 21, 22, 23, 24, 25]) {
        expect(startOfWeek(oct(day)), oct(19), reason: 'day $day');
      }
      expect(startOfWeek(oct(26)), oct(26));
    });
  });

  group('this week against the plan', () {
    test('mid-week: Monday done, the rest still ahead, today included', () {
      final w = week(today: 21, sessions: <int>[19]);
      expect(w.planned, 3);
      expect(w.hit, 1);
      expect(w.remaining.map((d) => d.date), <LocalDate>[oct(21), oct(23)],
          reason: 'today counts as remaining until it has a session');
      expect(weekCaption(w), '2 more to go — next is Wednesday');
    });

    test('a session today turns today into a hit', () {
      final w = week(today: 21, sessions: <int>[19, 21]);
      expect(w.hit, 2);
      expect(weekCaption(w), '1 more to go — next is Friday');
    });

    test('a skipped day is empty, never counted against what is left', () {
      final w = week(today: 23, sessions: <int>[19]);
      expect(w.days.map((d) => d.state), <PlanDayState>[
        PlanDayState.hit,
        PlanDayState.empty,
        PlanDayState.ahead,
      ]);
      expect(weekCaption(w), '1 more to go — next is Friday');
    });

    test('once the week is over it reads as a plain count', () {
      final w = week(today: 25, sessions: <int>[19, 23]);
      expect(w.hit, 2);
      expect(w.remaining, isEmpty);
      expect(weekCaption(w), '2 of 3 plan days');
    });

    test('every plan day done says so, and extra sessions are counted', () {
      final w = week(today: 25, sessions: <int>[19, 21, 23, 24]);
      expect(weekCaption(w), 'All 3 plan days done · +1 extra');
    });

    test('a session on a rest day is extra, not a hit', () {
      final w = week(today: 25, sessions: <int>[20]);
      expect(w.hit, 0);
      expect(w.extra, 1);
      expect(weekCaption(w), '0 of 3 plan days · +1 extra');
    });

    test('sessions after today are ignored', () {
      final w = week(today: 20, sessions: <int>[19, 21, 23]);
      expect(w.hit, 1);
      expect(w.remaining, hasLength(2));
    });

    test('no copy ever says missed, behind or failed', () {
      for (var today = 19; today <= 25; today++) {
        for (final sessions in <List<int>>[
          <int>[],
          <int>[19],
          <int>[19, 21, 23],
        ]) {
          final caption = weekCaption(week(today: today, sessions: sessions));
          expect(caption.toLowerCase(),
              isNot(anyOf(contains('miss'), contains('behind'), contains('fail'))),
              reason: 'day $today, sessions $sessions: "$caption"');
        }
      }
    });
  });

  group('changing the plan never rewrites the past', () {
    // Mon/Wed/Fri from 1 Oct, then Tue/Thu from Tue 20 Oct.
    final entries = <TrainingPlanEntry>[
      plan(1, monWedFri),
      plan(20, const <int>{1, 3}),
    ];

    test('last week keeps the old days', () {
      final w = week(
        today: 21,
        sessions: <int>[12, 16],
        entries: entries,
        start: 12,
      );
      expect(w.days.map((d) => d.weekday), <int>[0, 2, 4]);
      expect(w.hit, 2, reason: 'Monday and Friday were hit, Wednesday was not');
    });

    test('a week straddling the change uses the plan in force on each day', () {
      final w = week(today: 21, sessions: <int>[19], entries: entries);
      // Mon 19 is under the old plan; Tue 20 and Thu 22 under the new one;
      // Wed 21 and Fri 23 are no longer plan days.
      expect(w.days.map((d) => d.date), <LocalDate>[oct(19), oct(20), oct(22)]);
      expect(w.hit, 1);
    });
  });

  group('derived on read', () {
    HistorySession session(String id, int day) => HistorySession(
          id: id,
          performedOn: DateTime(2026, 10, day),
          exercises: const <HistoryExercise>[],
        );

    ProviderContainer container(List<HistorySession> sessions,
        List<TrainingPlanEntry> entries) {
      final c = ProviderContainer(overrides: [
        planTodayProvider.overrideWithValue(oct(21)),
        historySessionsProvider.overrideWithValue(sessions),
        initialTrainingPlanProvider.overrideWithValue(entries),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('no plan means no summary, never "0 of 0"', () {
      final c = container(<HistorySession>[session('a', 19)], const []);
      expect(c.read(thisWeekSummaryProvider), isNull);
      expect(c.read(lastWeekSummaryProvider), isNull);
      expect(c.read(todayPlanWeekdaysProvider), isEmpty);
    });

    test('the summary follows the saved sessions', () {
      final c = container(
        <HistorySession>[session('a', 19), session('b', 12), session('c', 16)],
        <TrainingPlanEntry>[plan(1, monWedFri)],
      );
      expect(c.read(thisWeekSummaryProvider)!.hit, 1);
      expect(c.read(lastWeekSummaryProvider)!.hit, 2);
      expect(c.read(lastWeekSummaryProvider)!.planned, 3);
    });

    test('a deleted session leaves the summary, with nothing stored to fix', () {
      final withIt = container(
        <HistorySession>[session('a', 19)],
        <TrainingPlanEntry>[plan(1, monWedFri)],
      );
      final without = container(
        const <HistorySession>[],
        <TrainingPlanEntry>[plan(1, monWedFri)],
      );
      expect(withIt.read(thisWeekSummaryProvider)!.hit, 1);
      expect(without.read(thisWeekSummaryProvider)!.hit, 0);
    });
  });

  group('storage', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => database.close());

    test('reads entries back oldest first as domain entries', () async {
      final store = TrainingPlanStore(database);
      await store.appendEntry('2026-10-20', 0x0A);
      await store.appendEntry('2026-10-01', 0x15);

      expect(await readStoredTrainingPlan(store), <TrainingPlanEntry>[
        plan(1, monWedFri),
        plan(20, const <int>{1, 3}),
      ]);
    });

    test('saving twice on one day replaces that day', () async {
      final store = TrainingPlanStore(database);
      await store.appendEntry('2026-10-20', 0x15);
      await store.appendEntry('2026-10-20', 0x01);

      final rows = await store.readEntries();
      expect(rows, hasLength(1));
      expect(rows.single.weekdayMask, 0x01);
    });

    test('the notifier stamps today, persists, and replaces a same-day save',
        () async {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ]);
      addTearDown(c.dispose);
      final log = c.read(trainingPlanLogProvider.notifier);

      await log.save(monWedFri);
      await log.save(const <int>{1});

      final today = LocalDate.today();
      expect(c.read(trainingPlanLogProvider), <TrainingPlanEntry>[
        TrainingPlanEntry(effectiveFrom: today, weekdays: const <int>{1}),
      ]);
      final stored = await readStoredTrainingPlan(TrainingPlanStore(database));
      expect(stored, c.read(trainingPlanLogProvider));
    });

    test('there is no way to edit or delete a past plan', () {
      // Enforced by absence, like the bodyweight series: a method here would
      // let a past week be re-read against a plan it was never lived under.
      final source = File('lib/src/data/training_plan.dart').readAsStringSync();
      expect(source, isNot(contains('_db.delete(')));
      expect(source, isNot(contains('_db.update(')));
      expect(source, isNot(contains('.replace(')));
    });
  });
}
