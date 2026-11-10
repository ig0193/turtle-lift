import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/active_session.dart' show savedSessionsProvider;
import '../data/body_gender.dart';
import '../data/date_labels.dart';
import '../data/derived.dart';
import '../data/exercise_index.dart';
import '../data/generated/muscle_taxonomy.dart';
import '../data/history_preview_data.dart' show sessionRecordsProvider;
import '../data/personal_best.dart';
import '../data/personal_details_store.dart' show bodyweightLogProvider;
import '../data/session_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'body_diagram.dart';
import 'exercise_detail_screen.dart' show MuscleFill;

/// **The** card for a saved workout: the summary a finished workout lands on,
/// the top of its History detail, and the image Share sends.
///
/// `docs/04`: session detail "is the same component as the live workout
/// card". There used to be two cards that disagreed on the muscles (the
/// detail painted whole parent groups, so a Push day lit the rear delt), on
/// labels (*Streak* / *Day streak*), on the date and on kcal against PB
/// (audit B3). Now there is one, and every figure on it is derived here from
/// the saved rows by the same functions:
///
/// * muscles: [workedSubGroups], primaries amber and secondaries steel;
/// * streak: [streakAsOf] on the workout's own day;
/// * kcal: [caloriesFor] with the weight in effect that day;
/// * PB: the cached [sessionRecordsProvider] projection;
/// * title: [resolvedTitle], the one chain;
/// * date: [cardDateLabel], always with the year, because an image outlives
///   the year it was made in.
///
/// On a record day the PB count takes the kcal slot (ADR 0008 §4).
class SessionCard extends ConsumerWidget {
  const SessionCard({required this.session, this.titleField, super.key});

  final WorkoutSession session;

  /// The inline title editor on the editor screen. Null shows the resolved
  /// title as text, which is what the read-only detail does.
  final Widget? titleField;

  /// The streak figure.
  static const Key streakKey = ValueKey<String>('session-streak');

  /// The PB count, present only on a record day.
  static const Key pbKey = ValueKey<String>('pb-pill');

  /// The kcal figure.
  static const Key calorieKey = ValueKey<String>('session-calories');

  /// The note that stands in for kcal when no weight was in effect.
  static const Key addWeightKey = ValueKey<String>('add-weight-prompt');

