/// Answers one question: which bodyweight was in effect on a given calendar
/// day, or none at all.
///
/// **This is the rule the bodyweight table exists to make expressible.** A
/// session's calorie estimate is derived on read (`CLAUDE.md` §Nothing is
/// stored that can be derived), so the weight it is derived *from* has to be
/// pinned to the session's own `performedOn` — not to the newest number on
/// record. Resolve it the newest-first way and every session already logged
/// silently re-prices itself the next time the user steps on a scale, which is
/// the exact bug this file is the fix for.
///
/// **It takes the series as an argument rather than reading a provider.** The
/// rule is pure date arithmetic and nothing about it needs Riverpod, a
/// database, or a widget tree, so keeping it a plain function makes it provable
/// against hand-built lists — including the property-style check in
/// `test/bodyweight_resolution_test.dart` that no legal sequence of writes can
/// change an already-resolved date. [weightInEffectProvider] at the bottom is
/// the thin wrapper that binds it to the live series; a call site that has a
/// `ref` uses that and never re-implements the walk.
///
/// **Nothing here is wired to a calorie estimate yet, on purpose** (KTD6). The
/// session tables — `Session`, `SessionExercise`, `SetEntry` — are build-order
/// step 2 and are not in this checkout (`app_database.dart` reserves schema
/// version 2 for them). Until they land there is no `performedOn` to resolve
/// against and no `caloriesFor` to call this from; the rule is testable against
/// dates alone, so it ships proven and the call site is a one-liner when the
/// tables arrive.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'personal_details_store.dart';

/// The bodyweight in effect on [date], or null when the user had not yet
/// weighed in.
///
/// [series] is every recorded entry — the order `PersonalDetailsStore
/// .readBodyweightEntries` and `BodyweightLog` both keep is oldest first, but
/// this does not rely on it: it scans for the latest qualifying entry instead
/// of walking backwards from the end. That costs nothing at this size (one row
/// per weigh-in) and means a caller that reversed the list to render a history
/// screen cannot accidentally change what a session's calories are computed
/// from.
///
/// **Null is an answer, not a failure, and it is permanent** (KD3). A date
/// earlier than every entry resolves to nothing, and the caller shows the
/// add-weight prompt rather than a number. Do *not* soften this to "fall back
/// to the earliest entry": that is the back-fill the user explicitly rejected —
/// `docs/01-app-idea.md` §257 had already chosen a prompt over a wrong number —
/// and it would invent a weight for a session logged before the user ever told
/// us one. Because KD5 makes entries immutable and un-backdatable, a date that
/// resolves to null today resolves to null forever, which is what makes the
/// prompt honest rather than a temporary gap.
///
/// [date] may carry a time of day; only its calendar fields are read. That is
/// the same distinction `BodyweightEntry` draws in its constructor, and it
/// matters for the same reason: an 11pm session must resolve against its own
/// day, not slip either side of midnight.
BodyweightEntry? weightInEffectOn(List<BodyweightEntry> series, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);

  BodyweightEntry? inEffect;
  for (final entry in series) {
    // An entry takes effect *from* its own day (KD5), so the day itself counts
    // as covered -- `isAfter` rather than a comparison that excludes it.
    if (entry.date.isAfter(day)) continue;
    // Strictly later, so that two entries sharing a date (impossible in stored
    // data -- the date is the table's primary key -- but expressible in an
    // in-memory list) resolve deterministically to the first of them.
    if (inEffect == null || entry.date.isAfter(inEffect.date)) {
      inEffect = entry;
    }
  }
  return inEffect;
}

/// Resolves a date against the bodyweight series the app is currently holding.
///
/// **A function-valued provider rather than a `family` keyed on the date.** A
/// family would cache one provider per date asked about, and the caller asking
/// is a history or summary screen walking a list of sessions — an unbounded set
/// of keys, each holding a subscription, for a computation that is a single
/// list scan. Handing back one resolver lets a screen resolve every row it is
/// building from one `watch`, and the resolver is rebuilt whenever
/// [bodyweightLogProvider] changes, so a new weigh-in re-resolves the dates it
/// actually affects.
///
/// It resolves, and it stops there: turning an entry into a calorie figure
/// belongs to the session layer that does not exist yet (see the library
/// comment above).
final weightInEffectProvider = Provider<BodyweightEntry? Function(DateTime)>(
  (ref) {
    final series = ref.watch(bodyweightLogProvider);
    return (date) => weightInEffectOn(series, date);
  },
);
