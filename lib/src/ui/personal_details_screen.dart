import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/body_gender.dart';
import '../data/personal_details_store.dart';
import '../theme/app_palette.dart';
import 'app_screen.dart';
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
  static const String genderGroupLabel = 'BODY DIAGRAM';

  /// The heading over the weight series.
  @visibleForTesting
  static const String weightGroupLabel = 'BODYWEIGHT';

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
  final TextEditingController _weight = TextEditingController();

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
    final parsed = double.tryParse(_weight.text.trim());
    if (parsed == null || parsed <= 0 || !parsed.isFinite) return;
    await ref.read(bodyweightLogProvider.notifier).record(parsed);
    if (!mounted) return;
    _weight.clear();
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
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppPalette.accentStrong : AppPalette.surface,
            border: Border.all(
              color: selected ? AppPalette.accentStrong : AppPalette.border,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppPalette.onAccent : AppPalette.textSecondary,
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
  const _WeightField({required this.controller, required this.onRecord});

  final TextEditingController controller;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            key: PersonalDetailsScreen.weightFieldKey,
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: kTemplateRowTitleStyle,
            cursorColor: AppPalette.accentStrong,
            onSubmitted: (_) => onRecord(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Weight in kg',
              hintStyle: kTemplateRowSubtitleStyle,
              suffixText: 'kg',
              suffixStyle: kTemplateRowSubtitleStyle,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppPalette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppPalette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppPalette.accentStrong),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Record weight',
          excludeSemantics: true,
          child: GestureDetector(
            key: PersonalDetailsScreen.recordKey,
            behavior: HitTestBehavior.opaque,
            onTap: onRecord,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.accentStrong,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                'Record',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.onAccent,
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('${_trimZero(entry.weightKg)} kg',
              style: kTemplateRowTitleStyle),
          Text(
            'from ${encodeCalendarDate(entry.date)}',
            style: kTemplateRowSubtitleStyle,
          ),
        ],
      ),
    );
  }
}

/// `78.0` reads as a precision the scale did not offer; `78.5` keeps its half.
String _trimZero(double kg) =>
    kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();

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
        borderRadius: BorderRadius.circular(9),
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
            ('1–9 sets', 'Light effort'),
            ('10–20 sets', 'Moderate effort'),
            ('21+ sets', 'Vigorous effort'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
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
            'not your newest one — so recording a weight today never changes '
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
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(label, style: kLandingSectionLabelStyle),
      ),
    );
  }
}
