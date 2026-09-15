import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/load_type.dart';
import 'package:turtle_lift/src/data/session_store.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/set_row.dart';
import 'package:turtle_lift/src/ui/stepper_field.dart';

/// Proves the one row that logs all four load types.
void main() {
  SetEntry entry({
    double? weightKg,
    int? reps,
    double? addedKg,
    double? assistKg,
    int? durationSec,
    bool completed = false,
  }) =>
      SetEntry(
        id: 'set-1',
        position: 0,
        completed: completed,
        weightKg: weightKg,
        reps: reps,
        addedKg: addedKg,
        assistKg: assistKg,
        durationSec: durationSec,
      );

  /// Pumps one row and reports what it emitted.
  Future<({List<SetEntry> changes, List<String> events})> pumpRow(
    WidgetTester tester, {
    required LoadType loadType,
    required SetEntry value,
    bool isPrefill = false,
  }) async {
    final changes = <SetEntry>[];
    final events = <String>[];
    var current = value;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SetRow(
              index: 0,
              loadType: loadType,
              entry: current,
              isPrefill: isPrefill,
              onChanged: (next) {
                changes.add(next);
                setState(() => current = next);
              },
              onToggleComplete: () => events.add('complete'),
              onDelete: () => events.add('delete'),
            ),
          ),
        ),
      ),
    );
    return (changes: changes, events: events);
  }

  group('the four row shapes', () {
    testWidgets('weighted shows a weight and a rep field', (tester) async {
      await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60, reps: 8));

      expect(find.text('kg'), findsOneWidget);
      expect(find.text('reps'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('assisted labels its weight as assistance', (tester) async {
      await pumpRow(tester,
          loadType: LoadType.assisted, value: entry(assistKg: 20, reps: 8));

      expect(find.text('assist'), findsOneWidget);
      expect(find.text('reps'), findsOneWidget);
    });

    testWidgets('bodyweight shows reps and a collapsed weight chip',
        (tester) async {
      await pumpRow(tester, loadType: LoadType.bodyweight, value: entry(reps: 12));

      expect(find.text('reps'), findsOneWidget);
      expect(find.text('+ weight'), findsOneWidget);
      expect(find.text('kg'), findsNothing);
    });

    testWidgets('timed shows a duration and a collapsed weight chip',
        (tester) async {
      await pumpRow(tester,
          loadType: LoadType.timed, value: entry(durationSec: 45));

      expect(find.text('0:45'), findsOneWidget);
      expect(find.text('+ weight'), findsOneWidget);
    });
  });

  group('the optional weight chip', () {
    testWidgets('expands on tap, on bodyweight', (tester) async {
      await pumpRow(tester, loadType: LoadType.bodyweight, value: entry(reps: 12));

      await tester.tap(find.text('+ weight'));
      await tester.pump();

      expect(find.text('+ weight'), findsNothing);
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('starts expanded when a weight is already recorded',
        (tester) async {
      await pumpRow(tester,
          loadType: LoadType.bodyweight, value: entry(reps: 8, addedKg: 10));

      expect(find.text('+ weight'), findsNothing);
      expect(find.text('10'), findsOneWidget);
    });
  });

  group('completing a set', () {
    testWidgets('a full required field completes it', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60, reps: 8));

      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await tester.pump();

      expect(result.events, <String>['complete']);
    });

    testWidgets('an empty required field focuses it instead', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60));

      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await tester.pump();

      expect(
        result.events,
        isEmpty,
        reason: 'tapping the tick on an empty required field focuses that '
            'field rather than completing the set',
      );
      final repsField = tester.widgetList<TextField>(find.byType(TextField));
      expect(repsField.any((f) => f.focusNode?.hasFocus ?? false), isTrue);
    });

    testWidgets('a zero duration does not complete a timed set',
        (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.timed, value: entry(durationSec: 0));

      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await tester.pump();

      expect(result.events, isEmpty);
    });

    testWidgets('an already-complete set can be un-ticked', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.weighted,
          value: entry(weightKg: 60, reps: 8, completed: true));

      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await tester.pump();

      expect(result.events, <String>['complete']);
    });
  });

  group('the steppers', () {
    testWidgets('weight moves in 2.5kg steps', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60, reps: 8));

      await tester.tap(find.bySemanticsLabel('Increase').first);
      await tester.pump();

      expect(result.changes.last.weightKg, 62.5);
    });

    testWidgets('reps move in single steps', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.bodyweight, value: entry(reps: 8));

      await tester.tap(find.bySemanticsLabel('Increase').first);
      await tester.pump();

      expect(result.changes.last.reps, 9);
    });

    testWidgets('duration moves in five-second steps', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.timed, value: entry(durationSec: 45));

      await tester.tap(find.bySemanticsLabel('Increase').first);
      await tester.pump();

      expect(result.changes.last.durationSec, 50);
    });

    testWidgets('never steps below zero', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.bodyweight, value: entry(reps: 0));

      await tester.tap(find.bySemanticsLabel('Decrease').first);
      await tester.pump();

      expect(
        result.changes.last.reps,
        0,
        reason: 'the sign in this app is carried by the load type, never typed',
      );
    });
  });

  group('the keypad', () {
    testWidgets('refuses a minus sign', (tester) async {
      await pumpRow(tester, loadType: LoadType.bodyweight, value: entry());

      await tester.enterText(find.byType(TextField).first, '-5');
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '5',
        reason: 'there is no minus key anywhere in this app',
      );
    });

    testWidgets('accepts one decimal place on a weight', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(reps: 8));

      await tester.enterText(find.byType(TextField).first, '57.5');
      await tester.pump();

      expect(result.changes.last.weightKg, 57.5);
    });

    testWidgets('refuses a decimal point on reps', (tester) async {
      await pumpRow(tester, loadType: LoadType.bodyweight, value: entry());

      await tester.enterText(find.byType(TextField).first, '8.5');
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '85',
      );
    });
  });

  group('clearing a field', () {
    testWidgets('emptying the weight really clears it', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60, reps: 8));

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      expect(
        result.changes.last.weightKg,
        isNull,
        reason: 'a cleared field that quietly keeps its old number would let a '
            'set complete with a value the user deleted',
      );
      expect(result.changes.last.reps, 8, reason: 'the other field is intact');
    });

    testWidgets('emptying the required field blocks completion', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.bodyweight, value: entry(reps: 8));

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      await tester.tap(find.byKey(SetRow.checkKey(0)));
      await tester.pump();

      expect(result.events, isEmpty);
    });
  });

  group('prefill rendering', () {
    testWidgets('a guess renders muted and an entry does not', (tester) async {
      await pumpRow(tester,
          loadType: LoadType.weighted,
          value: entry(weightKg: 60, reps: 8),
          isPrefill: true);

      final mutedStyle =
          tester.widget<TextField>(find.byType(TextField).first).style!;
      expect(mutedStyle.color, const Color(0xFF6B6156));

      await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60, reps: 8));

      final enteredStyle =
          tester.widget<TextField>(find.byType(TextField).first).style!;
      expect(enteredStyle.color, const Color(0xFFF5EFE8));
    });
  });

  group('deleting', () {
    testWidgets('a long press removes the row', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60, reps: 8));

      await tester.longPress(find.byKey(SetRow.rowKey(0)));
      await tester.pump();

      expect(
        result.events,
        <String>['delete'],
        reason: 'removal must not depend on a swipe the user cannot make '
            'one-handed',
      );
    });

    testWidgets('a swipe removes the row', (tester) async {
      final result = await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60, reps: 8));

      await tester.drag(find.byType(Dismissible), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(result.events, <String>['delete']);
    });
  });

  group('at a real phone width', () {
    /// The widest row — two steppers, two units, a set number and a checkmark,
    /// every field carrying its longest plausible value — at 375 points, the
    /// narrowest width any shipping iPhone still has.
    ///
    /// Every other test here runs at the default 800x600 viewport, which is
    /// wider than any phone and hid a 24-point overflow until the app was run
    /// on a simulator. This is that check, written down.
    Future<void> pumpNarrow(WidgetTester tester, LoadType loadType) async {
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SetRow(
                index: 0,
                loadType: loadType,
                entry: entry(
                  weightKg: 137.5,
                  reps: 12,
                  assistKg: 137.5,
                  durationSec: 3600,
                ),
                isPrefill: false,
                onChanged: (_) {},
                onToggleComplete: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final loadType in LoadType.values) {
      testWidgets('${loadType.name} lays out without overflowing',
          (tester) async {
        await pumpNarrow(tester, loadType);

        expect(
          tester.takeException(),
          isNull,
          reason: 'a row that overflows paints the striped warning over the '
              'numbers the user is trying to read',
        );
      });
    }
  });

  group('tap targets', () {
    testWidgets('the checkmark and the steppers clear the 48pt floor',
        (tester) async {
      await pumpRow(tester,
          loadType: LoadType.weighted, value: entry(weightKg: 60, reps: 8));

      expect(tester.getSize(find.byKey(SetRow.checkKey(0))).height,
          greaterThanOrEqualTo(48));
      final stepper = find.bySemanticsLabel('Increase').first;
      expect(tester.getSize(stepper).height, greaterThanOrEqualTo(48));
    });
  });

  group('the field widget itself', () {
    testWidgets('disposes a focus node it owns and leaves a supplied one',
        (tester) async {
      final supplied = FocusNode();
      addTearDown(supplied.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: StepperField(
              value: 10,
              step: 1,
              focusNode: supplied,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Reaching the supplied node after the widget is gone would throw if the
      // widget had disposed something it does not own.
      expect(supplied.hasFocus, isFalse);
    });
  });
}
