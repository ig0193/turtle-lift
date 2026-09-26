import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/routine_store.dart';
import '../data/routines.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'destructive_confirmation.dart';
import 'session_date_control.dart';
import 'session_summary_screen.dart';

/// The step between Finish and the summary.
///
/// **It is a confirmation, not a form.** Everything on it is optional: the
/// title has a fallback chain (`00` §6), the note may stay empty, and the date
/// is already right for all but a retrospective log. Nothing here gates saving,
/// which is why `Save` is in the header and not at the bottom behind the
/// fields.
///
/// **What is deliberately absent**, all from Hevy's version of this screen and
/// all needing an account or a network: a photo, a gym, a visibility setting, a
/// share sheet. See `CLAUDE.md`'s out-of-scope list.
class SaveWorkoutScreen extends ConsumerStatefulWidget {
  const SaveWorkoutScreen({super.key});

  static const Key saveKey = ValueKey<String>('save-workout');
  static const Key discardKey = ValueKey<String>('save-discard');
  static const Key notesKey = ValueKey<String>('save-notes');
  static const Key titleKey = ValueKey<String>('save-title');
  static const Key updateRoutineKey = ValueKey<String>('save-update-routine');

  @override
  ConsumerState<SaveWorkoutScreen> createState() => _SaveWorkoutScreenState();
}

