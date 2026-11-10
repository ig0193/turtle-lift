import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../data/date_labels.dart';
import '../data/diet_derived.dart' show suggestedTargetFor;
import '../data/diet_plan.dart' show proteinTargetProvider;
import '../data/local_date.dart';
import '../data/personal_details_store.dart';
import '../data/set_format.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'bodyweight_trend_chart.dart';
import 'number_input.dart';
import 'protein_target_screen.dart' show DietTextLink, pushProteinTargetScreen;
import 'template_row.dart';

/// The two things the app collects about the user, and the log of one of them.
///
/// **Everything here is authored** — the user typed it — which is why it lives
/// behind the avatar rather than on the History tab (KD1). Nothing on this
/// screen is computed from a session.
///
/// **The weight log is read-only, and that is the feature.** A bodyweight entry
/// is immutable and takes effect from the day it is recorded: no edit, no
/// delete, no backdating (KD5). The reason is not tidiness — the calorie
/// estimate is derived on read from the weight *in effect on* a session's date,
/// so changing or removing a past entry silently re-prices workouts the user
/// already saw and screenshotted. A correction is a new entry that supersedes
/// the old one going forward.
///
/// That rule is why there is no date picker here. The only control is the
/// number; the date is always today, because today is the only day an entry can
/// legally take effect from.
class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key});

  /// The heading over the gender choice.
  @visibleForTesting
  static const String genderGroupLabel = 'Body diagram';

  /// The heading over the weight series.
  @visibleForTesting
  static const String weightGroupLabel = 'Bodyweight';

  /// What the weight group says before the user has recorded anything.
  ///
  /// The same promise `docs/01` makes everywhere the calorie stat is gated: a
  /// prompt rather than a wrong number, and never a zero.
  @visibleForTesting
  static const String noWeightLabel =
      'Add your weight to see calorie estimates. '
      'Sessions logged before your first entry never get one.';

  /// What the gender choice explains underneath itself.
  @visibleForTesting
  static const String genderCaption =
      'Chooses which body diagram is used throughout the app. '
      'It changes nothing else.';

  /// Shown under the field while it holds something that is not a weight
  /// (profile audit B1).
  static const String rangeReason = 'Between 20 and 250 kg';

  /// What a weigh-in can and cannot be changed by (profile audit B3, KD5).
  static const String correctionNote =
      "Recording again today replaces today's entry until midnight. After "
      'that it stays, so a correction is a new entry from that day.';

  /// The status line after a weigh-in.
  static String recordedLine(double kg) =>
      'Recorded ${formatWeight(kg)} kg for today.';

  /// The follow-up when a weigh-in moves the protein suggestion away from a
  /// stored target (ADR 0014 §3). The target itself never changes here.
  static String suggestionMovedLine(int grams) =>
      'Protein suggestion is now $grams g.';

  /// Finds the Update target link after a weigh-in.
  @visibleForTesting
  static const Key updateTargetKey = ValueKey<String>('weight-update-target');

  /// Finds the status line after a weigh-in.
  @visibleForTesting
  static const Key statusKey = ValueKey<String>('weight-status');

  /// Finds one gender option.
  @visibleForTesting
  static Key genderKey(BodyGender gender) =>
      ValueKey<String>('gender-${gender.name}');

  /// Finds one row of the weight log, by the date it took effect.
  @visibleForTesting
  static Key weightRowKey(String isoDate) =>
      ValueKey<String>('weight-$isoDate');

  /// Finds the weight field.
  @visibleForTesting
  static const Key weightFieldKey = ValueKey<String>('weight-field');

  /// Finds the record button.
  @visibleForTesting
  static const Key recordKey = ValueKey<String>('weight-record');

  @override
  ConsumerState<PersonalDetailsScreen> createState() =>
      _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState
    extends ConsumerState<PersonalDetailsScreen> {
  late final TextEditingController _weight = TextEditingController()
    ..addListener(_changed);

  /// What the last Record did, read out by VoiceOver; null until then.
  String? _status;

  /// The new protein suggestion, when the last weigh-in moved it away from
  /// the stored target; null otherwise.
  int? _movedSuggestion;

  void _changed() => setState(() {});

  bool get _showReason =>
      _weight.text.trim().isNotEmpty && parseBodyweight(_weight.text) == null;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gender = ref.watch(bodyGenderProvider);
    // Newest first for display. The store keeps the series oldest-first
    // because that is the order resolution walks it in; reversing here rather
    // than there keeps the one true order in the data layer.
    final entries = ref.watch(bodyweightLogProvider).reversed.toList();

    return AppScreen.pushed(
      title: 'Personal details',
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const _GroupLabel(PersonalDetailsScreen.genderGroupLabel),
          Row(
            children: <Widget>[
              for (final option in BodyGender.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _GenderChip(
                    key: PersonalDetailsScreen.genderKey(option),
                    label: _genderLabel(option),
                    selected: option == gender,
                    onTap: () =>
                        ref.read(bodyGenderProvider.notifier).select(option),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              PersonalDetailsScreen.genderCaption,
              style: kTemplateRowSubtitleStyle,
            ),
          ),
          const _GroupLabel(PersonalDetailsScreen.weightGroupLabel),
          _WeightField(
            controller: _weight,
            onRecord: _record,
            valid: parseBodyweight(_weight.text) != null,
          ),
          if (_showReason)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                container: true,
                child: const Text(
                  PersonalDetailsScreen.rangeReason,
                  style: _reasonStyle,
                ),
              ),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Text(
                  <String>[
                    _status!,
                    if (_movedSuggestion != null)
                      PersonalDetailsScreen.suggestionMovedLine(
                          _movedSuggestion!),
                  ].join(' '),
                  key: PersonalDetailsScreen.statusKey,
                  style: _reasonStyle,
                ),
              ),
            ),
          if (_movedSuggestion != null)
            DietTextLink(
              key: PersonalDetailsScreen.updateTargetKey,
              label: 'Update target',
              onTap: () => pushProteinTargetScreen(
                context,
                initialGrams: _movedSuggestion,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Semantics(
              container: true,
              child: const Text(
                PersonalDetailsScreen.correctionNote,
                style: kTemplateRowSubtitleStyle,
              ),
            ),
          ),
          if (entries.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: BodyweightTrendChart(
                entries: entries.reversed.toList(growable: false),
              ),
            ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                PersonalDetailsScreen.noWeightLabel,
                style: kTemplateRowSubtitleStyle,
              ),
            )
          else
            for (final entry in entries)
              _WeightRow(
                key: PersonalDetailsScreen.weightRowKey(
                  encodeCalendarDate(entry.date),
                ),
                entry: entry,
              ),
          const _CalorieExplainer(),
        ],
      ),
    );
  }

  Future<void> _record() async {
    final parsed = parseBodyweight(_weight.text);
    if (parsed == null) return;
    await ref.read(bodyweightLogProvider.notifier).record(parsed);
    if (!mounted) return;
    _weight.clear();
    final target = ref.read(proteinTargetProvider);
    final suggestion = suggestedTargetFor(parsed);
    setState(() {
      _status = PersonalDetailsScreen.recordedLine(parsed);
      _movedSuggestion =
          target != null && suggestion != null && suggestion != target
              ? suggestion
              : null;
    });
    FocusScope.of(context).unfocus();
  }
}

