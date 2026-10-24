import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_screen.dart';
import 'profile_screen.dart';
import 'schedule_pane.dart';

/// The two panes of the Profile tab.
enum ProfileSegment {
  /// What the user typed: personal details, templates, data actions.
  personal('Personal'),

  /// Training days, the week summary and reminders. See
  /// `docs/adr/0005-schedule-and-opt-in-notifications.md`.
  schedule('Schedule');

  const ProfileSegment(this.label);

  final String label;
}

/// The Profile tab root: a Personal | Schedule segmented control over one
/// scroll view (`docs/adr/0004-profile-returns-as-a-tab.md`).
///
/// **A body, never a `Scaffold`** -- [L0Shell] owns the one `Scaffold`, the
/// pinned header and the bar, like the other three roots. The scrollable
/// carries [screenScrollPadding] so the last row clears the floating bar.
///
/// **The segment is local state, not a provider.** Nothing outside this widget
/// needs to switch it, and it is deliberately not remembered across launches:
/// Profile opens on Personal. [IndexedStack] in the shell keeps this root
/// mounted, so it survives a tab switch anyway.
class ProfileRoot extends StatefulWidget {
  const ProfileRoot({super.key});

  @visibleForTesting
  static Key segmentKey(ProfileSegment segment) =>
      ValueKey<String>('profile-segment-${segment.name}');

  @override
  State<ProfileRoot> createState() => _ProfileRootState();
}

class _ProfileRootState extends State<ProfileRoot> {
  ProfileSegment _segment = ProfileSegment.personal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: screenScrollPadding(context),
      children: <Widget>[
        _SegmentedControl(
          selected: _segment,
          onSelected: (s) => setState(() => _segment = s),
        ),
        switch (_segment) {
          ProfileSegment.personal => const ProfilePersonalPane(),
          ProfileSegment.schedule => const SchedulePane(),
        },
      ],
    );
  }
}

/// `.seg` in `prototypes/schedule-options.html`: a surface capsule with a
/// 1pt border and 3pt padding, the selected half filled accent.
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.selected, required this.onSelected});

  final ProfileSegment selected;
  final ValueChanged<ProfileSegment> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: BorderRadius.circular(9),
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
                    child: Container(
                      // 44pt tall once the 3pt padding is counted: a gym,
                      // one hand, a thumb.
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: segment == selected
                            ? AppPalette.accentStrong
                            : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        segment.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: segment == selected
                              ? AppPalette.onAccent
                              : AppPalette.textMuted,
                        ),
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
