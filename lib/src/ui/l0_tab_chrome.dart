import 'package:flutter/widgets.dart';

/// What a tab contributes to the shell's pinned header beyond its own name.
///
/// **The seam that keeps the shell ignorant of features.** The Workout header
/// stops being the word "Workout" the moment a workout is open: it becomes the
/// editable session title, and it grows a control for starting a different
/// workout. Wiring that by having the shell read the session would put the
/// app's navigation chassis in the business of knowing what a session is, and
/// every later feature wanting header chrome would copy the pattern.
///
/// Instead each feature owns a provider returning one of these, and the shell
/// knows only that a tab may contribute a title and some actions.
@immutable
class L0TabChrome {
  const L0TabChrome({this.title, this.titleWidget, this.actions});

  /// Replaces the tab's name as the header's semantics label.
  final String? title;

  /// Replaces the header text.
  final Widget? titleWidget;

  /// Controls added before the profile avatar, which stays trailing-most.
  final List<Widget>? actions;
}
