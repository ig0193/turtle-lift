import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'local_date.dart';
import 'settings_store.dart' show appDatabaseProvider;

/// The calendar-date helpers moved to `local_date.dart` when the session tables
/// needed the same type. Re-exported so every existing caller keeps working and
/// the app carries one spelling of a calendar date rather than two.
export 'local_date.dart'
    show decodeCalendarDate, encodeCalendarDate, todayLocal;

/// Reads and writes the two things the user tells the app about themselves:
/// their bodyweight, as a dated series, and which body-diagram artwork they
/// want. `docs/04` §Personal details calls these one screen, and they are the
/// only personal data V1 collects.
///
/// **A second store rather than more methods on `SettingsStore`.** The gender
/// value does live in the settings row, so putting its accessors there would
/// be the shorter diff — but the bodyweight series is its own table, and a
/// caller that wants "the user's personal details" would then have to hold two
/// stores and know which half lives where. The storage layout is an
/// implementation detail of this file; the grouping callers see is the one the
/// Profile screen is built from.
///
/// **It deals in opaque values, exactly like `SettingsStore`.** A date is a
/// `YYYY-MM-DD` string, a weight is a double, a gender is an unexamined string.
/// Deciding that `'female'` names `BodyGender.female` — and what an
/// unrecognised name means — belongs to `body_gender.dart`, which owns that
/// vocabulary. Teaching this class the enum too would put the same list in two
/// files, which is the drift the store-name rule exists to stop.
///
/// **There is deliberately no update and no delete for a bodyweight entry.**
/// KD5: an entry is immutable and takes effect from the day it is recorded, so
/// a correction is a new entry that supersedes the old one going forward,
/// never a rewrite of it. That is not a rule enforced by a check somewhere — it
/// is enforced by there being no method here to call, which is why
/// `test/personal_details_store_test.dart` reads this file's source and fails
/// if one reappears. The reason is that the calorie estimate is derived on read
/// from the weight *in effect on* a session's date: let a past entry be edited
/// or deleted and every already-logged session silently re-prices itself,
/// which is the bug this table exists to prevent.
class PersonalDetailsStore {
  const PersonalDetailsStore(this._db);

  final AppDatabase _db;

  /// Every recorded bodyweight, oldest first.
  ///
  /// **Ordered here rather than by the caller**, because the ordering is not a
  /// presentation choice: resolving "the weight in effect on a date" walks the
  /// series forward, and `date` is stored as `YYYY-MM-DD` precisely so that a
  /// string sort and a calendar sort are the same thing. A caller that sorted
  /// it itself would be re-deriving that fact from the date format.
  ///
  /// The whole series is read at once because it is one short row per weigh-in
  /// and every consumer needs the shape of it, not a single row.
  Future<List<BodyweightEntryRow>> readBodyweightEntries() {
    return (_db.select(_db.bodyweightEntries)
          ..orderBy(<OrderingTerm Function($BodyweightEntriesTable)>[
            (entries) => OrderingTerm.asc(entries.date),
          ]))
        .get();
  }

  /// Records [weightKg] as the weight in effect from [date] (`YYYY-MM-DD`).
  ///
  /// **An upsert, and that is not a back door into editing history.** `date` is
  /// the table's primary key, so recording a second weight on a day the user
  /// has already weighed in replaces that day rather than leaving two rows with
  /// no way to say which came later. The only day a caller can name is today —
  /// see `BodyweightLog.record`, which stamps the date itself — and today's
  /// sessions are not yet history, so nothing that has already been shown to
  /// the user changes underneath them.
  Future<void> appendBodyweightEntry(String date, double weightKg) async {
    await _db.into(_db.bodyweightEntries).insertOnConflictUpdate(
          BodyweightEntriesCompanion.insert(date: date, weightKg: weightKg),
        );
  }

  /// The stored gender name, or null when the user has never answered.
  ///
  /// Null is a real answer, not an error: `docs/04` gives an unset field the
  /// male artwork, and `BodyGender.preferNotToSay` resolves to that same
  /// artwork — only the null tells "I declined" apart from "I have not reached
  /// this screen yet", which is a difference the Profile screen renders.
  Future<String?> readBodyGender() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.id.equals(kSettingsRowId)))
        .getSingleOrNull();
    return row?.bodyGender;
  }

  /// Stores [name] as the gender every body diagram renders in.
  ///
  /// **The same upsert shape as `SettingsStore.writeWorkoutTemplateFilter`, and
  /// it has to be.** Both writes land on the one settings row, and an
  /// [UpdateCompanion] carries only the columns it was given — so this write
  /// leaves the split filter alone and that one leaves the gender alone. Build
  /// either of them out of a full row read-modify-write instead and whichever
  /// ran second would quietly reset the other; `test/personal_details_store_test.dart`
  /// holds that pair.
  Future<void> writeBodyGender(String name) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            id: const Value<int>(kSettingsRowId),
            bodyGender: Value<String>(name),
          ),
        );
  }
}

