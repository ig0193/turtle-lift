import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'divider_row.dart';
import 'equipment_exercise_list_screen.dart';
import 'exercise_detail_screen.dart';
import 'muscle_exercise_list_screen.dart';
import 'muscle_search_field.dart';
import 'sub_group_row.dart';

/// Which vocabulary a result came from.
///
/// **Three kinds, stated on every row, because the words overlap** (R12).
/// "kettlebell" is an equipment value *and* the first word of twelve exercise
/// names; "Lats" is a muscle and "Lat pulldown" is not. The three lead to
/// three different screens, so a row that only shows a name is asking the
/// reader to guess which one they are about to open.
enum SearchResultKind {
  /// One of the 260 exercises. Opens its page.
  exercise('Exercise'),

  /// One of the 19 sub-muscle groups. Opens its exercise list.
  muscle('Muscle'),

  /// One of the equipment values the library uses. Opens that list.
  equipment('Equipment');

  const SearchResultKind(this.label);

  /// How the kind is said out loud, for the row's semantics.
  final String label;

  /// How the kind is written on the row.
  ///
  /// Upper-cased here rather than stored that way, for the reason
  /// [exerciseEquipmentLabel] gives: the tag is a chip, the label is a word,
  /// and a screen reader should hear the word.
  String get tag => label.toUpperCase();
}

/// One row of results: what it is, which vocabulary it came from, and enough
/// of an id to open it with.
///
/// **The [Exercise] is carried whole on an exercise result**, because
/// `ExerciseDetailScreen` takes one — looking it back up by [id] would add a
/// second place the id could miss, for nothing.
@immutable
class MuscleSearchResult {
  const MuscleSearchResult({
    required this.kind,
    required this.id,
    required this.label,
    required this.subtitle,
    this.exercise,
  });

  final SearchResultKind kind;

  /// The exercise id, the `group/sub` id, or the equipment value — whichever
  /// [kind] says, and what [open] routes on.
  final String id;

  /// The display name: the library's spelling, the taxonomy's label, or the
  /// equipment value written as a name.
  final String label;

  /// The second line: a count for a category, the equipment for an exercise.
  final String subtitle;

  /// Non-null exactly when [kind] is [SearchResultKind.exercise].
  final Exercise? exercise;

  /// Opens what this result stands for (R13).
  ///
  /// **The routing lives on the result rather than in the row's `onTap`**, so
  /// that "which kind is this" is answered once. A switch at the call site
  /// would have to be repeated by every future caller of the row — and the
  /// fallback list already is one.
  Future<void> open(BuildContext context) => switch (kind) {
        SearchResultKind.exercise => pushExerciseDetail(context, exercise!),
        SearchResultKind.muscle => pushMuscleExerciseList(context, id),
        SearchResultKind.equipment => pushEquipmentExerciseList(context, id),
      };
}

/// Everything [query] matches, across all three vocabularies (R11).
///
/// **Categories first, exercises last.** A query like "kettlebell" matches one
/// equipment value and twelve exercise names; reading the library first would
/// push the route to *all* kettlebell work — including the six lifts not named
/// after it — below the fold, which is the one result the user could not have
/// found any other way.
///
/// **Sub-group *labels*, not ids** (R11). The ids are internal keys and a user
/// never sees one: matching them would make "back" return three rows, for
/// `back/lats`, `back/upper` and `back/lower`, while the visible label of one
/// of them does not contain the word at all.
///
/// **Uncapped.** The prototype slices exercise hits to 30; a cap silently
/// hides a match from someone who typed enough letters to find it, and the
/// results are rendered by a lazy `ListView` that never builds the rows nobody
/// scrolled to.
///
/// **Unranked, and deliberately so.** The prototype sorts the hits the user
/// has logged to the top. There is no session table in this slice, so that
/// ordering could only be invented — and `CLAUDE.md` puts the personal layer
/// after this tab. Each vocabulary keeps its own order instead: the taxonomy's
/// body order, the sorted equipment values, and the library's own order.
///
/// A blank query matches nothing, which is what puts the screen on its
/// fallback rather than on a list of all 260 names.
List<MuscleSearchResult> muscleSearchResults(
  ExerciseIndex index,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const <MuscleSearchResult>[];

  return <MuscleSearchResult>[
    for (final group in kSubMuscleGroups.values)
      if (group.label.toLowerCase().contains(needle))
        muscleResult(index, group.id),
    for (final value in index.equipmentValues)
      if (value.contains(needle)) equipmentResult(index, value),
    for (final exercise in index.searchByName(needle))
      MuscleSearchResult(
        kind: SearchResultKind.exercise,
        id: exercise.id,
        label: exercise.name,
        subtitle: exerciseEquipmentLabel(exercise.equipment),
        exercise: exercise,
      ),
  ];
}