class _SaveWorkoutScreenState extends ConsumerState<SaveWorkoutScreen> {
  late final TextEditingController _title;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final session = ref.read(activeSessionProvider);
    _title = TextEditingController(text: session?.title ?? '');
    _notes = TextEditingController(text: session?.notes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final elapsed = elapsedOf(session, DateTime.now());

    return AppScreen.pushed(
      title: 'Save workout',
      actions: <Widget>[
        TextButton(
          key: SaveWorkoutScreen.saveKey,
          onPressed: () => _save(context, session),
          child: const Text('Save',
              style: TextStyle(
                  color: AppPalette.accentLight, fontWeight: FontWeight.w600)),
        ),
      ],
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: AppMetrics.gapSnug),
          // **The three facts, as a card.** They were a bare row wedged under
          // an oversized placeholder, reading as debris. Given a surface they
          // become the summary of what is about to be filed.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppMetrics.gapCard, vertical: AppMetrics.gapCard),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(AppMetrics.radiusCard),
            ),
            child: Row(
              children: <Widget>[
                if (elapsed != null)
                  _Stat(
                      label: 'Duration',
                      value: formatDuration(elapsed.inSeconds)),
                _Stat(
                    label: 'Volume',
                    value: '${formatWeight(volumeOf(session))} kg'),
                _Stat(label: 'Sets', value: '${setCountOf(session)}'),
              ],
            ),
          ),
          const SizedBox(height: AppMetrics.gapSection),
          const _FieldLabel('WORKOUT NAME'),
          TextField(
            key: SaveWorkoutScreen.titleKey,
            controller: _title,
            maxLength: 40,
            style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600),
            decoration: _fieldDecoration(
              // A real hint, not a 22pt placeholder pretending to be a title.
              // The name is optional and resolves on read (`00` §6), so the
              // hint says what happens if it is left alone.
              hint: 'Optional — named from its muscles if left blank',
            ),
          ),
          const SizedBox(height: AppMetrics.gapSection),
          const _FieldLabel('HOW DID IT GO?'),
          TextField(
            key: SaveWorkoutScreen.notesKey,
            controller: _notes,
            maxLines: null,
            minLines: 3,
            style: const TextStyle(
                color: AppPalette.textSecondary, fontSize: 15, height: 1.4),
            decoration: _fieldDecoration(hint: 'Optional notes'),
          ),
          const SizedBox(height: AppMetrics.gapSection),
          const _FieldLabel('DATE'),
          // Retrospective logging is first-class, and the date is the one field
          // here that is wrong in a way the user cannot fix later without
          // hunting for it.
          const Align(
            alignment: Alignment.centerLeft,
            child: SessionDateControl(),
          ),
          const SizedBox(height: AppMetrics.gapBlock),
          Center(
            child: TextButton(
              key: SaveWorkoutScreen.discardKey,
              onPressed: () => _discard(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppMetrics.touchTarget),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppMetrics.gapCard),
              ),
              child: const Text('Discard workout',
                  style: TextStyle(
                      color: AppPalette.danger, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: AppMetrics.gapSection),
        ],
      ),
    );
  }

  /// One field decoration for the screen, so the two inputs cannot drift.
  static InputDecoration _fieldDecoration({required String hint}) =>
      InputDecoration(
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: AppPalette.mutedSurface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppMetrics.gap, vertical: AppMetrics.gap),
        hintText: hint,
        hintStyle: const TextStyle(color: AppPalette.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusField),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusField),
          borderSide:
              const BorderSide(color: AppPalette.accentStrong, width: 1.5),
        ),
      );

  Future<void> _save(BuildContext context, WorkoutSession session) async {
    final notifier = ref.read(activeSessionProvider.notifier);
    final id = session.id;
    // `00` §9: a session with no completed sets is not filed. `saveOpenSession`
    // enforces that itself — this is only the courtesy of asking first when the
    // user typed values and never ticked them, so work does not vanish on a
    // press they thought meant "keep it".
    final hadSets = setCountOf(session) > 0;
    if (!hadSets && session.hasAnyWrittenSets) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Nothing completed',
        message: 'This workout has values typed but no sets ticked, so there '
            'is nothing to save. Discard it?',
        confirmLabel: 'Discard',
      );
      if (!confirmed) return;
    }

    await notifier.rename(_title.text.trim().isEmpty ? null : _title.text.trim());
    await notifier.setSessionNotes(_notes.text);
    await notifier.finish();

    if (!context.mounted) return;
    await _offerRoutineUpdate(context, session);

    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (hadSets) pushSessionSummary(context, id, celebrate: true);
  }

  /// Asks whether the routine should learn from what was actually done.
  ///
  /// **Only when the shape changed**, per `routineDiverges` — not after every
  /// session. A question that appears every time is a question that gets
  /// dismissed without reading, and this one rewrites a thing the user built.
  ///
  /// **Keep is the quiet default**: doing nothing leaves the routine as it was,
  /// so the destructive reading of the two answers is the one that takes a
  /// deliberate tap.
  Future<void> _offerRoutineUpdate(
    BuildContext context,
    WorkoutSession session,
  ) async {
    final routineId = session.routineId;
    if (routineId == null) return;
    final routine =
        ref.read(routinesProvider).where((r) => r.id == routineId).firstOrNull;
    if (routine == null) return;
    if (!routineDiverges(routine, session)) return;

    final update = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Update ${routine.name}?',
            style: const TextStyle(color: AppPalette.textPrimary)),
        content: const Text(
          'This workout no longer matches the routine. Update the routine to '
          'what you just did, or keep it as it is.',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep routine',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
          TextButton(
            key: SaveWorkoutScreen.updateRoutineKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update routine',
                style: TextStyle(color: AppPalette.accentLight)),
          ),
        ],
      ),
    );
    if (update ?? false) {
      await ref
          .read(routineListProvider.notifier)
          .updateFromSession(routineId, session);
    }
  }

  Future<void> _discard(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Discard workout?',
      message: 'Everything logged in this session is permanently deleted.',
      confirmLabel: 'Discard',
    );
    if (!confirmed) return;
    await ref.read(activeSessionProvider.notifier).discard();
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// A section label. **Visible, not a placeholder.** A field whose only label
/// is its own hint text loses that label the moment the user types.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppMetrics.gapLabel),
        child: Text(text,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            )),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label,
                style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11,
                    letterSpacing: 0.3)),
            const SizedBox(height: AppMetrics.gapTight),
            Text(value,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                )),
          ],
        ),
      );
}