/// The personal-details store, named for the thing rather than the word
/// "provider" — matching `settingsStoreProvider` and `exerciseLibraryProvider`.
///
/// It reads [appDatabaseProvider], which is the seam a test overrides with an
/// in-memory database; there is no second database handle anywhere.
final personalDetailsStoreProvider = Provider<PersonalDetailsStore>(
  (ref) => PersonalDetailsStore(ref.watch(appDatabaseProvider)),
);

/// One bodyweight the user recorded, and the local calendar date it took
/// effect from.
///
/// **[date] is a calendar date, not a timestamp**, and it is normalised to
/// local midnight on the way in. `CLAUDE.md` is explicit about the distinction:
/// a weight recorded at 11pm must land on the day the user was looking at, and
/// a value that round-trips through UTC does not. Keeping the normalisation in
/// the constructor means no caller can build an entry with a time-of-day on it.
@immutable
class BodyweightEntry {
  BodyweightEntry({required DateTime date, required this.weightKg})
      : date = DateTime(date.year, date.month, date.day);

  /// The local calendar day this weight took effect from, at local midnight.
  final DateTime date;

  /// Kilograms. `docs/04` picks one unit for V1 and offers no toggle.
  final double weightKg;

  @override
  bool operator ==(Object other) =>
      other is BodyweightEntry &&
      other.date == date &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(date, weightKg);

  @override
  String toString() => 'BodyweightEntry(${encodeCalendarDate(date)}, $weightKg)';
}

/// The bodyweight series the app started with, resolved **before the first
/// frame**.
///
/// **This exists to be overridden, and `main()` is what overrides it** — the
/// same shape, and the same reasoning, as `initialTemplateFilterProvider`. An
/// `AsyncNotifier` reading the table in `build()` resolves a frame or more
/// after the tree first builds, so every surface carrying the calorie estimate
/// would render the "add your weight" prompt and then swap it for a number on
/// every cold start. That prompt is a real state for a user who has never
/// weighed in (`docs/04`), which is precisely why flashing it at a user who has
/// is not a cosmetic glitch: it says something false.
///
/// The default here — an empty series — is what a test, or a missed override,
/// gets, and it is also the honest state of a fresh install.
final initialBodyweightLogProvider = Provider<List<BodyweightEntry>>(
  (ref) => const <BodyweightEntry>[],
);

/// Reads the stored series into domain entries, oldest first.
///
/// Called once from `main()` before `runApp`. No fallback is needed: unlike a
/// filter key there is no vocabulary to fail to recognise, and an empty table
/// is the ordinary first-launch answer rather than an error.
Future<List<BodyweightEntry>> readStoredBodyweightLog(
  PersonalDetailsStore store,
) async {
  final rows = await store.readBodyweightEntries();
  return rows
      .map((row) => BodyweightEntry(
            date: decodeCalendarDate(row.date),
            weightKg: row.weightKg,
          ))
      .toList(growable: false);
}

/// Every bodyweight the user has recorded, oldest first.
///
/// **A `Notifier`, not an `AsyncNotifier`** — see [initialBodyweightLogProvider]
/// for why the read happens before the tree builds rather than inside it. And
/// not a `StateProvider`, which is legacy on Riverpod 3 (see
/// `lib/src/ui/tab_index.dart`).
///
/// **The whole series is the state, not the latest weight.** Storing only the
/// current number would make the calorie estimate on a session logged in March
/// move when the user weighs in again in June — a derived value silently
/// rewriting history, which is what `app_database.dart` explains this table
/// exists to stop. Anything that wants "the weight in effect on a date" reads
/// it out of this list.
///
/// **The only mutation is [record], and it takes no date.** KD5: entries are
/// immutable, take effect from the day they are recorded, and cannot be
/// backdated. A `record(date, weight)` would make backdating a one-argument
/// mistake, so the signature does not offer it.
class BodyweightLog extends Notifier<List<BodyweightEntry>> {
  @override
  List<BodyweightEntry> build() => ref.read(initialBodyweightLogProvider);

  /// Records [weightKg] as the weight in effect from today.
  ///
  /// Recording twice in one day replaces today's entry rather than adding a
  /// second — the user correcting a typo, which is the only correction the
  /// immutability rule allows because today's sessions are not yet history.
  ///
  /// The write is not skipped when the weight is unchanged: re-entering the
  /// same number on a later day is a real weigh-in, and swallowing it would
  /// leave the series claiming the user has not weighed in since.
  Future<void> record(double weightKg) async {
    assert(
      weightKg > 0 && weightKg.isFinite,
      'a bodyweight is an unsigned positive number, got $weightKg',
    );

    final today = todayLocal();
    await ref
        .read(personalDetailsStoreProvider)
        .appendBodyweightEntry(encodeCalendarDate(today), weightKg);

    // Today is by construction the latest date in the series, so dropping any
    // entry already on today and appending keeps the oldest-first order the
    // store returns without a re-sort.
    state = <BodyweightEntry>[
      ...state.where((entry) => entry.date != today),
      BodyweightEntry(date: today, weightKg: weightKg),
    ];
  }
}

/// The bodyweight series. Named for the thing, matching `tabIndexProvider`.
final bodyweightLogProvider =
    NotifierProvider<BodyweightLog, List<BodyweightEntry>>(
  BodyweightLog.new,
);
