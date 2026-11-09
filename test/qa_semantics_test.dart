import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/ghost_button.dart';

/// Accessibility regressions found by the Maestro pass, which reads the same
/// tree VoiceOver does.
void main() {
  // QA (Maestro, Diet first-time state): "Set a daily target" was not its own
  // element. GhostButton's Semantics was not a container, so its label and tap
  // merged into the nearest ancestor node with the heading and body text, and
  // VoiceOver read the whole block as one thing with no separate button.
  testWidgets('a ghost button is its own button, not part of the text above',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Semantics(
          container: true,
          child: Column(
            children: <Widget>[
              const Text('Plan your week'),
              GhostButton(label: 'Set a daily target', onTap: () {}),
            ],
          ),
        ),
      ),
    ));

    expect(find.bySemanticsLabel(RegExp(r'^Set a daily target$')),
        findsOneWidget);
    final node = tester.getSemantics(find.byType(GhostButton));
    expect(node.label, 'Set a daily target');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}