/// The result standing for one sub-muscle group.
MuscleSearchResult muscleResult(ExerciseIndex index, String subGroupId) =>
    MuscleSearchResult(
      kind: SearchResultKind.muscle,
      id: subGroupId,
      label: MuscleExerciseListScreen.titleFor(subGroupId),
      subtitle: searchResultCountLine(index.withPrimary(subGroupId).length),
    );

/// The result standing for one equipment value.
MuscleSearchResult equipmentResult(ExerciseIndex index, String equipment) =>
    MuscleSearchResult(
      kind: SearchResultKind.equipment,
      id: equipment,
      label: EquipmentExerciseListScreen.titleFor(equipment),
      subtitle: searchResultCountLine(index.withEquipment(equipment).length),
    );

/// The second line on a category row: how many exercises are behind it.
///
/// Worded exactly as `SubGroupRow` words its own count — the same function, in
/// fact — because on the fallback screen the two kinds of row sit under each
/// other.
String searchResultCountLine(int count) => exerciseCountLabel(count);

/// Where the landing's search field lands.
///
/// **One field over three vocabularies** (R11): the 260 exercise names, the 19
/// sub-group labels and the equipment values the library uses. A user standing
/// in a gym knows one of three things — the lift, the muscle, or what is free
/// — and three separate search boxes would ask them to classify their own
/// question before typing it.
///
/// **It never returns an empty screen** (R14). When nothing matches, the full
/// sub-group list and the full equipment list render under their own headings:
/// the same content the landing carries, so a failed search is somewhere to go
/// rather than a dead end with a keyboard over it. The prototype's fallback
/// shows only muscles; R14 names both, and both are cheap to render.
///
/// **The rows under an empty query are not a "recent" or "suggested" list.**
/// They are that same index — there is no session table to draw a recent list
/// from, and inventing one is exactly what this slice does not do.
class MuscleSearchScreen extends ConsumerStatefulWidget {
  const MuscleSearchScreen({super.key});

  @override
  ConsumerState<MuscleSearchScreen> createState() => _MuscleSearchScreenState();
}

class _MuscleSearchScreenState extends ConsumerState<MuscleSearchScreen> {
  /// Owned here rather than left to the `TextField`'s own, because the query is
  /// read back to match on it.
  final TextEditingController _controller = TextEditingController();

  /// What has been typed.
  ///
  /// **Held as state rather than read off [_controller] in `build`**, so that
  /// the rebuild is driven by the change itself: a controller read during build
  /// renders whatever the field happened to hold at that moment, and nothing
  /// schedules the frame in which it changed.
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(exerciseIndexProvider);
    final results = muscleSearchResults(index, _query);

    return AppScreen.pushed(
      title: 'Search',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 4),
          MuscleSearchField.editable(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 14),
          if (results.isNotEmpty)
            for (final result in results)
              SearchResultRow(
                key: searchResultKey(result.kind, result.id),
                result: result,
              )
          else
            _SearchFallback(index: index, query: _query),
        ],
      ),
    );
  }
}

/// The row for a result, so a test can reach one by kind and id rather than by
/// position in a list that changes with every keystroke.
@visibleForTesting
Key searchResultKey(SearchResultKind kind, String id) =>
    ValueKey<String>('search-${kind.name}-$id');

/// Said over the fallback's muscle list.
const String kSearchMusclesHeading = 'MUSCLES';

/// Said over the fallback's equipment list.
const String kSearchEquipmentHeading = 'EQUIPMENT';

