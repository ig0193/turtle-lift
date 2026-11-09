import 'package:flutter/widgets.dart';

import 'glass_tab_bar.dart' show GlassTabBar;

/// Whether the user asked the platform for less motion.
///
/// **Both flags, always.** iOS reports Reduce Motion as `reduceMotion` and
/// leaves `disableAnimations` false; Android's "Remove animations" is
/// `disableAnimations`. Reading only `MediaQuery.disableAnimations` is how the
/// finish ring kept radiating on an iPhone (QA second pass), so every animation
/// in the app asks here, and this asks the tab bar's one reading of them.
bool prefersReducedMotion(BuildContext context) =>
    GlassTabBar.prefersReducedMotion(context);

/// [duration], or zero when the user asked for less motion: the change still
/// happens, it just does not travel.
Duration motionDuration(BuildContext context, Duration duration) =>
    prefersReducedMotion(context) ? Duration.zero : duration;
