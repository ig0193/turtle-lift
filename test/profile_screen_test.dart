import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/app_screen.dart';
import 'package:turtle_lift/src/ui/divider_row.dart';
import 'package:turtle_lift/src/ui/profile_screen.dart';

/// The destination behind the header avatar: four doors, and one rule about
/// what may not appear on the way to them.
///
/// The load-bearing test in this file is the last group. Everything above it
/// is the screen doing its job; **"nothing derived is rendered here" is the
/// executable form of KD1** — authored data lives behind the avatar, data
/// computed from session rows lives on the History tab — and it is the one
/// assertion that has to survive every future edit to this screen by someone
/// who has not read `docs/04`.
void main() {
  /// A custom template, shaped as `workout_root_test.dart` shapes one. Only
  /// the count is read here, but a real value is cheaper to trust than a
  /// stand-in.
  WorkoutTemplate customTemplate(String id) => WorkoutTemplate(
        id: id,
        name: 'My $id',
        groupIds: const <String>['biceps'],
        filters: const <TemplateFilter>{},
        isPredefined: false,
      );

  /// Hosts the screen as the shell pushes it: inside a `MaterialApp`, so a row
  /// tap has a real `Navigator` to push onto.
  ///
  /// [custom] seeds the authored template count. The four builders are the
  /// destination seams — passing one swaps that row's destination for a
  /// sentinel, which is how "tapping this row navigates" is asserted without
  /// naming a screen another unit is still writing.
  ///
  /// **Overrides are passed as a literal rather than through a typed
  /// parameter** because riverpod 3 does not export the `Override` type, so
  /// there is no name to give such a parameter. The builders are the typed
  /// surface instead.
  ///
  /// [windowPadding] is injected rather than defaulted so the bottom-inset
  /// assertion below has something to detect.
  Widget host({
    List<WorkoutTemplate> custom = const <WorkoutTemplate>[],
    WidgetBuilder? templatesDestination,
    WidgetBuilder? personalDetailsDestination,
    WidgetBuilder? exportDestination,
    WidgetBuilder? deleteAllDestination,
    ProviderObserver? observer,
    EdgeInsets windowPadding = EdgeInsets.zero,
  }) {
    return ProviderScope(
      observers: observer == null ? null : <ProviderObserver>[observer],
      overrides: [
        customTemplatesProvider.overrideWithValue(custom),
        if (templatesDestination != null)
          profileTemplatesDestinationProvider
              .overrideWithValue(templatesDestination),
        if (personalDetailsDestination != null)
          profilePersonalDetailsDestinationProvider
              .overrideWithValue(personalDetailsDestination),
        if (exportDestination != null)
          profileExportDestinationProvider
              .overrideWithValue(exportDestination),
        if (deleteAllDestination != null)
          profileDeleteAllDestinationProvider
              .overrideWithValue(deleteAllDestination),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(padding: windowPadding),
          child: const ProfileScreen(),
        ),
      ),
    );
  }

  /// A stand-in for a destination screen that another unit is building. The
  /// tests below assert against *the seam*, never against a real screen —
  /// wiring `TemplateLibraryScreen` into the provider's default must not turn
  /// these red.
  Widget sentinel(String label) => Scaffold(body: Text('sentinel-$label'));

  group('what it lists', () {
    testWidgets('renders the four rows under their two group labels',
        (tester) async {
      await tester.pumpWidget(host());

      expect(find.text(ProfileScreen.yoursGroupLabel), findsOneWidget);
      expect(find.text(ProfileScreen.dataGroupLabel), findsOneWidget);

      expect(find.text(templatesRowTitle), findsOneWidget);
      expect(find.text(personalDetailsRowTitle), findsOneWidget);
      expect(find.text(exportRowTitle), findsOneWidget);
      expect(find.text(deleteAllRowTitle), findsOneWidget);

      expect(find.byType(DividerRow), findsNWidgets(4),
          reason: 'R4: templates, personal details, export, delete all — and '
              'nothing else that behaves like a row');
    });

    testWidgets('rows read out as buttons, with their second line',
        (tester) async {
      await tester.pumpWidget(host());

      // No `hasTapAction` in either matcher, and that is a finding rather
      // than a relaxed assertion: `DividerRow` wraps its gesture detector in a
      // `Semantics(excludeSemantics: true)`, which drops the detector's own
      // tap action along with its children's labels. Every divider row in the
      // app announces as a button that a screen reader cannot activate --
      // `TemplateRow` and `SubGroupRow` included. Fixing it belongs to
      // `divider_row.dart`, not to this screen, so this test pins what is
      // true today rather than quietly asserting less than it means.
      expect(
        tester.getSemantics(find.byKey(profileRowKey('personal-details'))),
        isSemantics(
          label: '$personalDetailsRowTitle. $personalDetailsRowSubtitle',
          isButton: true,
        ),
        reason: 'the row excludes its children, so its own label is all a '
            'screen reader hears',
      );
      expect(
        tester.getSemantics(find.byKey(profileRowKey('export'))),
        isSemantics(label: exportRowTitle, isButton: true),
        reason: 'a row with no second line says only its name — not its name '
            'and a trailing full stop',
      );
    });

    testWidgets('the template line counts authored templates, not sessions',
        (tester) async {
      await tester.pumpWidget(
        host(custom: <WorkoutTemplate>[customTemplate('a'), customTemplate('b')]),
      );

      expect(
        find.text(
          templateCountLabel(
            predefined: kPredefinedTemplates.length,
            custom: 2,
          ),
        ),
        findsOneWidget,
        reason: 'both halves are authored: a const list and rows the user '
            'typed. This is the one figure R2 permits here.',
      );
    });

    testWidgets('the custom half of that line follows the user\'s templates',
        (tester) async {
      await tester.pumpWidget(host());
      expect(find.textContaining('0 custom'), findsOneWidget,
          reason: 'a user with no templates of their own is a state, not a '
              'reason to hide the count');

      await tester.pumpWidget(host(custom: <WorkoutTemplate>[customTemplate('a')]));
      expect(find.textContaining('1 custom'), findsOneWidget,
          reason: 'the count is watched, so saving a template changes it');
    });
  });

  group('where a row goes', () {
    /// Taps [id] and settles the push.
    Future<void> tapRow(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(profileRowKey(id)));
      await tester.pumpAndSettle();
    }

    testWidgets('each row pushes its own destination seam', (tester) async {
      await tester.pumpWidget(host(
        templatesDestination: (_) => sentinel('templates'),
        personalDetailsDestination: (_) => sentinel('details'),
        exportDestination: (_) => sentinel('export'),
        deleteAllDestination: (_) => sentinel('delete'),
      ));

      // One pump per row, popping back each time, so a row wired to the wrong
      // provider shows up as the wrong sentinel rather than as a pass.
      for (final pair in const <(String, String)>[
        ('templates', 'templates'),
        ('personal-details', 'details'),
        ('export', 'export'),
        ('delete-all', 'delete'),
      ]) {
        await tapRow(tester, pair.$1);
        expect(find.text('sentinel-${pair.$2}'), findsOneWidget,
            reason: 'the ${pair.$1} row must push its own seam');

        Navigator.of(tester.element(find.text('sentinel-${pair.$2}'))).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the push is opaque, so nothing of the shell shows through',
        (tester) async {
      await tester.pumpWidget(
        host(templatesDestination: (_) => sentinel('templates')),
      );
      await tapRow(tester, 'templates');

      expect(find.text('Profile'), findsNothing,
          reason: 'an opaque route covers what it is pushed over — the same '
              'mechanism that takes the floating tab bar offstage (L0Shell)');
      expect(find.text(templatesRowTitle), findsNothing,
          reason: 'the rows behind it go too -- this is a push over the '
              'screen, not a sheet above it');
    });

    testWidgets('an unwired seam still opens a real screen', (tester) async {
      // The default builders point at a placeholder today and at the real
      // screens tomorrow. Either way a tap must navigate: a row that does
      // nothing is indistinguishable from a bug.
      await tester.pumpWidget(host());
      await tapRow(tester, 'templates');

      expect(find.text('Profile'), findsNothing,
          reason: 'the default destination is a pushed screen, not a no-op');
      expect(find.byIcon(Icons.chevron_left), findsOneWidget,
          reason: 'and it is an AppScreen.pushed, so it can be backed out of');
    });
  });

  group('nothing derived is rendered here', () {
    /// Every string this screen puts on the glass, plus every semantics label
    /// it announces.
    ///
    /// Both, because the two ways a figure could arrive are a `Text` and a
    /// label on a row that excludes its children's semantics — and a streak
    /// announced only to a screen reader would still be a streak.
    List<String> spokenAndWritten(WidgetTester tester) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label ?? '');
      return <String>[...texts, ...labels]
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }

    testWidgets('no figure on this screen comes from a session row',
        (tester) async {
      await tester.pumpWidget(
        host(custom: <WorkoutTemplate>[customTemplate('a')]),
      );

      // The allowlist is one string long, and it is built from the same
      // function the screen builds it from -- so it cannot be widened by
      // accident, only by editing this line. Every other digit anywhere on
      // this screen fails here.
      final authored = templateCountLabel(
        predefined: kPredefinedTemplates.length,
        custom: 1,
      );
      final digit = RegExp(r'\d');

      for (final rendered in spokenAndWritten(tester)) {
        if (!digit.hasMatch(rendered)) continue;
        expect(
          rendered,
          contains(authored),
          reason: 'KD1/R2: the only number allowed behind the avatar is the '
              'authored template count. "$rendered" is a figure this screen '
              'may not show — if it is computed from session rows (a streak, '
              'a workout or set count, a personal best, a calorie estimate) '
              'it belongs on the History tab. If it is genuinely authored, '
              'widening this allowlist is a decision, not a fix.',
        );
      }
    });

    testWidgets('and says none of the words a derived figure arrives with',
        (tester) async {
      // The second net, because the first one has a gap: "Current streak" with
      // the number still to come, or a stat tile rendered before its provider
      // exists, carries no digit at all. These are the words `docs/01`
      // §Derived values uses for the things computed on read.
      final derivedVocabulary = RegExp(
        r'\b(streak|streaks|session|sessions|set|sets|rep|reps|'
        r'calorie|calories|kcal|volume|total|totals|average|'
        r'personal best|personal bests|pb|pbs|trained)\b',
        caseSensitive: false,
      );

      await tester.pumpWidget(host(custom: <WorkoutTemplate>[customTemplate('a')]));

      for (final rendered in spokenAndWritten(tester)) {
        expect(
          derivedVocabulary.hasMatch(rendered),
          isFalse,
          reason: 'KD1/R2: "$rendered" names something the app derives from '
              'session rows. Derived lives on the History tab; only what the '
              'user typed lives behind the avatar.',
        );
      }
    });

    testWidgets('it watches no provider beyond the authored template list',
        (tester) async {
      // The structural half of the same rule, and the one that fails before a
      // figure is ever rendered: a derived number has to come from somewhere.
      // The moment this screen watches a session provider, this set grows and
      // someone has to justify the new entry.
      final read = <Object>{};
      await tester.pumpWidget(host(observer: _RecordingObserver(read)));

      expect(
        read,
        <Object>{customTemplatesProvider},
        reason: 'the screen reads exactly one provider for content, and it '
            'holds authored data. A new entry here is a new source of truth '
            'on a screen that is meant to have one -- check it is not '
            'computed from session rows before widening this.',
      );
    });
  });

  group('the screen shell', () {
    testWidgets('is one Scaffold with a pinned header', (tester) async {
      // A short viewport, so four rows plus their labels genuinely overflow
      // and the fling below is a real scroll rather than a no-op.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 260);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host());

      expect(find.byType(Scaffold), findsOneWidget,
          reason: 'the screen is an AppScreen.pushed, not a Scaffold inside a '
              'Scaffold');
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Profile'),
        ),
        findsNothing,
        reason: 'the title is the Scaffold.appBar, never a row in the scroll '
            'view (see AppScreen)',
      );

      final before = tester.getTopLeft(find.text('Profile'));
      await tester.fling(find.byType(ListView), const Offset(0, -200), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget,
          reason: 'the header scrolled away');
      expect(tester.getTopLeft(find.text('Profile')), before,
          reason: 'the header moved');
    });

    testWidgets('the scrollable carries the one padding rule', (tester) async {
      await tester.pumpWidget(
        host(windowPadding: const EdgeInsets.fromLTRB(11, 47, 13, 34)),
      );

      final padding = tester.widget<ListView>(find.byType(ListView)).padding;
      expect(padding, screenScrollPadding(tester.element(find.byType(ListView))),
          reason: 'a pushed screen picks up the home indicator on the bottom '
              'edge; a SafeArea here would silently zero it');
      expect((padding! as EdgeInsets).bottom, kScreenGutter + 34,
          reason: 'gutter plus the inset, spent on the scrollable itself');
    });

    testWidgets('every row clears the 48pt tap target', (tester) async {
      await tester.pumpWidget(host());

      for (final id in const <String>[
        'templates',
        'personal-details',
        'export',
        'delete-all',
      ]) {
        expect(
          tester.getSize(find.byKey(profileRowKey(id))).height,
          greaterThanOrEqualTo(DividerRow.minHeight),
          reason: 'the $id row is read standing, one-handed, like every other '
              'row in this app',
        );
      }
    });
  });

  group('the destructive row', () {
    testWidgets('delete-all is the only thing painted in danger',
        (tester) async {
      await tester.pumpWidget(host());

      expect(tester.widget<Text>(find.text(deleteAllRowTitle)).style?.color,
          AppPalette.danger,
          reason: '§12: the eleventh colour exists for exactly this row');

      final otherTitles = <String>[
        templatesRowTitle,
        personalDetailsRowTitle,
        exportRowTitle,
      ];
      for (final title in otherTitles) {
        expect(
          tester.widget<Text>(find.text(title)).style?.color,
          isNot(AppPalette.danger),
          reason: 'danger is destructive-only -- "$title" destroys nothing, '
              'and export least of all',
        );
      }
    });

    testWidgets('its chevron stays muted like every other row', (tester) async {
      await tester.pumpWidget(host());

      final chevrons = tester
          .widgetList<Icon>(find.byIcon(Icons.chevron_right_rounded))
          .map((icon) => icon.color)
          .toSet();
      expect(chevrons, <Color>{AppPalette.textMuted},
          reason: 'the warning belongs to the words; the row only opens a '
              'confirmation, so its arrow must not shout');
    });
  });
}

/// Records every provider the screen actually causes to be created.
///
/// A `ProviderObserver` rather than `ProviderContainer.getAllProviderElements`,
/// which riverpod 3 marks `@internal` and does not export.
final class _RecordingObserver extends ProviderObserver {
  _RecordingObserver(this.seen);

  final Set<Object> seen;

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    seen.add(context.provider);
  }
}