/// `docs/04` spells the three options exactly this way.
String _genderLabel(BodyGender gender) => switch (gender) {
      BodyGender.male => 'Male',
      BodyGender.female => 'Female',
      BodyGender.preferNotToSay => 'Prefer not to say',
    };

/// One gender option.
///
/// Selected state is carried by [AppPalette.accentStrong], which means "active"
/// everywhere in the app — this is that, not an approval.
class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Selected = raised neutral, amber outline and label: the same
            // selection language as the Front/Back toggle and the Profile
            // switch. A solid accent is reserved for the primary action.
            color: selected ? AppPalette.mutedSurface : AppPalette.surface,
            border: Border.all(
              color: selected ? AppPalette.accentStrong : AppPalette.border,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  selected ? AppPalette.accentStrong : AppPalette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The weight input and its record button.
///
/// **One field, no date control.** KD5 forbids backdating, so offering a date
/// would be offering an illegal action; the entry is always dated today.
class _WeightField extends StatelessWidget {
  const _WeightField({
    required this.controller,
    required this.onRecord,
    required this.valid,
  });

  final TextEditingController controller;

  /// Records the field's value; does nothing when it is not a valid weight.
  final VoidCallback onRecord;

  /// False while the field does not hold a valid weight: the button dims, a
  /// tap records nothing, and the reason under the field says why.
  final bool valid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          // Stable id for UI automation (Maestro); never read aloud.
          child: Semantics(
            identifier: 'bodyweight-field',
            child: TextField(
            key: PersonalDetailsScreen.weightFieldKey,
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // A comma decimal ("77,5") is accepted, and nothing that is not a
            // weight can be typed or pasted.
            inputFormatters: <TextInputFormatter>[
              UnsignedNumberFormatter(decimals: 1, maxIntegerDigits: 3),
            ],
            // The iOS number pad has no return key: a tap off the field
            // is how it is put away.
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            style: kTemplateRowTitleStyle,
            cursorColor: AppPalette.accentStrong,
            onSubmitted: (_) => onRecord(),
            // The theme's field: 16pt radius, hairline border, amber on
            // focus -- the same box as the search field, not Material's 4pt
            // default sitting next to a capsule.
            decoration: const InputDecoration(
              hintText: 'Weight in kg',
              hintStyle: kTemplateRowSubtitleStyle,
              suffixText: 'kg',
              suffixStyle: kTemplateRowSubtitleStyle,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          container: true,
          button: true,
          label: 'Record weight',
          identifier: 'record-weight',
          enabled: valid,
          onTap: onRecord,
          excludeSemantics: true,
          child: GestureDetector(
            key: PersonalDetailsScreen.recordKey,
            behavior: HitTestBehavior.opaque,
            onTap: onRecord,
            child: Opacity(
              opacity: valid ? 1 : 0.5,
              child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              // The screen's primary action, so it takes the primary button's
              // look: a chalk capsule.
              decoration: const ShapeDecoration(
                shape: StadiumBorder(),
                color: AppPalette.textPrimary,
              ),
              child: const Text(
                'Record',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.onAccent,
                ),
              ),
            ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One recorded weight.
///
/// **No trailing action of any kind**, and no `GestureDetector`: the row is
/// not tappable because there is nothing legal to do to it. A swipe action or
/// an edit pencil here would be the regression KD5 exists to prevent, so the
/// row offers no surface to hang one on.
class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.entry, super.key});

  final BodyweightEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: TemplateRow.minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('${formatWeight(entry.weightKg)}kg',
              style: kTemplateRowTitleStyle),
          Text(
            'from ${shortDateLabel(LocalDate.fromDateTime(entry.date))}',
            style: kTemplateRowSubtitleStyle,
          ),
        ],
      ),
    );
  }
}

