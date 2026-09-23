import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/active_session.dart';
import '../data/derived.dart';
import '../data/session_store.dart';
import '../data/set_format.dart';
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
          TextField(
            key: SaveWorkoutScreen.titleKey,
            controller: _title,
            maxLength: 40,
            style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: 'Workout title',
              hintStyle: TextStyle(color: AppPalette.textMuted, fontSize: 22),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (elapsed != null)
                _Stat(label: 'Duration', value: formatDuration(elapsed.inSeconds)),
              _Stat(
                  label: 'Volume',
                  value: '${formatWeight(volumeOf(session))} kg'),
              _Stat(label: 'Sets', value: '${setCountOf(session)}'),
            ],
          ),
          const Divider(color: AppPalette.border, height: 32),
          TextField(
            key: SaveWorkoutScreen.notesKey,
            controller: _notes,
            maxLines: null,
            minLines: 3,
            style: const TextStyle(color: AppPalette.textSecondary),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'How did your workout go? Leave some notes here…',
              hintStyle: TextStyle(color: AppPalette.textMuted),
            ),
          ),
          const Divider(color: AppPalette.border, height: 32),
          // The same control the overview carries, because retrospective
          // logging is first-class and the date is the one field here that can
          // be wrong in a way the user cannot fix later without hunting.
          const SessionDateControl(),
          const SizedBox(height: 28),
          TextButton(
            key: SaveWorkoutScreen.discardKey,
            onPressed: () => _discard(context),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Discard workout',
                style: TextStyle(color: AppPalette.danger)),
          ),
        ],
      ),
    );
  }

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
    Navigator.of(context).pop();
    if (hadSets) pushSessionSummary(context, id, celebrate: true);
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
                style:
                    const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
