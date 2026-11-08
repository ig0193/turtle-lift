import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diet_derived.dart' show suggestedTargetProvider;
import '../data/diet_plan.dart' show proteinTargetProvider;
import '../data/bodyweight_resolution.dart' show weightInEffectProvider;
import '../data/settings_store.dart'
    show kMaxProteinTargetG, kMinProteinTargetG;
import '../data/training_plan.dart' show planTodayProvider;
import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'ghost_button.dart';
import 'personal_details_screen.dart';

/// Pushes the [ProteinTargetScreen] onto the stack.
Future<void> pushProteinTargetScreen(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProteinTargetScreen()),
    );

/// "Daily protein target": set or clear the one number every day's plan is
/// measured against (R15, R16; `.target` in `prototypes/diet.html`).
///
/// * **One whole-gram field, 1 to 400** (A3). Anything else cannot be saved,
///   and the reason sits under the field rather than in a dialog.
/// * **The suggestion fills the field and stores nothing.** Only Save writes,
///   and it writes the number, never a "follow my bodyweight" flag (R15): a
///   later weigh-in moves the suggestion, not the target.
/// * **The suggestion shows its working and its source** (R16, KD3): 1.6 g per
///   kg of the bodyweight in effect today, to the nearest 5 g
///   ([suggestedTargetProvider]). Framed as "a common starting point", not an
///   optimum (Protein rule verification in the plan). Without a bodyweight the
///   row is replaced by a link to Personal details, pushed on top of this
///   screen so Back lands here with the suggestion recomputed.
/// * **One filled button**, Save. Clear target is a ghost button, and only
///   when a target is set.
class ProteinTargetScreen extends ConsumerStatefulWidget {
  const ProteinTargetScreen({super.key});

  static const String title = 'Daily protein target';

  static const String fieldUnit = 'g a day';

  static const String helper =
      "Every day's plan is measured against this number. Change it any time.";

  /// Why 0 or 401 cannot be saved.
  static const String rangeReason = 'Whole grams, 1 to 400';

  static const String addBodyweightLabel =
      'Add your bodyweight to get a suggestion';

  static const String medicalNote =
      'A guide, not medical advice. If you have a health condition, '
      'talk to a doctor before changing your diet.';

  static const String sourceLine =
      'Source: Morton et al. 2018, Br J Sports Med; ISSN position stand '
      '2017 (1.4 to 2.0 g per kg).';

  static const String saveLabel = 'Save';

  static const String clearLabel = 'Clear target';

  /// "Suggested 115 g".
  static String suggestedLine(int grams) => 'Suggested $grams g';

  /// "1.6 g per kg at 72 kg, your current bodyweight. A common starting
  /// point."
  static String workingLine(double kg) =>
      '1.6 g per kg at ${_trimZero(kg)} kg, your current bodyweight. '
      'A common starting point.';

  @visibleForTesting
  static const Key fieldKey = ValueKey<String>('protein-target-field');

  @visibleForTesting
  static const Key reasonKey = ValueKey<String>('protein-target-reason');

  @visibleForTesting
  static const Key suggestionKey =
      ValueKey<String>('protein-target-suggestion');

  @visibleForTesting
  static const Key addBodyweightKey =
      ValueKey<String>('protein-target-add-bodyweight');

  @visibleForTesting
  static const Key saveKey = ValueKey<String>('protein-target-save');

  @visibleForTesting
  static const Key clearKey = ValueKey<String>('protein-target-clear');

  @override
  ConsumerState<ProteinTargetScreen> createState() =>
      _ProteinTargetScreenState();
}

class _ProteinTargetScreenState extends ConsumerState<ProteinTargetScreen> {
  late final TextEditingController _grams = TextEditingController(
    text: ref.read(proteinTargetProvider)?.toString() ?? '',
  )..addListener(_changed);

  void _changed() => setState(() {});

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  /// The field as a savable target, or null when it is empty or out of range.
  int? get _valid {
    final grams = int.tryParse(_grams.text);
    if (grams == null) return null;
    if (grams < kMinProteinTargetG || grams > kMaxProteinTargetG) return null;
    return grams;
  }

  /// Something typed that cannot be saved. An empty field is not an error.
  bool get _showReason => _grams.text.isNotEmpty && _valid == null;

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(proteinTargetProvider);
    final suggested = ref.watch(suggestedTargetProvider);
    // Both follow a weigh-in made on Personal details while this screen sits
    // underneath it: the weight resolver is rebuilt from the series.
    final today = ref.watch(planTodayProvider);
    final kg = ref.watch(weightInEffectProvider)(today.toDateTime())?.weightKg;