/// How the calorie estimate works, carried from `docs/04` §Personal details.
///
/// The transparency is the point: a stat the user cannot predict is a stat that
/// generates angry reviews, so the tiers and the honesty note travel with the
/// field that gates them.
class _CalorieExplainer extends StatelessWidget {
  const _CalorieExplainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'How the calorie estimate works',
            style: kTemplateRowTitleStyle,
          ),
          const SizedBox(height: 8),
          for (final tier in const <(String, String)>[
            ('1-9 sets', 'Light effort'),
            ('10-20 sets', 'Moderate effort'),
            ('21+ sets', 'Vigorous effort'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(tier.$1, style: kTemplateRowSubtitleStyle),
                  Text(tier.$2, style: kTemplateRowSubtitleStyle),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Each session uses the weight in effect on the day it happened, '
            'not your newest one, so recording a weight today never changes '
            'a workout you already logged. Actual calories burned vary by '
            'person and effort.',
            style: kTemplateRowSubtitleStyle,
          ),
        ],
      ),
    );
  }
}

/// A section heading, matching `ProfileScreen` and `MusclesRoot`.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(label, style: kLandingSectionLabelStyle),
      ),
    );
  }
}

const TextStyle _reasonStyle = TextStyle(
  fontSize: 13,
  color: AppPalette.textSecondary,
);
