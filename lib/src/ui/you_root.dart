import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'empty_state.dart' show kEmptyStateBodyStyle;
import 'history_root.dart';
import 'profile_screen.dart';

/// The three panes of the You tab (`docs/adr/0016-you-tab-and-diet-tab.md`).
enum YouSegment {
  /// What the user typed: personal details, templates, data actions. This is
  /// what the Profile tab's Personal pane was.
  profile('Profile'),

  /// What the user did: the old History tab (stats, calendar, recent
  /// workouts). The workouts are the same; only its home moved.
  activity('Activity'),

  /// Reserved. An empty pane for now.
  analysis('Analysis');

  const YouSegment(this.label);

  final String label;
}

/// Which You pane is showing. **In memory only, never stored** (KTD2).
///
/// It builds to [YouSegment.activity], so a cold start and the
/// `appRestartProvider` reboot after Delete all data both open You on Activity
/// (what the user did is what they come to You to read), and the shell's
/// [IndexedStack] keeps the choice across tab switches.
class YouSegmentNotifier extends Notifier<YouSegment> {
  @override
  YouSegment build() => YouSegment.activity;

  void select(YouSegment segment) => state = segment;
}

final youSegmentProvider =
    NotifierProvider<YouSegmentNotifier, YouSegment>(YouSegmentNotifier.new);

/// The You tab root: a Profile | Activity | Analysis segmented control over
/// three panes.
///
/// **A body, never a `Scaffold`** -- [L0Shell] owns the one `Scaffold`, the
/// pinned header and the bar, like the other three roots.
///
/// **Each pane owns its own scroll view.** Profile used to share one with Diet,
/// which is why a switch had to jump to the top; with a scrollable per pane
/// there is nothing to reset, and **[IndexedStack] keeps all three mounted**, so
/// Activity keeps its scroll position and calendar month while the user looks
/// at Profile. The control is pinned above them (profile audit B4, ADR 0014):
/// on a long pane, or back from a pushed screen, the way to the others is never
/// scrolled away.
class YouRoot extends ConsumerWidget {
  const YouRoot({super.key});

  @visibleForTesting
  static Key segmentKey(YouSegment segment) =>
      ValueKey<String>('you-segment-${segment.name}');

  /// The Profile pane's scroll view.
  @visibleForTesting
  static const Key profileScrollKey = ValueKey<String>('you-profile-scroll');

  /// The Analysis pane.
  @visibleForTesting
  static const Key analysisKey = ValueKey<String>('you-analysis');

  static const String analysisCopy = 'Analysis is coming soon.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(youSegmentProvider);
    final padding = screenScrollPadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          child: _SegmentedControl(
            selected: segment,
            onSelected: ref.read(youSegmentProvider.notifier).select,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: segment.index,
            sizing: StackFit.expand,
            children: <Widget>[
              ListView(
                key: profileScrollKey,
                padding: padding,
                children: const <Widget>[ProfilePersonalPane()],
              ),
              const HistoryRoot(),
              ListView(
                key: analysisKey,
                padding: padding,
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 34, horizontal: 16),
                    child: Text(
                      analysisCopy,
                      textAlign: TextAlign.center,
                      style: kEmptyStateBodyStyle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `.seg` in `prototypes/diet.html`: a surface capsule with a 1pt border and
/// 4pt padding, the selected segment a raised neutral.
///
/// **The 4pt vertical padding sits inside each segment's tap target**, so a
/// 40pt capsule gives a 48pt target (R9) while drawing exactly the old 4pt
/// inset. Labels are one line, and the [FittedBox] only guards a very large
/// system text setting.
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.selected, required this.onSelected});

  final YouSegment selected;
  final ValueChanged<YouSegment> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          for (final segment in YouSegment.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: segment == selected,
                label: segment.label,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    key: YouRoot.segmentKey(segment),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(segment),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _SegmentCapsule(
                        label: segment.label,
                        selected: segment == selected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentCapsule extends StatelessWidget {
  const _SegmentCapsule({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 48pt tall with the 4pt padding around it: a gym, one hand, a thumb.
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Selected reads like the tab bar's highlight: a raised neutral with
        // the label in the accent. A solid amber slab would be the loudest thing
        // on the screen for a control that only switches a view.
        color: selected ? AppPalette.mutedSurface : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: AppTypeScale.footnote,
            fontWeight: FontWeight.w500,
            color: selected ? AppPalette.accentStrong : AppPalette.textMuted,
          ),
        ),
      ),
    );
  }
}
