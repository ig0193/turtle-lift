import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/custom_templates.dart';
import 'package:turtle_lift/src/data/settings_store.dart';
import 'package:turtle_lift/src/data/workout_templates.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/theme/app_theme.dart';
import 'package:turtle_lift/src/ui/template_library_screen.dart';

/// The only place templates are authored: what it offers on each kind of row,
/// and what it refuses to offer.
///
/// The writes go through a real in-memory database rather than a stubbed list,
/// because the thing worth proving is that duplicating actually persists — a
/// fixture override would pass while nothing reached the table.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  /// Eleven predefined rows plus the custom group do not fit the 800x600
  /// default, and a `ListView` only builds what is on screen -- so half these
  /// finders would miss widgets that exist and are simply below the fold.
  /// A tall viewport is the honest fix; scrolling before every tap would test
  /// the scroll position rather than the screen.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher
        .implicitView!;
    view.physicalSize = const Size(1200, 4200);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Widget host() => ProviderScope(
        key: UniqueKey(),
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const TemplateLibraryScreen(),
        ),
      );

  /// The names of the custom templates currently on screen, read from the
  /// provider rather than the widget tree so the assertion survives a layout
  /// change.
  List<String> customNames(WidgetTester tester) {
    final element = tester.element(find.byType(TemplateLibraryScreen));
    return ProviderScope.containerOf(element)
        .read(customTemplatesProvider)
        .map((template) => template.name)
        .toList();
  }

  group('what each kind of row offers', () {
    testWidgets('every predefined template offers duplicate and nothing else',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      for (final template in kPredefinedTemplates) {
        expect(
          find.byKey(TemplateLibraryScreen.duplicateKey(template.id)),
          findsOneWidget,
          reason: '${template.name} must be duplicable',
        );
        expect(
          find.byKey(TemplateLibraryScreen.renameKey(template.id)),
          findsNothing,
          reason: 'predefined templates are immutable -- they stay a reliable '
              'unmodified reference',
        );
        expect(
          find.byKey(TemplateLibraryScreen.deleteKey(template.id)),
          findsNothing,
          reason: 'a user must not be able to delete what ships with the app',
        );
      }
    });

    testWidgets('offers no way to create a template from scratch',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // KD4 defers the muscle-group builder. If someone adds it later this
      // fails, which is the prompt to update docs/04 in the same change rather
      // than leaving the docs claiming less than the app does.
      expect(find.textContaining('Create'), findsNothing);
      expect(find.textContaining('New template'), findsNothing);
    });

    testWidgets('says what the empty custom group is for', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        find.text(TemplateLibraryScreen.noCustomTemplatesLabel),
        findsOneWidget,
      );
    });
  });

  group('duplicating', () {
    testWidgets('adds one custom copy and leaves the original alone',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TemplateLibraryScreen.duplicateKey('push')));
      await tester.pumpAndSettle();

      expect(customNames(tester), <String>['Push day (mine)']);
      expect(
        find.text('Push day'),
        findsOneWidget,
        reason: 'the predefined row it came from is untouched',
      );
    });

    testWidgets('a second copy of the same template gets a distinct name',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TemplateLibraryScreen.duplicateKey('push')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TemplateLibraryScreen.duplicateKey('push')));
      await tester.pumpAndSettle();

      final names = customNames(tester);
      expect(names, hasLength(2));
      expect(
        names.toSet(),
        hasLength(2),
        reason: 'two copies sharing a name would be indistinguishable in the '
            'list and in the Workout landing',
      );
      expect(names, contains('Push day (mine)'));
      expect(names, contains('Push day (mine) 2'));
    });

    testWidgets('the copy carries the original\'s muscle groups',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TemplateLibraryScreen.duplicateKey('leg')));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TemplateLibraryScreen));
      final copy = ProviderScope.containerOf(element)
          .read(customTemplatesProvider)
          .single;
      final source =
          kPredefinedTemplates.firstWhere((t) => t.id == 'leg');

      expect(copy.groupIds, source.groupIds);
      expect(copy.isPredefined, isFalse);
    });

    testWidgets('the copy survives a fresh container on the same database',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TemplateLibraryScreen.duplicateKey('pull')));
      await tester.pumpAndSettle();

      // A new scope over the same database is what a relaunch looks like.
      final reopened = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(reopened.dispose);

      final stored = await readStoredCustomTemplates(
        reopened.read(customTemplateStoreProvider),
      );
      expect(stored.map((t) => t.name), <String>['Pull day (mine)']);
    });
  });

  group('deleting', () {
    Future<void> makeOne(WidgetTester tester) async {
      await tester.tap(find.byKey(TemplateLibraryScreen.duplicateKey('push')));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, and cancelling keeps the template',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await makeOne(tester);

      final id = ProviderScope.containerOf(
        tester.element(find.byType(TemplateLibraryScreen)),
      ).read(customTemplatesProvider).single.id;

      await tester.tap(find.byKey(TemplateLibraryScreen.deleteKey(id)));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cannot be undone'),
        findsOneWidget,
        reason: 'hard delete with no tombstone -- the user gets one chance to '
            'back out',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(customNames(tester), hasLength(1));
    });

    testWidgets('confirming removes it', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await makeOne(tester);

      final id = ProviderScope.containerOf(
        tester.element(find.byType(TemplateLibraryScreen)),
      ).read(customTemplatesProvider).single.id;

      await tester.tap(find.byKey(TemplateLibraryScreen.deleteKey(id)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(customNames(tester), isEmpty);
      expect(
        find.text('Push day'),
        findsOneWidget,
        reason: 'deleting a copy never touches the template it came from',
      );
    });

    testWidgets('the destructive glyph is the only thing painted danger',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await makeOne(tester);

      final id = ProviderScope.containerOf(
        tester.element(find.byType(TemplateLibraryScreen)),
      ).read(customTemplatesProvider).single.id;

      final deleteIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(TemplateLibraryScreen.deleteKey(id)),
          matching: find.byType(Icon),
        ),
      );
      final renameIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(TemplateLibraryScreen.renameKey(id)),
          matching: find.byType(Icon),
        ),
      );

      expect(deleteIcon.color, AppPalette.danger);
      expect(
        renameIcon.color,
        isNot(AppPalette.danger),
        reason: 'renaming is not destructive and must not borrow its colour',
      );
      expect(
        renameIcon.color,
        isNot(AppPalette.accentStrong),
        reason: 'accentStrong means "this has been worked" everywhere in the '
            'app; on an action glyph it would read as approval',
      );
    });
  });

  group('renaming', () {
    testWidgets('changes the name and keeps the groups', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TemplateLibraryScreen.duplicateKey('push')));
      await tester.pumpAndSettle();

      final before = ProviderScope.containerOf(
        tester.element(find.byType(TemplateLibraryScreen)),
      ).read(customTemplatesProvider).single;

      await tester.tap(find.byKey(TemplateLibraryScreen.renameKey(before.id)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Heavy push');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final after = ProviderScope.containerOf(
        tester.element(find.byType(TemplateLibraryScreen)),
      ).read(customTemplatesProvider).single;

      expect(after.name, 'Heavy push');
      expect(after.id, before.id, reason: 'the id is stable across renames');
      expect(after.groupIds, before.groupIds);
    });

    testWidgets('an emptied name is refused rather than saved', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TemplateLibraryScreen.duplicateKey('push')));
      await tester.pumpAndSettle();

      final id = ProviderScope.containerOf(
        tester.element(find.byType(TemplateLibraryScreen)),
      ).read(customTemplatesProvider).single.id;

      await tester.tap(find.byKey(TemplateLibraryScreen.renameKey(id)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        customNames(tester),
        <String>['Push day (mine)'],
        reason: 'a blank row would be unidentifiable in the Workout landing',
      );
    });
  });

  group('the duplicate-naming rule', () {
    test('the first copy matches the name docs/04 documents', () {
      expect(duplicateName('Push day', const <String>{}), 'Push day (mine)');
    });

    test('later copies number upward', () {
      expect(
        duplicateName('Push day', const <String>{'Push day (mine)'}),
        'Push day (mine) 2',
      );
      expect(
        duplicateName(
          'Push day',
          const <String>{'Push day (mine)', 'Push day (mine) 2'},
        ),
        'Push day (mine) 3',
      );
    });

    test('a freed name is reused rather than leaving a gap', () {
      // Deleting "(mine) 2" and duplicating again should reuse 2, not skip to
      // 4 and leave the user looking at a number they cannot explain.
      expect(
        duplicateName(
          'Push day',
          const <String>{'Push day (mine)', 'Push day (mine) 3'},
        ),
        'Push day (mine) 2',
      );
    });
  });
}
