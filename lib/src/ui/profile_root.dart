import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_screen.dart';
import 'diet_pane.dart';
import 'profile_screen.dart';
import 'schedule_pane.dart';

/// The three panes of the Profile tab.
enum ProfileSegment {
  /// What the user typed: personal details, templates, data actions.
  personal('Personal'),

  /// Training days, the week summary and reminders. See
  /// `docs/adr/0005-schedule-and-opt-in-notifications.md`.
  schedule('Schedule'),

  /// The weekly protein plan. See `docs/adr/0007-diet-in-profile.md`.
  diet('Diet');

  const ProfileSegment(this.label);

  final String label;
}

/// Which Profile pane is showing. **In memory only, never stored** (KTD2).
///
/// A provider rather than `State` because something outside [ProfileRoot]
/// has to switch it: a diet reminder tap lands on Diet (R11). It builds to
/// [ProfileSegment.personal], so a cold start and the `appRestartProvider`
/// reboot after Delete all data both open Profile on Personal (R10, AE8), and
/// [IndexedStack] in the shell keeps the choice across tab switches.
class ProfileSegmentNotifier extends Notifier<ProfileSegment> {
  @override
  ProfileSegment build() => ProfileSegment.personal;

  void select(ProfileSegment segment) => state = segment;
}

final profileSegmentProvider =
    NotifierProvider<ProfileSegmentNotifier, ProfileSegment>(
  ProfileSegmentNotifier.new,
);

/// The Profile tab root: a Personal | Schedule | Diet segmented control over
/// one scroll view (`docs/adr/0004-profile-returns-as-a-tab.md`,
/// `docs/adr/0007-diet-in-profile.md`).
///
/// **A body, never a `Scaffold`** -- [L0Shell] owns the one `Scaffold`, the
/// pinned header and the bar, like the other three roots. The scrollable
/// carries [screenScrollPadding] so the last row clears the floating bar.
///
/// **The segment lives in [profileSegmentProvider]**, so a reminder tap can
/// select Diet from outside this widget.
///
/// **A switch jumps to the top** (KTD3). The three panes share one scroll view
/// and differ a lot in length; without the reset, leaving a scrolled Diet
/// would land part way down Personal.
class ProfileRoot extends ConsumerStatefulWidget {
  const ProfileRoot({super.key});

  @visibleForTesting
  static Key segmentKey(ProfileSegment segment) =>
      ValueKey<String>('profile-segment-${segment.name}');

  @override
  ConsumerState<ProfileRoot> createState() => _ProfileRootState();
}

class _ProfileRootState extends ConsumerState<ProfileRoot> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileSegment>(profileSegmentProvider, (previous, next) {
      if (previous != next && _scroll.hasClients) _scroll.jumpTo(0);
    });
    final segment = ref.watch(profileSegmentProvider);
    return ListView(
      controller: _scroll,
      padding: screenScrollPadding(context),
      children: <Widget>[
        _SegmentedControl(
          selected: segment,
          onSelected: ref.read(profileSegmentProvider.notifier).select,
        ),
        switch (segment) {
          ProfileSegment.personal => const ProfilePersonalPane(),
          ProfileSegment.schedule => const SchedulePane(),
          ProfileSegment.diet => const DietPane(),
        },
      ],
    );
  }
}

/// `.seg` in `prototypes/diet.html`: a surface capsule with a 1pt border and
/// 4pt padding, the selected segment a raised neutral.
///
/// **The 4pt vertical padding sits inside each segment's tap target**, so a
/// 40pt capsule gives a 48pt target (R9) while drawing exactly the old 4pt
/// inset. Labels are one line; at 1.3x text on a 375pt phone "Schedule" fits
/// with room, and the [FittedBox] only guards a still larger system setting.
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.selected, required this.onSelected});

  final ProfileSegment selected;
  final ValueChanged<ProfileSegment> onSelected;

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
          for (final segment in ProfileSegment.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: segment == selected,
                label: segment.label,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    key: ProfileRoot.segmentKey(segment),
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
