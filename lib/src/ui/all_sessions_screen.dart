import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_index.dart' show searchFold;
import '../data/generated/muscle_taxonomy.dart';
import '../data/history_preview_data.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'empty_state.dart';
import 'history_session_row.dart';
import 'muscle_exercise_list_screen.dart' show EquipmentChip;

/// Every workout, newest first, grouped by month, with search and a muscle
/// filter (audit #11).
///
/// **Reached from [HistoryRoot]'s "See all N workouts", never a tab root.**
///
/// **Find, not scroll.** Search matches the title, the exercise names and
/// each exercise's note (folded like the exercise picker: case, hyphens and
/// apostrophes forgiven); the chips keep workouts that trained a muscle group
/// directly. Both are held in memory only, and an empty result says so.
///
/// **Built lazily** (`ListView.builder`, audit B16): a thousand workouts
/// build only the rows on screen. Month headings carry their count.
class AllSessionsScreen extends ConsumerStatefulWidget {
  const AllSessionsScreen({super.key});

  /// Finds one session's row.
  @visibleForTesting
  static Key rowKey(String sessionId) =>
      ValueKey<String>('all-sessions-$sessionId');

  /// Finds a month heading.
  @visibleForTesting
  static Key monthKey(String label) =>
      ValueKey<String>('all-sessions-month-$label');

  /// The search field.
  @visibleForTesting
  static const Key searchKey = ValueKey<String>('all-sessions-search');

  /// A muscle-group filter chip.
  @visibleForTesting
  static Key muscleKey(String groupId) =>
      ValueKey<String>('all-sessions-muscle-$groupId');

  @override
  ConsumerState<AllSessionsScreen> createState() => _AllSessionsScreenState();
}

class _AllSessionsScreenState extends ConsumerState<AllSessionsScreen> {
  final TextEditingController _query = TextEditingController();
  String? _group;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(HistorySession session, HistoryRowFigures figures) {
    if (_group != null && !figures.trainedGroupIds.contains(_group)) {
      return false;
    }
    final needle = searchFold(_query.text).trim();
    if (needle.isEmpty) return true;
    final haystack = searchFold(<String>[
      resolvedTitle(session, figures),
      for (final e in session.exercises) ...<String>[e.name, ?e.note],
    ].join(' '));
    return needle.split(' ').where((w) => w.isNotEmpty).every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(historySessionsNewestFirstProvider);
    final figures = ref.watch(historyProjectionProvider);

    if (sessions.isEmpty) {
      return AppScreen.pushed(
        title: 'All workouts',
        body: ListView(
          padding: screenScrollPadding(context),
          children: const <Widget>[
            EmptyState(
              glyph: EmptyStateGlyph.logbook,
              heading: 'No workouts yet',
              body: "Finish your first workout and it'll show up here.",
            ),
          ],
        ),
      );
    }

    // Groups that appear in the history, in taxonomy order: a chip for a
    // muscle never trained would always filter to nothing.
    final trained = <String>{
      for (final s in sessions) ...figures[s.id]!.trainedGroupIds,
    };
    final groups = <String>[
      for (final id in kMuscleTaxonomy.keys)
        if (trained.contains(id)) id,
    ];

    final visible = <HistorySession>[
      for (final s in sessions)
        if (_matches(s, figures[s.id]!)) s,
    ];

    // Flattened into headings and rows once, then built lazily.
    final counts = <String, int>{};
    for (final s in visible) {
      final m = monthYearLabel(s.performedOn);
      counts[m] = (counts[m] ?? 0) + 1;
    }
    final items = <Object>[];
    String? lastMonth;
    for (final s in visible) {
      final m = monthYearLabel(s.performedOn);
      if (m != lastMonth) {
        items.add(m);
        lastMonth = m;
      }
      items.add(s);
    }

    final header = <Widget>[
      _SearchField(
        controller: _query,
        onChanged: (_) => setState(() {}),
      ),
      if (groups.length > 1) ...<Widget>[
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              for (final id in groups) ...<Widget>[
                EquipmentChip(
                  key: AllSessionsScreen.muscleKey(id),
                  label: kMuscleGroupLabels[id] ?? id,
                  selected: _group == id,
                  onTap: () =>
                      setState(() => _group = _group == id ? null : id),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 8),
      if (visible.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No workouts match.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppPalette.textMuted),
          ),
        ),
    ];

    return AppScreen.pushed(
      title: 'All workouts',
      body: ListView.builder(
        padding: screenScrollPadding(context),
        itemCount: header.length + items.length,
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          final item = items[i - header.length];
          if (item is String) {
            final n = counts[item]!;
            final label = '$item · $n workout${n == 1 ? '' : 's'}';
            return HistoryMonthLabel(
              key: AllSessionsScreen.monthKey(item),
              label: label,
              first: i == header.length,
            );
          }
          final session = item as HistorySession;
          return HistorySessionRow(
            key: AllSessionsScreen.rowKey(session.id),
            session: session,
            figures: figures[session.id]!,
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search workouts',
      textField: true,
      child: TextField(
        key: AllSessionsScreen.searchKey,
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: const TextStyle(fontSize: 15, color: AppPalette.textPrimary),
        decoration: InputDecoration(
          hintText: 'Exercise, title or note',
          hintStyle: const TextStyle(fontSize: 15, color: AppPalette.textMuted),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: AppPalette.textMuted),
          suffixIcon: controller.text.isEmpty
              ? null
              : Semantics(
                  button: true,
                  label: 'Clear search',
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppPalette.textMuted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
                ),
          filled: true,
          fillColor: AppPalette.surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.textSecondary),
          ),
        ),
      ),
    );
  }
}