    return AppScreen.pushed(
      title: ProteinTargetScreen.title,
      body: ListView(
        padding: screenScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 4),
          _TargetField(controller: _grams),
          if (_showReason)
            const Padding(
              key: ProteinTargetScreen.reasonKey,
              padding: EdgeInsets.fromLTRB(2, 0, 2, 12),
              child: Text(ProteinTargetScreen.rangeReason, style: _reasonStyle),
            ),
          if (suggested != null && kg != null)
            _SuggestionRow(
              grams: suggested,
              kg: kg,
              onTap: () => _grams.text = '$suggested',
            )
          else
            const _AddBodyweightBox(),
          const _Helper(ProteinTargetScreen.helper),
          const _Helper(ProteinTargetScreen.sourceLine),
          const _Helper(ProteinTargetScreen.medicalNote),
          const SizedBox(height: 4),
          FilledButton(
            key: ProteinTargetScreen.saveKey,
            onPressed: _valid == null ? null : _save,
            child: const Text(ProteinTargetScreen.saveLabel),
          ),
          if (stored != null) ...<Widget>[
            const SizedBox(height: 8),
            GhostButton(
              buttonKey: ProteinTargetScreen.clearKey,
              label: ProteinTargetScreen.clearLabel,
              onTap: _clear,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final grams = _valid;
    if (grams == null) return;
    await ref.read(proteinTargetProvider.notifier).set(grams);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await ref.read(proteinTargetProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }
}

/// `.tfield`: the number, large, with its unit beside it.
class _TargetField extends StatelessWidget {
  const _TargetField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Semantics(
              label: 'Grams a day',
              child: TextField(
                key: ProteinTargetScreen.fieldKey,
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                cursorColor: AppPalette.accentStrong,
                style: _fieldStyle,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '0',
                  hintStyle: _fieldHintStyle,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(ProteinTargetScreen.fieldUnit, style: _unitStyle),
        ],
      ),
    );
  }
}

/// `.suggest`: an outlined row that fills the field. Outlined, not filled:
/// the screen's one filled button is Save.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.grams,
    required this.kg,
    required this.onTap,
  });

  final int grams;
  final double kg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = ProteinTargetScreen.suggestedLine(grams);
    final working = ProteinTargetScreen.workingLine(kg);
    return Semantics(
      button: true,
      label: '$title. $working Fills the field.',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: ProteinTargetScreen.suggestionKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppPalette.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: _suggestTitleStyle),
              const SizedBox(height: 2),
              Text(working, style: _suggestBodyStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.nobw`: no bodyweight, so no suggestion; a link to record one.
class _AddBodyweightBox extends StatelessWidget {
  const _AddBodyweightBox();

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PersonalDetailsScreen(),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DietTextLink(
        key: ProteinTargetScreen.addBodyweightKey,
        label: ProteinTargetScreen.addBodyweightLabel,
        onTap: open,
      ),
    );
  }
}

/// A quiet in-text action with a 48pt tap target: "Set a daily target",
/// "Add your bodyweight to get a suggestion".
///
/// **Not in the accent.** On Diet the accent means one thing, eaten (the tick
/// and the eaten layer, KTD20), so a link carries its affordance with weight
/// and an underline instead.
class DietTextLink extends StatelessWidget {
  const DietTextLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.centerLeft,
          child: Text(label, style: _linkStyle),
        ),
      ),
    );
  }
}

class _Helper extends StatelessWidget {
  const _Helper(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Text(text, style: _helperStyle),
    );
  }
}

/// `72.0` reads as a precision the scale did not offer; `72.5` keeps its half.
String _trimZero(double kg) =>
    kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();

const TextStyle _fieldStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w600,
  color: AppPalette.textPrimary,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

const TextStyle _fieldHintStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w600,
  color: AppPalette.textMuted,
);

const TextStyle _unitStyle = TextStyle(
  fontSize: 15,
  color: AppPalette.textMuted,
);

const TextStyle _reasonStyle = TextStyle(
  fontSize: 13,
  color: AppPalette.textSecondary,
);

const TextStyle _suggestTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: AppPalette.textPrimary,
);

const TextStyle _suggestBodyStyle = TextStyle(
  fontSize: 12,
  height: 1.4,
  color: AppPalette.textSecondary,
);

const TextStyle _helperStyle = TextStyle(
  fontSize: 12,
  height: 1.5,
  color: AppPalette.textMuted,
);

const TextStyle _linkStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: AppPalette.textPrimary,
  decoration: TextDecoration.underline,
  decorationColor: AppPalette.textSecondary,
);
