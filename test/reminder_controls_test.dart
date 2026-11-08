import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/reminder_controls.dart';

import 'support/fake_reminder_scheduler.dart';

/// The reminder controls Schedule (U16) and Diet's Reminders screen (U17)
/// share: the row with a drawn switch, the time row, the explain-first sheet
/// and the opt-in flow that orders sheet, then OS prompt (ADR 0005 §3, A9).
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: Center(child: child)),
      );

  const switchKey = ValueKey<String>('switch');
  const allowKey = ValueKey<String>('allow');
  const notNowKey = ValueKey<String>('not-now');

  group('SwitchRow', () {
    testWidgets('announces its state and runs onTap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(host(SwitchRow(
        switchKey: switchKey,
        title: 'Remind me',
        subtitle: 'Notification on training days',
        value: true,
        onTap: () => taps++,
      )));

      expect(
        tester.getSemantics(find.byKey(switchKey)),
        isSemantics(
          label: 'Remind me. Notification on training days',
          isToggled: true,
          hasToggledState: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byKey(switchKey));
      expect(taps, 1);
      expect(tester.widget<ReminderSwitch>(find.byType(ReminderSwitch)).on,
          isTrue);
      handle.dispose();
    });

    testWidgets('with no onTap it is disabled and says so', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const SwitchRow(
        switchKey: switchKey,
        title: 'Lunch',
        subtitle: 'Turn on reminders to set times',
        value: false,
        onTap: null,
      )));

      expect(
        tester.getSemantics(find.byKey(switchKey)),
        isSemantics(
          label: 'Lunch. Turn on reminders to set times',
          isToggled: false,
          hasToggledState: true,
          isEnabled: false,
          hasEnabledState: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled, the reason stays at full strength; only the title '
        'and switch dim (taste pass: muted text 4.5:1)', (tester) async {
      await tester.pumpWidget(host(const SwitchRow(
        switchKey: switchKey,
        title: 'Lunch',
        subtitle: 'Turn on reminders to set times',
        value: false,
        onTap: null,
      )));

      final reason = find.text('Turn on reminders to set times');
      expect(
        find.ancestor(of: reason, matching: find.byType(Opacity)),
        findsNothing,
        reason: 'the reason a row is disabled must stay readable',
      );
      final title = find.text('Lunch');
      final dim = tester.widget<Opacity>(
          find.ancestor(of: title, matching: find.byType(Opacity)).first);
      expect(dim.opacity, lessThan(1));
    });
  });

  testWidgets('TimeRow shows its label and time and is a button',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(host(TimeRow(
      key: const ValueKey<String>('time'),
      label: 'Morning summary',
      time: '7:30 AM',
      onTap: () => taps++,
    )));

    expect(find.text('Morning summary'), findsOneWidget);
    expect(find.text('7:30 AM'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey<String>('time'))),
      isSemantics(
        label: 'Morning summary. 7:30 AM',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('time')));
    expect(taps, 1);
    handle.dispose();
  });

  group('optInToReminders', () {
    Future<ReminderOptIn?> run(
      WidgetTester tester,
      FakeReminderScheduler fake, {
      Key? tapKey,
    }) async {
      ReminderOptIn? result;
      await tester.pumpWidget(host(Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await optInToReminders(
              context,
              scheduler: fake,
              title: 'Remind you on meal times?',
              body: 'One notification per meal you switch on.',
              allowKey: allowKey,
              notNowKey: notNowKey,
            );
          },
          child: const Text('go'),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      if (tapKey != null) {
        expect(find.text('Remind you on meal times?'), findsOneWidget);
        expect(find.text('One notification per meal you switch on.'),
            findsOneWidget);
        await tester.tap(find.byKey(tapKey));
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('Not now declines and requests nothing', (tester) async {
      final fake = FakeReminderScheduler();
      expect(await run(tester, fake, tapKey: notNowKey), ReminderOptIn.declined);
      expect(fake.calls, isEmpty);
    });

    testWidgets('Allow asks the OS; a grant is granted', (tester) async {
      final fake = FakeReminderScheduler();
      expect(await run(tester, fake, tapKey: allowKey), ReminderOptIn.granted);
      expect(fake.calls, <String>['request']);
    });

    testWidgets('Allow asks the OS; a refusal is denied', (tester) async {
      final fake = FakeReminderScheduler(grantOnRequest: false);
      expect(await run(tester, fake, tapKey: allowKey), ReminderOptIn.denied);
      expect(fake.calls, <String>['request']);
    });

    testWidgets('already permitted: no sheet, no prompt', (tester) async {
      final fake = FakeReminderScheduler(permitted: true);
      expect(await run(tester, fake), ReminderOptIn.granted);
      expect(find.byType(ExplainSheet), findsNothing);
      expect(fake.calls, isEmpty);
    });

    testWidgets('dismissing the sheet counts as Not now', (tester) async {
      final fake = FakeReminderScheduler();
      ReminderOptIn? result;
      await tester.pumpWidget(host(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await optInToReminders(
            context,
            scheduler: fake,
            title: 'T',
            body: 'B',
          ),
          child: const Text('go'),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // the barrier
      await tester.pumpAndSettle();

      expect(result, ReminderOptIn.declined);
      expect(fake.calls, isEmpty);
    });
  });

  testWidgets('the explain sheet has one filled button: Allow', (tester) async {
    await tester.pumpWidget(host(const ExplainSheet(
      title: 'T',
      body: 'B',
      allowKey: allowKey,
      notNowKey: notNowKey,
    )));

    expect(find.byType(FilledButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(allowKey),
        matching: find.text('Allow reminders'),
      ),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('the notifications-off note says where to fix it',
      (tester) async {
    await tester.pumpWidget(host(const NotificationsOffNote()));
    expect(
      find.text(
          'Notifications are off for TurtleLift. Turn them on in Settings.'),
      findsOneWidget,
    );
  });

  group('reminder minutes', () {
    testWidgets('format as the platform time of day', (tester) async {
      late String text;
      await tester.pumpWidget(host(Builder(builder: (context) {
        text = formatReminderMinute(context, 18 * 60 + 30);
        return const SizedBox();
      })));
      expect(text, '6:30 PM');
    });

    testWidgets('the picker returns the chosen minute, or null on cancel',
        (tester) async {
      final results = <int?>[];
      await tester.pumpWidget(host(Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              results.add(await pickReminderMinute(context, 7 * 60 + 5)),
          child: const Text('go'),
        ),
      )));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, <int?>[7 * 60 + 5, null]);
    });
  });
}