/// Said above both, when a query failed.
///
/// **It names the query back.** Without it the two full lists read as results
/// for what was typed, and a user who mistyped "kettlebel" would conclude the
/// app thinks that is a muscle.
String noSearchMatchNote(String query) => 'Nothing matches “${query.trim()}”.';

/// What a query with no matches falls through to, and what an untouched field
/// opens on (R14).
///
/// **Both lists, each headed.** Muscles alone — the prototype's fallback —
/// would be a screen answering a question about equipment with a list of body
/// parts. The equipment list is 8 rows.
///
/// **The 19 rows are `subGroupRows`, the same function the landing calls**, so
/// the two screens cannot drift apart (R8).
class _SearchFallback extends StatelessWidget {
  const _SearchFallback({required this.index, required this.query});

  final ExerciseIndex index;

  /// Empty when nothing has been typed yet, which is the one case with nothing
  /// to apologise for.
  final String query;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (query.trim().isNotEmpty) ...<Widget>[
          Text(noSearchMatchNote(query), style: kNoSearchMatchStyle),
          const SizedBox(height: 16),
        ],
        Semantics(
          header: true,
          child: Text(kSearchMusclesHeading, style: kLandingSectionLabelStyle),
        ),
        const SizedBox(height: 9),
        ...subGroupRows(
          index: index,
          onSelected: (subGroupId) =>
              pushMuscleExerciseList(context, subGroupId),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            kSearchEquipmentHeading,
            style: kLandingSectionLabelStyle,
          ),
        ),
        const SizedBox(height: 9),
        for (final value in index.equipmentValues)
          SearchResultRow(
            key: searchResultKey(SearchResultKind.equipment, value),
            result: equipmentResult(index, value),
            // The heading directly above says EQUIPMENT for all 8 of these; a
            // tag repeating it on every row would be noise, and these are not
            // results of a match in the first place.
            showKind: false,
          ),
      ],
    );
  }
}

/// One result: its name, which vocabulary it came from, a second line, and a
/// chevron.
///
/// **The same divider row as `SubGroupRow` and `ExerciseRow`** — the
/// prototype's `.row`, and the pattern underneath is `template_row.dart`'s: the
/// semantics wrapper, the opaque gesture box, the 48pt floor, the trailing
/// chevron. Neither of those two rows could be reused as-is: this one carries a
/// tag beside the name, and it has to serve all three kinds without the reader
/// having to notice that muscles are rendered by one widget and equipment by
/// another.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    required this.result,
    this.showKind = true,
    super.key,
  });

  final MuscleSearchResult result;

  /// Whether the kind tag is drawn.
  ///
  /// True everywhere R12 applies — every row in a result list. False only on
  /// the fallback's equipment rows, which sit under a heading that has already
  /// said it.
  final bool showKind;

  /// The minimum row height, matching [SubGroupRow.minHeight] and the app's
  /// other tap targets.
  static const double minHeight = DividerRow.minHeight;

  @override
  Widget build(BuildContext context) {
    return DividerRow(
      // The kind is said even when the tag is not drawn: a heading two rows up
      // is a visual grouping a screen reader moving row by row does not carry
      // with it.
      semanticsLabel:
          '${result.label}. ${result.kind.label}. ${result.subtitle}',
      onTap: () => result.open(context),
      children: <Widget>[
        Row(
          children: <Widget>[
            // Flexible, not Expanded: a short name must not push the tag out
            // to the far edge, where it would read as a column of its own
            // rather than as part of the name.
            Flexible(
              child: Text(
                result.label,
                style: kExerciseRowNameStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showKind) ...<Widget>[
              const SizedBox(width: 7),
              // The prototype's `.kind` chip, which is deliberately the same
              // muted pill the equipment chip on an exercise row is: both are
              // a fact about the row rather than a state of it.
              RowTagChip(label: result.kind.tag),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          result.subtitle,
          style: kSubGroupRowCountStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The apology over the fallback. Quieter than a row, because it explains the
/// screen rather than being part of it — the same weight as the landing's map
/// hint.
const TextStyle kNoSearchMatchStyle = TextStyle(
  fontSize: 12,
  color: AppPalette.textSecondary,
);
