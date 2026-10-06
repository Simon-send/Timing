import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_bootstrap.dart';
import 'package:results/features/auth/data/auth_repository.dart';
import 'package:results/features/results/presentation/results_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('bootstrap never queries Firebase apps before SDK initialization', () {
    // Source guard: native mocks cannot reproduce the WebKit-specific error
    // in firebase_core_web's apps getter before its JavaScript SDK is loaded.
    final source = File('lib/app/app_bootstrap.dart').readAsStringSync();
    expect(source, isNot(contains('Firebase.apps.isEmpty')));
    expect(source, contains('await Firebase.initializeApp('));
  });
  testWidgets('bootstrap leaves deep route ownership to the real router', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue =
        '/events/event/results/class/athletes/runner?stageId=heat&relayLeg=2';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final navigation = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        navigation.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
    final completion = Completer<AppDependencies>();
    await tester.pumpWidget(AppBootstrap(initialize: () => completion.future));
    await tester.pump();
    expect(find.byType(Navigator), findsNothing);
    expect(navigation, isEmpty);
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Prøv igjen'), findsOneWidget);
    await tester.tap(find.text('Prøv igjen'));
    await tester.pump();
    expect(find.byType(Navigator), findsNothing);
    expect(navigation, isEmpty);
    completion.completeError(StateError('test complete'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late startup success recovers without a manual retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final completion = Completer<AppDependencies>();
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => completion.future,
        appBuilder: (_) => const MaterialApp(home: Text('Klar')),
      ),
    );
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Kunne ikke starte'), findsOneWidget);
    completion.complete(AppDependencies(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.text('Klar'), findsOneWidget);
  });
  testWidgets('retry after timeout reuses initialization still in progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final completion = Completer<AppDependencies>();
    var attempts = 0;
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () {
          attempts++;
          return completion.future;
        },
        appBuilder: (_) => const MaterialApp(home: Text('Klar')),
      ),
    );
    await tester.pump(const Duration(seconds: 21));
    await tester.tap(find.text('Prøv igjen'));
    await tester.pump();
    expect(attempts, 1);
    completion.complete(AppDependencies(preferences: preferences));
    await tester.pumpAndSettle();
    expect(find.text('Klar'), findsOneWidget);
  });
  testWidgets('bootstrap keeps a visible retry screen after a startup error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var attempts = 0;

    Future<AppDependencies> initialize() {
      attempts++;
      if (attempts == 1) return Future.error(StateError('offline'));
      return Future.value(AppDependencies(preferences: preferences));
    }

    await tester.pumpWidget(
      AppBootstrap(
        initialize: initialize,
        appBuilder: (_) =>
            const MaterialApp(home: Scaffold(body: Text('Klar'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kunne ikke starte'), findsOneWidget);
    expect(find.text('Prøv igjen'), findsOneWidget);

    await tester.tap(find.text('Prøv igjen'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Klar'), findsOneWidget);
  });

  test('Google uses redirect on phones and popup on larger web clients', () {
    expect(
      googleSignInMethodFor(TargetPlatform.android),
      GoogleSignInMethod.redirect,
    );
    expect(
      googleSignInMethodFor(TargetPlatform.iOS),
      GoogleSignInMethod.redirect,
    );
    expect(
      googleSignInMethodFor(TargetPlatform.macOS),
      GoogleSignInMethod.popup,
    );
  });

  testWidgets('mobile result tables do not create a floating header overlay', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final pageScrollController = ScrollController();
    addTearDown(pageScrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: pageScrollController,
            child: Column(
              children: [
                const SizedBox(height: 220),
                SizedBox(
                  height: 420,
                  child: ResultsLoadMoreViewport(
                    pageScrollController: pageScrollController,
                    itemCount: 20,
                    isLoadingMore: false,
                    stickyClassHeader: const Text('Klasse'),
                    stickyTableHeader: const SizedBox(width: 720, height: 36),
                    child: const SizedBox(width: 720, height: 360),
                  ),
                ),
                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pageScrollController.jumpTo(260);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sticky-results-header')), findsNothing);
  });
}
