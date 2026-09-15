import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/bodyweight_resolution.dart';
import 'package:turtle_lift/src/data/personal_details_store.dart';

/// Proves the one rule the whole bodyweight fix exists to enforce: a date
/// resolves to the weight that was in effect *then*, and a date earlier than
/// every weigh-in resolves to nothing at all.
///
/// **The last two groups are the regression guard, not extra coverage.** The
/// bug being designed out is a calorie estimate computed from the newest weight
/// on record, which silently re-prices every session already logged the moment
/// the user steps on a scale again. An implementation that returns "the current
/// weight" passes the happy-path cases in the first group and fails
/// `a newer entry` and `no legal sequence of writes`; that asymmetry is the
/// point of them.
///
/// No database and no widgets here. Resolution is pure date arithmetic over a
/// list, which is precisely why `bodyweight_resolution.dart` takes the series
/// as an argument — the provider group at the end is the only part that needs
/// a container.
void main() {
  // A short, deliberately uneven series: two gaps of different lengths, so a
  // "between two entries" case cannot be confused with an off-by-one-day one.
  final janFirst = BodyweightEntry(date: DateTime(2026, 1, 1), weightKg: 80.0);
  final marchTenth = BodyweightEntry(date: DateTime(2026, 3, 10), weightKg: 78.5);
  final juneFirst = BodyweightEntry(date: DateTime(2026, 6, 1), weightKg: 76.0);
  final series = <BodyweightEntry>[janFirst, marchTenth, juneFirst];

  group('a date with a weight in effect', () {
    test('a date after the only entry resolves to that entry', () {
      expect(
        weightInEffectOn(<BodyweightEntry>[janFirst], DateTime(2026, 9, 14)),
        janFirst,
      );
    });

    test('a date exactly on an entry resolves to that entry, not the one '
        'before it', () {
      expect(
        weightInEffectOn(series, DateTime(2026, 3, 10)),
        marchTenth,
        reason: 'KD5 says an entry takes effect from the day it is recorded, '
            'so the day itself is already covered by it',
      );
    });

    test('a date between two entries resolves to the earlier one', () {
      expect(
        weightInEffectOn(series, DateTime(2026, 4, 20)),
        marchTenth,
        reason: 'the March weight was the last thing the user told us before '
            'that day; the June one had not happened yet',
      );
    });

    test('the day before an entry still resolves to the previous one', () {
      expect(weightInEffectOn(series, DateTime(2026, 5, 31)), marchTenth);
    });

    test('a date after every entry resolves to the newest', () {
      expect(weightInEffectOn(series, DateTime(2027, 1, 1)), juneFirst);
    });

    test('a time of day on the asked date does not change the answer', () {
      // The 11pm case CLAUDE.md calls out. `performedOn` is a calendar date,
      // but a caller holding a DateTime with a time on it must not resolve to
      // yesterday's weight just because the clock has not wrapped.
      expect(
        weightInEffectOn(series, DateTime(2026, 3, 10, 23, 30)),
        marchTenth,
        reason: 'resolution compares calendar days, not instants',
      );
    });
  });

  group('a date with no weight in effect', () {
    test('a date before every entry resolves to nothing, though entries exist',
        () {
      expect(
        weightInEffectOn(series, DateTime(2025, 12, 31)),
        isNull,
        reason: 'KD3: a session older than the first weigh-in shows the '
            'add-weight prompt permanently, never a back-filled number',
      );
    });

    test('the day before the first entry is already outside it', () {
      expect(weightInEffectOn(series, DateTime(2025, 12, 31)), isNull);
    });

    test('with no entries at all, any date resolves to nothing', () {
      expect(
        weightInEffectOn(const <BodyweightEntry>[], DateTime(2026, 6, 1)),
        isNull,
      );
    });

    test('recording a weight later does not backfill an earlier date', () {
      final before = weightInEffectOn(const <BodyweightEntry>[], DateTime(2026, 1, 5));
      final after = weightInEffectOn(<BodyweightEntry>[marchTenth], DateTime(2026, 1, 5));

      expect(before, isNull);
      expect(
        after,
        isNull,
        reason: 'R11: entering a weight in March says nothing about January, '
            'so that session keeps its prompt forever',
      );
    });
  });

  group('a newer entry never rewrites an older date', () {
    test('appending a newer weight leaves an earlier date untouched', () {
      final beforeJune = weightInEffectOn(
        <BodyweightEntry>[janFirst, marchTenth],
        DateTime(2026, 4, 20),
      );
      final afterJune = weightInEffectOn(series, DateTime(2026, 4, 20));

      expect(
        afterJune,
        beforeJune,
        reason: 'R10: a session in April is priced from the March weight '
            'whether or not the user has weighed in since -- an '
            'implementation returning the newest entry fails exactly here',
      );
    });

    test('the newest entry is not the answer for every date', () {
      expect(
        weightInEffectOn(series, DateTime(2026, 2, 1)),
        isNot(juneFirst),
        reason: 'the naive "use the current weight" implementation this work '
            'replaces returns juneFirst here',
      );
    });
  });

  group('no legal sequence of writes changes an already-resolved date', () {
    test('a past date keeps its answer across an arbitrary run of appends', () {
      // A property-style check rather than a fixed sequence, because the claim
      // is about *all* legal write orders and KD5 defines the legal ones
      // narrowly: appends only, each dated at or after the last, no edit, no
      // delete, no backdating. The seed is fixed so a failure is reproducible.
      //
      // **A date is only frozen once a weigh-in later than it exists.** Stated
      // any wider the property is simply false, and usefully so: a weight
      // recorded on the 29th does change what the 2nd of the next month
      // resolves to, because on the 29th that day has not happened and no
      // session can have been logged on it. What must never move is a date the
      // series has already passed -- that is a session in the user's history,
      // and KD5's no-backdating rule is what guarantees no later entry can
      // reach back before it.
      final random = Random(20260915);

      for (var run = 0; run < 50; run++) {
        final log = <BodyweightEntry>[];
        var cursor = DateTime(2026, 1, 1);

        // Dates spread either side of the series, so most runs include dates
        // that resolve to nothing as well as dates that resolve to an entry.
        final probes = <DateTime>[
          for (var i = 0; i < 12; i++)
            DateTime(2025, 12, 20).add(Duration(days: i * 11)),
        ];
        final frozen = <DateTime, BodyweightEntry?>{};

        for (var write = 0; write < 8; write++) {
          // "At or after the last" -- a zero-day step is the same-day
          // correction `appendBodyweightEntry` allows, and is legal.
          cursor = cursor.add(Duration(days: random.nextInt(40)));
          log
            ..removeWhere((entry) => entry.date == cursor)
            ..add(BodyweightEntry(
              date: cursor,
              weightKg: 60.0 + random.nextInt(400) / 10,
            ));

          for (final probe in probes.where(cursor.isAfter)) {
            final answer = weightInEffectOn(log, probe);
            if (frozen.containsKey(probe)) {
              expect(
                answer,
                frozen[probe],
                reason: 'the weight in effect on $probe changed after a write '
                    'dated $cursor -- run $run, write $write. Any drift here '
                    'is a logged session silently re-pricing itself, which is '
                    'the bug KD5 and this function exist to prevent',
              );
            } else {
              frozen[probe] = answer;
            }
          }
        }

        expect(
          frozen,
          isNotEmpty,
          reason: 'a run that froze no date at all would assert nothing, so '
              'this guards the generator rather than the function',
        );
      }
    });

    test('a date stays unresolved once the series has moved past it', () {
      // The half of the property the loop above cannot state on its own: a
      // date before the first weigh-in must keep resolving to nothing however
      // many weights arrive afterwards.
      final log = <BodyweightEntry>[marchTenth];
      final orphanedSession = DateTime(2026, 2, 1);

      expect(weightInEffectOn(log, orphanedSession), isNull);

      log.add(juneFirst);
      expect(weightInEffectOn(log, orphanedSession), isNull);

      log.add(BodyweightEntry(date: DateTime(2027, 1, 1), weightKg: 74.0));
      expect(
        weightInEffectOn(log, orphanedSession),
        isNull,
        reason: 'KD3 makes this permanent, not merely "until we know more"',
      );
    });
  });

  group('the provider seam', () {
    test('it resolves against the series the log provider is holding', () {
      final container = ProviderContainer(
        overrides: [
          initialBodyweightLogProvider.overrideWithValue(series),
        ],
      );
      addTearDown(container.dispose);

      final resolve = container.read(weightInEffectProvider);

      expect(resolve(DateTime(2026, 4, 20)), marchTenth);
      expect(resolve(DateTime(2025, 11, 1)), isNull);
    });

    test('an empty log resolves everything to nothing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(weightInEffectProvider)(DateTime(2026, 6, 1)),
        isNull,
        reason: 'a fresh install has weighed in never, which is the state '
            'that shows the add-weight prompt',
      );
    });

    test('recording a weight re-resolves later dates without touching earlier '
        'ones', () async {
      final container = ProviderContainer(
        overrides: [
          initialBodyweightLogProvider.overrideWithValue(<BodyweightEntry>[marchTenth]),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(weightInEffectProvider)(DateTime(2026, 2, 1)), isNull);

      // Reaching past `record` -- it writes to the database, which needs a
      // platform channel. What is under test here is that the resolver tracks
      // the log's state, not that the store persists.
      //
      // The new state is an *append*, not `series`: `series` would slip
      // janFirst in behind marchTenth, and a backdated entry is a write KD5
      // forbids. Asserting against one would be testing behaviour the app
      // cannot produce.
      container.read(bodyweightLogProvider.notifier).state =
          <BodyweightEntry>[marchTenth, juneFirst];

      expect(
        container.read(weightInEffectProvider)(DateTime(2026, 2, 1)),
        isNull,
        reason: 'a newer series must not give an old date an answer it did '
            'not have',
      );
      expect(container.read(weightInEffectProvider)(DateTime(2026, 6, 2)), juneFirst);
    });
  });
}
