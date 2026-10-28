import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/presentation/me_page.dart';
import 'package:results/features/results/presentation/shooting_selection_panel.dart';
import 'package:results/l10n/app_localizations.dart';

import 'support/season_shooting_fixtures.dart';

Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: buildAppTheme(AppThemeVariant.alpineLight),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key, String label) async {
  await tapKey(tester, key);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

const profile = AthleteProfile(
  athleteId: 'athlete',
  displayName: 'Athlete',
  normalizedName: 'athlete',
  primaryClubId: null,
  primaryTeamId: null,
  events: [],
);

void main() {
  testWidgets(
    'one series renders, bar reveals its exact source, keyboard opens table',
    (tester) async {
      final source = race(passes: [pass(1)]);
      AthleteRace? opened;
      await tester.pumpWidget(
        app(
          ShootingSelectionPanel(
            statisticsRaces: [source],
            entries: [
              ShootingSelectionEntry(
                id: '${source.key}/${source.resultId}',
                label: 'Friendly winter event · Senior',
                metrics: source.biathlonMetrics!,
              ),
            ],
            onRaceSelected: (race) => opened = race,
          ),
        ),
      );
      expect(
        find.byKey(const Key('season-distribution-low-data')),
        findsOneWidget,
      );
      expect(
        find.text('n = 1 measured series · each observation is one series'),
        findsOneWidget,
      );
      await tapKey(tester, 'season-distribution-bar-5');
      expect(
        find.text('Friendly winter event · Senior · Shooting 1 · prone · 5'),
        findsOneWidget,
      );
      await tapKey(
        tester,
        'season-distribution-contribution-${source.key}/${source.resultId}/1',
      );
      expect(opened, same(source));

      final toggle = find.byKey(const Key('season-distribution-table-toggle'));
      await tester.ensureVisible(toggle);
      final label = find.descendant(of: toggle, matching: find.byType(Text));
      Focus.of(tester.element(label)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('season-distribution-table')),
        findsOneWidget,
      );
      expect(find.text('100 %'), findsOneWidget);
      await tapKey(tester, 'season-distribution-bin-0');
      expect(find.text('No series in this interval.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'season, metric and pass controls update distribution and route with stage',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/me',
        routes: [
          GoRoute(
            path: '/me',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: AthleteSeasonResults(
                  profile: profile,
                  races: [
                    race(event: 'old', passes: [pass(1), pass(2)]),
                    race(
                      event: 'winter',
                      stage: 'stage-final',
                      passes: [
                        pass(1),
                        pass(2, misses: 1),
                        pass(3, position: 'standing', misses: 2, time: 30000),
                        pass(4, position: 'standing', misses: 3, time: 40000),
                      ],
                    ),
                    for (final status in ['DNF', 'DNS', 'DFQ', 'DSQ', 'DQ'])
                      race(
                        event: 'winter',
                        resultId: status,
                        status: status,
                        passes: [pass(1)],
                      ),
                  ],
                  events: [
                    ResultEvent(
                      id: 'old',
                      name: 'Spring race',
                      sportName: 'Biathlon',
                      date: DateTime(2025, 4, 30),
                      place: '',
                    ),
                    ResultEvent(
                      id: 'winter',
                      name: 'Winter final',
                      sportName: 'Biathlon',
                      date: DateTime(2025, 5, 1),
                      place: '',
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/events/:event/results/:class/athletes/:result',
            builder: (context, state) =>
                Scaffold(body: Text('Result ${state.uri}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: buildAppTheme(AppThemeVariant.alpineLight),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      expect(
        find.text('n = 6 measured series · each observation is one series'),
        findsOneWidget,
      );
      await choose(tester, 'shooting-pass-selector', '2nd standing');
      expect(
        find.text('n = 1 measured series · each observation is one series'),
        findsOneWidget,
      );
      expect(find.text('Mean: 2'), findsOneWidget);
      await tapKey(tester, 'season-2024');
      expect(
        find.byKey(const Key('season-distribution-empty')),
        findsOneWidget,
      );
      await tapKey(tester, 'season-2025');
      await choose(tester, 'shooting-metric-selector', 'Time on the range');
      expect(find.text('Mean: 40 s'), findsOneWidget);
      await tapKey(tester, 'season-distribution-bar-0');
      expect(
        find.textContaining('Winter final', findRichText: true),
        findsWidgets,
      );
      await tapKey(
        tester,
        'season-distribution-contribution-winter/class/stage-final/same-result-id/4',
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/events/winter/results/class/athletes/same-result-id',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['stageId'],
        'stage-final',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('known relay leg survives range-series result navigation', (
    tester,
  ) async {
    final relay = race(
      event: 'relay',
      stage: 'relay-final',
      relay: true,
      relayLeg: true,
      relayLegNumber: 2,
      passes: [pass(1)],
    );
    final router = GoRouter(
      initialLocation: '/me',
      routes: [
        GoRoute(
          path: '/me',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: AthleteSeasonResults(
                profile: profile,
                races: [relay],
                events: [
                  ResultEvent(
                    id: 'relay',
                    name: 'Relay final',
                    sportName: 'Biathlon',
                    date: DateTime(2025, 12, 1),
                    place: '',
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/events/:event/results/:class/athletes/:result',
          builder: (context, state) => Scaffold(body: Text('${state.uri}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildAppTheme(AppThemeVariant.alpineLight),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    expect(find.byKey(const Key('season-distribution-empty')), findsOneWidget);
    await choose(tester, 'shooting-metric-selector', 'Time on the range');
    await tapKey(tester, 'season-distribution-bar-0');
    await tapKey(
      tester,
      'season-distribution-contribution-${relay.key}/${relay.resultId}/1',
    );
    final query = router.routeInformationProvider.value.uri.queryParameters;
    expect(query['stageId'], 'relay-final');
    expect(query['relayLeg'], '2');
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'chart, contributions and table fit 250/320px in ${locale.languageCode}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final width in [250.0, 320.0]) {
          tester.view.physicalSize = Size(width, 900);
          final source = race(
            passes: [pass(1), pass(2, misses: 5, time: 30000)],
          );
          await tester.pumpWidget(
            app(
              ShootingSelectionPanel(
                key: ValueKey(width),
                statisticsRaces: [source],
                raceLabel: (_) =>
                    'Winter championship · A long event and class label',
                onRaceSelected: (_) {},
                entries: const [],
              ),
              locale: locale,
            ),
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(ShootingSelectionPanel)),
          );
          await tapKey(tester, 'season-distribution-bar-5');
          expect(
            find.byKey(const Key('season-distribution-contributions')),
            findsOneWidget,
          );
          await tapKey(tester, 'season-distribution-table-toggle');
          expect(
            find.byKey(const Key('season-distribution-table')),
            findsOneWidget,
          );
          await choose(
            tester,
            'shooting-metric-selector',
            l10n.biathlonRangeTime,
          );
          expect(
            find.byKey(const Key('season-distribution-contributions')),
            findsNothing,
          );
          await tapKey(tester, 'season-distribution-bin-0');
          expect(
            find.byKey(const Key('season-distribution-contributions')),
            findsOneWidget,
          );
          await tapKey(tester, 'season-distribution-table-toggle');
          expect(
            find.byKey(const Key('season-distribution-chart')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
