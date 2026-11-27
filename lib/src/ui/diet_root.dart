import 'package:flutter/material.dart';

import 'app_screen.dart';
import 'diet_pane.dart';

/// The Diet tab root (`docs/adr/0016-you-tab-and-diet-tab.md`): the protein
/// log, as the first tab of the bar.
///
/// **A body, never a `Scaffold`** -- [L0Shell] owns the one `Scaffold`, the
/// pinned "Diet" header and the bar, like the other roots. The scrollable's
/// padding is [screenScrollPadding], always, so the last slot card clears the
/// floating bar.
///
/// Everything it shows is [DietPane], which used to live inside Profile.
class DietRoot extends StatelessWidget {
  const DietRoot({super.key});

  @visibleForTesting
  static const Key scrollKey = ValueKey<String>('diet-scroll');

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: scrollKey,
      padding: screenScrollPadding(context),
      children: const <Widget>[DietPane()],
    );
  }
}
