import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Horizontal gutter every screen uses, matching `.scroll` in the L0
/// prototypes (`padding: 0 18px`). Apply it to the *scrollable's* own padding,
/// not to a wrapper, so overscroll glow and the scrollbar still reach the edge.
const double kScreenGutter = 18;

/// The shell every screen is built from.
///
/// **The header is pinned. It does not scroll — anywhere in the app.**
///
/// That is structural, not styling: the header is the [Scaffold.appBar], which
/// sits outside the body and therefore outside whatever scroll view the body
/// contains. [body] is expected to *be* the scrollable (a `ListView`,
/// `SingleChildScrollView`, `CustomScrollView`, …), so content scrolls beneath
/// a header that stays put.
///
/// Two rules follow from that, and both are easy to break by accident:
///
/// * Never put a title row inside the scroll view. The prototypes render `.hdr`
///   and `.l0h` inside `.scroll`, so their headers scroll away — that is a
///   prototype artefact, corrected here and in the prototypes themselves. This
///   widget is the reference, not that markup.
/// * Never reach for `SliverAppBar` with `floating`, `snap` or a collapsing
///   `expandedHeight`. A header that hides on scroll is not a pinned header.
///   `SliverAppBar(pinned: true)` is acceptable only if a screen genuinely
///   needs slivers, and then it must carry no scroll-driven size change.
///
/// Use [AppScreen.root] for a tab root (large title, no back arrow) and
/// [AppScreen.pushed] for anything pushed onto the stack (back arrow, compact
/// title).
class AppScreen extends StatelessWidget {
  const AppScreen._({
    required this.title,
    required this.body,
    required this.showBack,
    required this.largeTitle,
    this.titleWidget,
    this.actions,
    this.bottomBar,
    this.onBack,
    super.key,
  });

  /// A tab root: large title, no back arrow.
  const AppScreen.root({
    required String title,
    required Widget body,
    Widget? titleWidget,
    List<Widget>? actions,
    Widget? bottomBar,
    Key? key,
  }) : this._(
          title: title,
          body: body,
          showBack: false,
          largeTitle: true,
          titleWidget: titleWidget,
          actions: actions,
          bottomBar: bottomBar,
          key: key,
        );

  /// A pushed screen: back arrow, compact title.
  const AppScreen.pushed({
    required String title,
    required Widget body,
    Widget? titleWidget,
    List<Widget>? actions,
    Widget? bottomBar,
    VoidCallback? onBack,
    Key? key,
  }) : this._(
          title: title,
          body: body,
          showBack: true,
          largeTitle: false,
          titleWidget: titleWidget,
          actions: actions,
          bottomBar: bottomBar,
          onBack: onBack,
          key: key,
        );

  /// Header text. Still required when [titleWidget] is given — it is the
  /// semantics label for the header.
  final String title;

  /// Replaces the header text when the title is not a plain string (the
  /// editable session title, for instance). [title] remains the label.
  final Widget? titleWidget;

  /// The scrollable content. See the class doc: this scrolls, the header does not.
  final Widget body;

  final List<Widget>? actions;
  final Widget? bottomBar;
  final bool showBack;
  final bool largeTitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final titleStyle = largeTitle
        ? const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.48,
            color: AppPalette.textPrimary,
          )
        : const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.16,
            color: AppPalette.textPrimary,
          );

    return Scaffold(
      appBar: AppBar(
        // Pinned by construction: an appBar is a sibling of the body, so no
        // amount of scrolling in the body can move it.
        toolbarHeight: largeTitle ? 64 : 56,
        titleSpacing: showBack ? 0 : kScreenGutter,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                color: AppPalette.textSecondary,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Semantics(
          header: true,
          label: title,
          child: titleWidget ??
              Text(title, style: titleStyle, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          ...?actions,
          const SizedBox(width: kScreenGutter - 8),
        ],
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: bottomBar,
    );
  }
}