  /// The kcal explanation.
  static const Key calorieInfoKey = ValueKey<String>('calorie-info');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedSessionsProvider);
    final index = ref.watch(exerciseIndexProvider);
    final weights = ref.watch(bodyweightLogProvider);
    final records =
        (ref.watch(sessionRecordsProvider)[session.id] ?? SessionRecords.none)
            .count;

    final name = resolvedTitle(session, index);
    final worked = workedSubGroups(session, index);
    final views = viewsForMuscles(worked.primary.union(worked.secondary));
    final fill = MuscleFill(primary: worked.primary, secondary: worked.secondary);
    final calories = caloriesFor(session, weights);
    final streak = streakAsOf(session.performedOn, saved);
    final quickLog = isQuickLogSession(session);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            label: spokenDateLabel(session.performedOn) +
                (quickLog ? ', quick log' : ''),
            excludeSemantics: true,
            child: Text(
              cardDateLabel(session.performedOn) +
                  (quickLog ? ' · quick log' : ''),
              style: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
            ),
          ),
          const SizedBox(height: 4),
          titleField ??
              Semantics(
                header: true,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
          const SizedBox(height: 12),
          // Only the views that carry trained muscles; never an empty second
          // diagram beside a filled one. The map is the card's moment, so it
          // takes the card's width and most of its height.
          SizedBox(
            height: 280,
            child: Row(
              children: <Widget>[
                for (final view in views) ...<Widget>[
                  if (view != views.first) const SizedBox(width: 12),
                  Expanded(child: BodyDiagram(view: view, fill: fill.colorFor)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _Stat(value: '${setCountOf(session)}', label: 'Sets'),
              _Stat(value: '${exerciseCountOf(session)}', label: 'Exercises'),
              _Stat(key: streakKey, value: '$streak', label: 'Day streak'),
              // A figure among the figures, in the PB colour. Absent at zero:
              // never "0 PB" on a card built to be screenshotted.
              if (records > 0)
                _Stat(
                  key: pbKey,
                  value: '$records',
                  label: 'PB',
                  valueColor: AppPalette.accentStrong,
                ),
              // On a record day the PB count takes the kcal slot: an estimate
              // with an info icon is the weakest figure on a card meant to be
              // shown, and the record is the strongest.
              if (calories != null && records == 0)
                _CalorieStat(calories: calories),
            ],
          ),
          // A workout logged before the user ever weighed in cannot have an
          // honest estimate, and adding a weight later does not back-fill it.
          // So there is no kcal figure, and the instruction sits under the
          // row rather than in a figure's slot.
          if (calories == null && records == 0) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              key: addWeightKey,
              kNoWeightKcalNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: Text(
              kAppDisplayName.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: AppPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One exercise logged on its own, outside any template.
///
/// The History row's "quick log" tag, worked out from the saved workout so
/// the card and the row say the same thing.
bool isQuickLogSession(WorkoutSession session) =>
    exerciseCountOf(session) == 1 &&
    (session.templateName ?? '').trim().isEmpty;

/// What stands in for the calorie figure when no bodyweight was in effect on
/// the session's day.
const String kNoWeightKcalNote = 'Add your bodyweight in Profile to see kcal';

/// The app's display name, as it appears on a card meant to be posted.
const String kAppDisplayName = 'TurtleLift';

/// Every completed set as one line, `77.5kg × 8 · 75kg × 8`, with the
/// record-setting set the only thing painted amber.
///
/// **Used by the detail log and the editor alike** (audit B3e), so the record
/// set is marked the same way in both. Inside each set the spaces are
/// non-breaking, so a set never wraps mid-token at large text ("95kg ×" over
/// "7", audit B12); the line breaks only between sets.
class SessionSetLine extends StatelessWidget {
  const SessionSetLine({
    required this.exercise,
    required this.recordSetId,
    super.key,
  });

  final SessionExercise exercise;

  /// The set that set a record in this workout, or null.
  final String? recordSetId;

  static const TextStyle _style = TextStyle(
    fontSize: 13,
    color: AppPalette.textSecondary,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var first = true;
    for (final set in exercise.sets) {
      if (!set.completed) continue;
      if (!first) spans.add(const TextSpan(text: ' · '));
      first = false;
      final isRecord = set.id == recordSetId;
      spans.add(TextSpan(
        text: unbreakable(formatSet(exercise.loadType, set)),
        style: isRecord
            ? const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppPalette.accentStrong,
              )
            : null,
      ));
    }
    return Text.rich(TextSpan(style: _style, children: spans));
  }
}

/// [text] with its spaces made non-breaking, so it stays on one line.
String unbreakable(String text) => text.replaceAll(' ', ' ');

/// Which body views to draw for a set of trained muscles.
///
/// Only the views that carry something: never an empty second diagram beside a
/// filled one.
List<BodyView> viewsForMuscles(Set<String> subGroupIds) {
  final views = <BodyView>{};
  for (final id in subGroupIds) {
    for (final placement in kSubMuscleGroups[id]?.segments ??
        const <({String view, String segment})>[]) {
      views.add(placement.view == 'front' ? BodyView.front : BodyView.back);
    }
  }
  if (views.isEmpty) return <BodyView>[BodyView.front];
  return BodyView.values.where(views.contains).toList(growable: false);
}

/// Shares a rendered card image. A provider so a test can see what would be
/// shared without a platform share sheet.
typedef CardImageSharer = Future<void> Function(
  Uint8List png, {
  required String fileName,
  Rect? origin,
});

final cardImageSharerProvider =
    Provider<CardImageSharer>((ref) => shareCardImage);

/// The image's file name: the workout's name, made safe for a file system.
String cardImageFileName(String name) {
  final safe = name
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '')
      .toLowerCase();
  return '${safe.isEmpty ? 'workout' : safe}.png';
}

/// Writes [png] to the temporary directory and opens the system share sheet
/// on it, the same route Export takes (`share_plus`, `path_provider`).
Future<void> shareCardImage(
  Uint8List png, {
  required String fileName,
  Rect? origin,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(png, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'image/png')],
      sharePositionOrigin: origin,
    ),
  );
}

/// Renders the card under [boundaryKey] to a PNG and hands it to the share
/// sheet. **The card as it is on screen, nothing added and nothing stored**;
/// the image lives in the temporary directory only for the share sheet.
///
/// Shared by the summary's Share card and the History detail's header share,
/// so both send exactly the same image.
Future<void> shareSessionCard(
  BuildContext context,
  WidgetRef ref, {
  required GlobalKey boundaryKey,
  required String name,
}) async {
  FocusScope.of(context).unfocus();
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final ratio = MediaQuery.devicePixelRatioOf(context).clamp(2.0, 3.0);
  final image = await boundary.toImage(pixelRatio: ratio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null || !context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await ref.read(cardImageSharerProvider)(
    data.buffer.asUint8List(),
    fileName: cardImageFileName(name),
    origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.valueColor = AppPalette.textPrimary,
    super.key,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: valueColor,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            // One line at any text size: "Day streak" wrapped at the 1.3x
            // clamp and pushed its figure out of line with the others.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style:
                    const TextStyle(fontSize: 12, color: AppPalette.textMuted),
              ),
            ),
          ],
        ),
      );
}

/// Calories, with the way to read how they are estimated.
class _CalorieStat extends StatelessWidget {
  const _CalorieStat({required this.calories});

  final double calories;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      key: SessionCard.calorieKey,
      child: Column(
        children: <Widget>[
          Text(
            '${calories.round()}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'kcal',
                style: TextStyle(fontSize: 12, color: AppPalette.textMuted),
              ),
              const SizedBox(width: 4),
              Builder(
                builder: (context) => Semantics(
                  container: true,
                  button: true,
                  label: 'How the calorie estimate works',
                  onTap: () => _explain(context),
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: SessionCard.calorieInfoKey,
                    onTap: () => _explain(context),
                    child: const Icon(Icons.info_outline,
                        size: 13, color: AppPalette.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _explain(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.border),
        ),
        title: const Text(
          'How this is estimated',
          style: TextStyle(fontSize: 17, color: AppPalette.textPrimary),
        ),
        content: const Text(
          'Estimated from the sets you logged and your body weight, using '
          'standard exercise-science averages for resistance training. Actual '
          'calories burned vary by person and effort.',
          style: TextStyle(fontSize: 15, color: AppPalette.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
        ],
      ),
    );
  }
}
