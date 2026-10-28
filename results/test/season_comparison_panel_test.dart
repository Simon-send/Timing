import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/core/widgets/histogram_chart.dart';
import 'package:results/features/profile/domain/athlete_season.dart';
import 'package:results/features/profile/presentation/me_page.dart';
import 'package:results/features/profile/presentation/season_comparison_panel.dart';
import 'package:results/l10n/app_localizations.dart';

import 'season_shooting_comparison_test.dart'
    show comparisonEvents, comparisonRaces, event;
import 'season_shooting_distribution_panel_test.dart' show app, tapKey, profile;
import 'support/season_shooting_fixtures.dart';

Finder inside(String side, String key) => find.descendant(
  of: find.byKey(Key('comparison-$side')),
  matching: find.byKey(Key(key)),
);

Future<void> choose(WidgetTester tester, String key, String label) async {
  await tapKey(tester, key);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> tapInside(WidgetTester tester, String side, String key) async {
  final target = inside(side, key);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

List<HistogramBarsPainter> painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(SeasonComparisonPanel),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((widget) => widget.painter)
    .whereType<HistogramBarsPainter>()
    .toList();

void main() {
  testWidgets(
    'unequal series share percentage/count scales, swap distinct seasons and empty selections',
    (tester) async {
      await tester.pumpWidget(
        app(
          SeasonComparisonPanel(
            dataset: AthleteSeasonDataset(
              races: comparisonRaces(),
              events: comparisonEvents(),
            ),
          ),
        ),
      );
      expect(
        find.text('Hit rate difference (B − A): -5 percentage points'),
        findsOneWidget,
      );
      var charts = painters(tester);
      expect(charts, hasLength(2));
      expect(charts.map((chart) => chart.maximumValue), everyElement(100));
      expect(
        charts.map(
          (chart) => chart.buckets.fold<double>(
            0,
            (sum, bar) => sum + bar.heightValue,
          ),
        ),
        everyElement(100),
      );
      await tapKey(tester, 'comparison-count-toggle');
      charts = painters(tester);
      expect(charts.map((chart) => chart.maximumValue), everyElement(2));
      expect(charts[0].buckets.fold<int>(0, (sum, bar) => sum + bar.count), 2);
      expect(charts[1].buckets.fold<int>(0, (sum, bar) => sum + bar.count), 4);
      await choose(tester, 'comparison-season-left', '2025/26');
      expect(
        find.text('Hit rate difference (B − A): +5 percentage points'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('comparison-left')),
          matching: find.text('2025/26'),
        ),
        findsOneWidget,
      );
      await choose(tester, 'comparison-selection-selector', '2nd standing');
      expect(
        find.byKey(const Key('season-distribution-empty')),
        findsNWidgets(2),
      );
      expect(
        find.text('Hit rate difference (B − A): — percentage points'),
        findsOneWidget,
      );
      await choose(tester, 'comparison-selection-selector', 'All shootings');
      await choose(tester, 'comparison-metric-selector', 'Time on the range');
      expect(
        find.text('Mean range time difference (B − A): +7.25 s'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('comparison-intervals')), findsOneWidget);
      expect(
        find.byKey(const Key('season-distribution-intervals')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile comparison keeps full history and opens exact contribution with stage',
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
                  races: comparisonRaces(),
                  events: comparisonEvents(),
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
      await tapKey(tester, 'season-2025');
      await tapKey(tester, 'season-comparison-open');
      expect(
        find.text('Hit rate difference (B − A): -5 percentage points'),
        findsOneWidget,
      );
      await tapInside(tester, 'left', 'season-distribution-bar-4');
      expect(
        find.text(
          'Friendly old · 30.04.2025 · Senior · Shooting 1 · prone · 4',
        ),
        findsOneWidget,
      );
      await tapInside(
        tester,
        'left',
        'season-distribution-contribution-old/class/stage/same-result-id/1',
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/events/old/results/class/athletes/same-result-id',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['stageId'],
        'stage',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('known relay leg survives the comparison contribution callback', (
    tester,
  ) async {
    final races = [
      for (final id in ['old', 'new'])
        race(
          event: id,
          relay: true,
          relayLeg: true,
          relayLegNumber: 2,
          stage: 'relay-final',
          passes: [pass(1)],
        ),
    ];
    final router = GoRouter(
      initialLocation: '/me',
      routes: [
        GoRoute(
          path: '/me',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: AthleteSeasonResults(
                profile: profile,
                races: races,
                events: [
                  event('old', DateTime(2025, 4, 30), disciplines: ['Relay']),
                  event('new', DateTime(2025, 5, 1), disciplines: ['Relay']),
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
    await tapKey(tester, 'season-comparison-open');
    await choose(tester, 'comparison-metric-selector', 'Time on the range');
    await tapInside(tester, 'right', 'season-distribution-bar-0');
    await tapInside(
      tester,
      'right',
      'season-distribution-contribution-new/class/relay-final/same-result-id/1',
    );
    final query = router.routeInformationProvider.value.uri.queryParameters;
    expect(query['stageId'], 'relay-final');
    expect(query['relayLeg'], '2');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one season and unknown programs explain unavailable comparison',
    (tester) async {
      await tester.pumpWidget(
        app(
          SeasonComparisonPanel(
            dataset: AthleteSeasonDataset(
              races: [race(event: 'old')],
              events: comparisonEvents(),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('comparison-empty')), findsOneWidget);
      await tester.pumpWidget(
        app(
          SeasonComparisonPanel(
            dataset: AthleteSeasonDataset(
              races: comparisonRaces(),
              events: [
                event('old', DateTime(2025, 4, 30), disciplines: []),
                event('new', DateTime(2025, 5, 1), disciplines: []),
              ],
            ),
          ),
        ),
      );
      expect(
        find.textContaining('No unambiguous comparable program'),
        findsOneWidget,
      );
      expect(
        find.textContaining('3 with an unknown or ambiguous program'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'comparison stacks at 320 and shares a row at 1280 in ${locale.languageCode}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final width in [320.0, 1280.0]) {
          tester.view.physicalSize = Size(width, 1100);
          await tester.pumpWidget(
            app(
              SeasonComparisonPanel(
                key: ValueKey(width),
                dataset: AthleteSeasonDataset(
                  races: comparisonRaces(),
                  events: comparisonEvents(),
                ),
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          final left = tester.getTopLeft(
            find.byKey(const Key('comparison-left')),
          );
          final right = tester.getTopLeft(
            find.byKey(const Key('comparison-right')),
          );
          if (width == 320) {
            expect(right.dy, greaterThan(left.dy));
          } else {
            expect(right.dy, left.dy);
            expect(right.dx, greaterThan(left.dx));
          }
          await tapInside(tester, 'left', 'season-distribution-bar-4');
          expect(
            inside('left', 'season-distribution-contributions'),
            findsOneWidget,
            reason: 'width $width',
          );
          await tapInside(tester, 'left', 'season-distribution-table-toggle');
          expect(inside('left', 'season-distribution-table'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
