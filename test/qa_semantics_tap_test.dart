import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/date_labels.dart';
import 'package:turtle_lift/src/data/history_preview_data.dart';
import 'package:turtle_lift/src/data/local_date.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/history_calendar_card.dart';
import 'package:turtle_lift/src/ui/set_row.dart';

/// QA (second pass, accessibility): a control that names itself a button to
/// assistive tech must also carry the tap.
///
/// The app's shared pattern is `Semantics(button: true, label: …,
/// excludeSemantics: true, child: GestureDetector(onTap: …))`. The
/// `excludeSemantics` that keeps the visible text from being read twice also
/// hides the GestureDetector's own tap action, so unless the Semantics names
/// `onTap` itself the node is a button with nothing to activate: VoiceOver
/// falls back to a synthesised touch, and TalkBack's double-tap does nothing.
void main() {
  test('every Semantics button that excludes its children is its own node '
      'and names its own tap',
      () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in RegExp(r'Semantics\(').allMatches(source)) {
        final args = _argumentsBeforeChild(source, match.end);
        final excludes = args.contains('excludeSemantics: true');
        final hasTap = RegExp(r'\bonTap:').hasMatch(args);
        final isButton = args.contains('button: true');
        // A button must name its tap; anything tappable that hides its
        // children must be its own node, or it merges with the text beside
        // it (the Schedule's Remind me switch did, QA second pass).
        if (excludes &&
            ((isButton && !hasTap) ||
                ((isButton || hasTap) && !args.contains('container: true')))) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          offenders.add('${file.path}:${line + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'add `onTap:` to these Semantics (the same callback the '
            'GestureDetector under them runs) and `container: true`, so the '
            'button is its own element rather than merging with the text '
            'beside it');
  });

  testWidgets('the set checkmark can be activated through semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SetRow(
          index: 0,
          loadType: LoadType.bodyweight,
          entry: const SetEntry(id: 's', position: 0, completed: false, reps: 8),
          isPrefill: false,
          onChanged: (_) {},
          onToggleComplete: () => taps++,
          onDelete: () {},
        ),
      ),
    ));

    final node = tester.getSemantics(find.bySemanticsLabel('Complete set 1'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Complete set 1'));
    await tester.pump();
    expect(taps, 1);

    final add = tester.getSemantics(find.bySemanticsLabel('Add weight'));
    expect(add.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  // Found on the simulator after the upgrade (History, a month with no
  // workouts): VoiceOver read the whole month grid as one element, "1, no
  // workout logged, 1, 2, no workout logged, 2, ...", because a day cell
  // was not its own semantics node.
  testWidgets('each calendar day is its own element', (tester) async {
    final handle = tester.ensureSemantics();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        historySessionsProvider.overrideWithValue(<HistorySession>[
          HistorySession(
            id: 'a',
            performedOn: today,
            exercises: const <HistoryExercise>[],
          ),
        ]),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(child: HistoryCalendarCard()),
        ),
      ),
    ));

    // Named in full since audit B10: weekday, day, month, year, "today".
    final empty = LocalDate(today.year, today.month, today.day == 1 ? 2 : 1);
    expect(
        find.semantics
            .byLabel(RegExp('^${spokenDateLabel(empty)}, '
                '(no workout|not yet)\$'))
            .evaluate(),
        hasLength(1));
    expect(
        find.semantics
            .byLabel('${spokenDateLabel(LocalDate.fromDateTime(today))}, '
                'today, 1 workout')
            .evaluate(),
        hasLength(1));
    handle.dispose();
  });
}

/// The text of a `Semantics(` call's arguments up to its `child:`, skipping
/// nested brackets so a label built from an interpolation does not end it.
String _argumentsBeforeChild(String source, int start) {
  var depth = 0;
  final out = StringBuffer();
  for (var i = start; i < source.length && i < start + 2000; i++) {
    final c = source[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) break;
      depth--;
    }
    if (depth == 0 && source.startsWith('child:', i)) break;
    out.write(c);
  }
  return out.toString();
}
