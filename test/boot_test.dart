import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_lift/main.dart' as app;
import 'package:turtle_lift/src/data/app_database.dart';
import 'package:turtle_lift/src/data/exercise_index.dart';
import 'package:turtle_lift/src/data/exercise_library.dart';
import 'package:turtle_lift/src/theme/app_palette.dart';
import 'package:turtle_lift/src/ui/l0_shell.dart';
import 'package:turtle_lift/src/ui/muscles_root.dart';

/// What the app opens on. Cheap to break and expensive to notice: `main.dart`
/// is edited rarely and by hand, and a wrong `home:` still compiles, still
/// renders and still passes every widget test that pumps its own screen.
///
/// **One of these tests runs `main()` itself.** Pumping `TurtleLiftApp` with a
/// hand-copied override list — which is all this file used to do — proves the
/// list in this file, not the one in `main.dart`. Deleting
/// `exerciseIndexProvider` from the real boot would have thrown on the Muscles
/// root's first frame on a device, and left every test green.
void main() {
  // The exercise library is read off `rootBundle`, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // `main()` opens its own database while this file's tests hold others.
  // Drift flags that on debug builds as a possible mistake; here it is the
  // arrangement under test.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// The shipped library, indexed the way `main()` indexes it.
  ///
  /// Only the direct-pump tests below need this. The test that runs `main()`
  /// deliberately does not build an index of its own — `main()` building the
  /// right one is the thing being asserted.
  late ExerciseIndex index;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    index = ExerciseIndex.fromJson(
      await container.read(exerciseLibraryProvider.future),
    );
  });

  testWidgets('the app boots into the L0 shell on the page background',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [exerciseIndexProvider.overrideWithValue(index)],
        child: const app.TurtleLiftApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(L0Shell), findsOneWidget,
        reason: 'the app must open on the tab shell, not on any other screen');

    // Which tab it opens on is part of the boot contract, and only this file
    // exercises the real TurtleLiftApp path -- the shell's own tests host
    // L0Shell directly and would not notice main.dart handing it a different
    // starting index.
    expect(find.text('TEMPLATES').hitTestable(), findsOneWidget,
        reason: 'the app opens on the Workout tab, which lists the templates');

    final context = tester.element(find.byType(L0Shell));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppPalette.pageBackground,
      reason: 'the shell must sit on the palette page background',
    );
  });

  testWidgets('running main() itself boots an app with every provider it '
      'needs already overridden', (tester) async {
    // The one thing swapped out, and the reason `openAppDatabase` exists: the
    // real constructor reaches `path_provider`, which has no platform channel
    // here. Everything else below is `main()` as it ships.
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    app.openAppDatabase = () => database;
    addTearDown(() async {
      app.openAppDatabase = AppDatabase.new;
      await database.close();
    });

    // **`runAsync`, because `main()`'s two awaits are real I/O.** A
    // `testWidgets` body runs under fake async, where the asset read and the
    // database query never complete and the boot simply hangs. This is the
    // one place in the suite that needs it, and it is needed precisely
    // because the entrypoint is being run rather than imitated.
    await tester.runAsync(app.main);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'booting the real entrypoint must not throw');
    expect(find.byType(ErrorWidget), findsNothing,
        reason: 'a provider that threw during build renders an ErrorWidget '
            'rather than failing the pump');
    expect(find.byType(L0Shell), findsOneWidget);

    // The assertion this test exists for. `L0Shell` mounts all three roots in
    // an IndexedStack, so the Muscles root builds on the first frame whichever
    // tab is showing -- and it reads `exerciseIndexProvider`, which throws
    // rather than defaulting. Drop that override from `main()` and this line
    // is what catches it.
    // `skipOffstage: false` because the IndexedStack keeps the two unselected
    // roots mounted but off stage; the app opens on Workout.
    final muscles = find.byType(MusclesRoot, skipOffstage: false);
    expect(muscles, findsOneWidget,
        reason: 'the Muscles root must build under the boot overrides that '
            "main() installs, not under a test file's copy of them");

    // And it must have a real index, not merely an instance: the heading is
    // counted from the taxonomy and the rows are counted from the library, so
    // a root that rendered with an empty index would still be found above.
    final shellContext = tester.element(muscles);
    expect(
      ProviderScope.containerOf(shellContext).read(exerciseIndexProvider).all,
      hasLength(260),
      reason: 'main() must fold the shipped library into the index it '
          'overrides with -- an empty one renders the whole tab as zeroes, '
          'silently',
    );
  });
}
