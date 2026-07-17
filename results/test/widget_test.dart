import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_providers.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/auth/data/auth_repository.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/settings/data/settings_repository.dart';
import 'package:results/features/settings/domain/user_settings.dart';
import 'package:results/features/results/presentation/results_split_graph.dart';
import 'package:results/features/results/presentation/results_table.dart';
import 'package:results/features/results/presentation/relay_leg_selector.dart';
import 'package:results/features/athlete/presentation/relay_team_panel.dart';
import 'package:results/features/athlete/presentation/biathlon_result_panel.dart';
import 'package:results/features/results/presentation/split_selector.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:results/results_app.dart';
import 'package:results/results_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'load-more state fills the bottom fifth and blocks repeat loads',
    (WidgetTester tester) async {
      var isLoadingMore = true;
      var loadMoreCalls = 0;
      late StateSetter updateViewport;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: StatefulBuilder(
                builder: (context, setState) {
                  updateViewport = setState;
                  return ResultsLoadMoreViewport(
                    isLoadingMore: isLoadingMore,
                    itemCount: 1,
                    onLoadMore: () => loadMoreCalls++,
                    child: const SizedBox(width: 900, height: 80),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final indicator = find.byKey(
        const ValueKey('results-loading-more-indicator'),
      );
      expect(indicator, findsOneWidget);
      expect(tester.getSize(indicator).height, 100);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Laster flere resultater'), findsOneWidget);
      expect(loadMoreCalls, 0);

      updateViewport(() => isLoadingMore = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(indicator, findsNothing);
      expect(loadMoreCalls, 1);
    },
  );

  testWidgets('login has a separate forgot-password flow', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authRepository = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          eventsRepositoryProvider.overrideWithValue(_FakeEventsRepository()),
          authRepositoryProvider.overrideWithValue(authRepository),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
        ],
        child: const ResultsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Glemt passord?'), findsOneWidget);

    await tester.tap(find.text('Glemt passord?'));
    await tester.pumpAndSettle();
    expect(find.text('Send tilbakestillingslenke'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-post'),
      'test@example.com',
    );
    await tester.tap(find.text('Send tilbakestillingslenke'));
    await tester.pumpAndSettle();

    expect(authRepository.resetEmail, 'test@example.com');
    expect(find.textContaining('har vi sendt en lenke'), findsOneWidget);
  });

  test(
    'result highlighting prioritizes favorites and matches club or team',
    () {
      const ownResult = RaceResult(
        id: 'own-result',
        athleteId: 'athlete-1',
        rank: 1,
        bib: '1',
        name: 'Own Athlete',
        club: 'Alta Skiskytterlag',
        totalMs: 1000,
        totalText: '1.0',
        shooting: '',
        status: 'TIME',
        splitValues: {},
      );
      const teamMateResult = RaceResult(
        id: 'team-result',
        athleteId: 'athlete-3',
        rank: 3,
        bib: '3',
        name: 'Team Mate',
        club: 'Another Club',
        team: '  TEAM   ALTA ',
        totalMs: 1200,
        totalText: '1.2',
        shooting: '',
        status: 'TIME',
        splitValues: {},
      );
      const clubMateResult = RaceResult(
        id: 'club-result',
        athleteId: 'athlete-2',
        rank: 2,
        bib: '2',
        name: 'Club Mate',
        club: '  ALTA   SKISKYTTERLAG ',
        totalMs: 1100,
        totalText: '1.1',
        shooting: '',
        status: 'TIME',
        splitValues: {},
      );

      expect(
        resultHighlightFor(
          ownResult,
          linkedAthleteId: 'athlete-1',
          linkedClubName: 'Alta Skiskytterlag',
          linkedTeamName: 'Team Alta',
        ),
        ResultRowHighlight.self,
      );
      expect(
        resultHighlightFor(
          clubMateResult,
          linkedAthleteId: 'athlete-1',
          linkedClubName: 'Alta Skiskytterlag',
          linkedTeamName: 'Team Alta',
        ),
        ResultRowHighlight.affiliationMate,
      );
      expect(
        resultHighlightFor(
          teamMateResult,
          linkedAthleteId: 'athlete-1',
          linkedClubName: 'Alta Skiskytterlag',
          linkedTeamName: 'Team Alta',
        ),
        ResultRowHighlight.affiliationMate,
      );
      expect(
        resultHighlightFor(
          clubMateResult,
          linkedAthleteId: 'athlete-1',
          linkedClubName: 'Alta Skiskytterlag',
          linkedTeamName: 'Team Alta',
          favoriteAthleteIds: const {'athlete-2'},
        ),
        ResultRowHighlight.favorite,
      );
      expect(
        resultHighlightFor(
          ownResult,
          linkedAthleteId: 'athlete-1',
          linkedClubName: 'Alta Skiskytterlag',
          linkedTeamName: 'Team Alta',
          favoriteAthleteIds: const {'athlete-1'},
        ),
        ResultRowHighlight.favorite,
      );
    },
  );

  test('RaceResult keeps club and team names separate', () {
    final result = RaceResult.fromMap('result-1', {
      'name': 'Elle Simensen',
      'clubName': 'Alta Skiskytterlag',
      'teamName': 'Team Alta',
    });

    expect(result.club, 'Alta Skiskytterlag');
    expect(result.team, 'Team Alta');
  });

  testWidgets('result placement keeps finish rank inside parentheses', (
    WidgetTester tester,
  ) async {
    final result = RaceResult.fromMap('result-1', {
      'name': 'Elle Simensen',
      'bib': '12',
      'finishRank': 2,
      'totalMs': 2000,
      'totalText': '2.0',
      'status': 'TIME',
      'splitValues': {
        'split-1': {
          'cumRank': 7,
          'cumMs': 1000,
          'cumText': '1.0',
          'legMs': 1000,
          'legText': '1.0',
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nb'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ResultsTable(
            rows: [
              ResultTableRow(
                result: result,
                classId: 'class-1',
                className: 'Testklasse',
                color: null,
                originalPlacementLabel: '2',
              ),
            ],
            selectedSplitId: 'split-1',
            splitRange: null,
            sortMode: ResultSortMode.cumulative,
            onSortModeChanged: (_) {},
            tableDensity: TableDensity.comfortable,
            affiliationView: ResultAffiliationView.club,
            onAffiliationViewToggle: () {},
            onAthleteTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('1(2)'), findsOneWidget);
    expect(find.text('1(7)'), findsNothing);
    expect(find.text('SKYTING'), findsNothing);
  });

  testWidgets('qualified result shows an advancement badge', (tester) async {
    final result = RaceResult.fromMap('qualified', {
      'name': 'Oslo lag 1',
      'bib': '12',
      'totalMs': 2000,
      'totalText': '2.0',
      'status': 'TIME',
      'advanced': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nb'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ResultsTable(
            rows: [
              ResultTableRow(
                result: result,
                classId: 'class-1',
                className: 'Testklasse',
                color: null,
                originalPlacementLabel: '1',
              ),
            ],
            selectedSplitId: null,
            splitRange: null,
            sortMode: ResultSortMode.cumulative,
            onSortModeChanged: (_) {},
            tableDensity: TableDensity.comfortable,
            affiliationView: ResultAffiliationView.club,
            onAffiliationViewToggle: () {},
            onAthleteTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('advancement-badge')), findsOneWidget);
    expect(find.text('Q'), findsOneWidget);
  });

  testWidgets(
    'independent split picker returns checked splits in split order',
    (WidgetTester tester) async {
      const splitOptions = [
        SplitOption(id: 'first', label: 'Første', sort: 1, kind: 'split'),
        SplitOption(id: 'middle', label: 'Midten', sort: 2, kind: 'split'),
        SplitOption(id: 'last', label: 'Siste', sort: 3, kind: 'finish'),
      ];
      var selection = const SplitRangeSelection(
        fromSplitId: 'first',
        toSplitId: 'middle',
        includedSplitIds: ['middle'],
      );
      List<String>? submittedIds;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('nb'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: 600,
                  child: SplitSelector(
                    splitOptions: splitOptions,
                    selectedSplitId: selection.toSplitId,
                    onChanged: (_) {},
                    rangeSelection: selection,
                    canUseRange: true,
                    onRangeToggle: () {},
                    onRangeFromChanged: (_) {},
                    onRangeToChanged: (_) {},
                    onIndependentChanged: (value) {
                      setState(() {
                        selection = selection.copyWith(isIndependent: value);
                      });
                    },
                    onIncludedSplitsChanged: (ids) {
                      submittedIds = ids;
                      setState(() {
                        selection = selection.copyWith(includedSplitIds: ids);
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('independent-splits-checkbox')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('independent-splits-picker')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('independent-splits-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('independent-split-middle')));
      await tester.tap(find.byKey(const Key('independent-split-last')));
      await tester.tap(find.byKey(const Key('independent-split-first')));
      await tester.tap(find.text('Bruk'));
      await tester.pumpAndSettle();

      expect(submittedIds, ['first', 'last']);
      expect(find.text('Første, Siste'), findsOneWidget);
    },
  );

  testWidgets('independent splits sum legs, hide time, and sort by split', (
    WidgetTester tester,
  ) async {
    RaceResult result(
      String id,
      String name, {
      required int firstMs,
      required int middleMs,
      required int lastMs,
    }) {
      return RaceResult.fromMap(id, {
        'name': name,
        'bib': id,
        'club': 'Klubb',
        'totalMs': firstMs + middleMs + lastMs,
        'totalText': 'sluttid',
        'status': 'TIME',
        'splitValues': {
          'first': {'cumMs': firstMs, 'legMs': firstMs, 'addition': '0'},
          'middle': {
            'cumMs': firstMs + middleMs,
            'legMs': middleMs,
            'addition': '0',
          },
          'last': {
            'cumMs': firstMs + middleMs + lastMs,
            'legMs': lastMs,
            'addition': '0',
          },
        },
      });
    }

    final rows = [
      ResultTableRow(
        result: result('1', 'Alfa', firstMs: 2000, middleMs: 500, lastMs: 3000),
        classId: 'class-1',
        className: 'Testklasse',
        color: null,
        originalPlacementLabel: '1',
      ),
      ResultTableRow(
        result: result(
          '2',
          'Beta',
          firstMs: 1000,
          middleMs: 4000,
          lastMs: 2000,
        ),
        classId: 'class-1',
        className: 'Testklasse',
        color: null,
        originalPlacementLabel: '2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nb'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ResultsTable(
            rows: rows,
            selectedSplitId: 'last',
            splitRange: const SplitRangeSelection(
              fromSplitId: null,
              toSplitId: 'last',
              includedSplitIds: ['first', 'last'],
              isIndependent: true,
            ),
            sortMode: ResultSortMode.cumulative,
            onSortModeChanged: (_) {},
            tableDensity: TableDensity.comfortable,
            affiliationView: ResultAffiliationView.club,
            onAffiliationViewToggle: () {},
            onAthleteTap: (_) {},
          ),
        ),
      ),
    );

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.sortColumnIndex, 4);
    expect(table.columns[5].onSort, isNull);
    expect(find.text('0:03.0'), findsOneWidget);
    expect(find.text('0:05.0'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Beta')).dy,
      lessThan(tester.getTopLeft(find.text('Alfa')).dy),
    );
  });

  testWidgets('search does not recalculate result placement', (
    WidgetTester tester,
  ) async {
    RaceResult result(String id, String name, int timeMs) {
      return RaceResult.fromMap(id, {
        'name': name,
        'totalMs': timeMs + 1000,
        'totalText': '${timeMs + 1000}',
        'status': 'TIME',
        'splitValues': {
          'split-1': {
            'cumMs': timeMs,
            'cumText': '$timeMs',
            'legMs': timeMs,
            'legText': '$timeMs',
          },
        },
      });
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nb'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ResultsTable(
            rows: [
              ResultTableRow(
                result: result('first', 'Første utøver', 1000),
                classId: 'class-1',
                className: 'Testklasse',
                color: null,
                originalPlacementLabel: '4',
              ),
              ResultTableRow(
                result: result('target', 'Søkt utøver', 2000),
                classId: 'class-1',
                className: 'Testklasse',
                color: null,
                originalPlacementLabel: '9',
              ),
            ],
            selectedSplitId: 'split-1',
            splitRange: null,
            sortMode: ResultSortMode.cumulative,
            onSortModeChanged: (_) {},
            tableDensity: TableDensity.comfortable,
            affiliationView: ResultAffiliationView.club,
            onAffiliationViewToggle: () {},
            searchQuery: 'søkt',
            onAthleteTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Første utøver'), findsNothing);
    expect(find.text('Søkt utøver'), findsOneWidget);
    expect(find.text('2(9)'), findsOneWidget);
    expect(find.text('1(9)'), findsNothing);
  });

  testWidgets('load more shows a footer until new results arrive', (
    WidgetTester tester,
  ) async {
    var itemCount = 20;
    var contentHeight = 600.0;
    var isLoadingMore = false;
    var loadCalls = 0;
    late StateSetter updateHost;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return ResultsLoadMoreScrollView(
                  itemCount: itemCount,
                  isLoadingMore: isLoadingMore,
                  onLoadMore: () {
                    loadCalls++;
                    updateHost(() => isLoadingMore = true);
                  },
                  child: SizedBox(width: 400, height: contentHeight),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Laster flere resultater'), findsNothing);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pump();

    expect(loadCalls, 1);
    expect(find.text('Laster flere resultater'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    updateHost(() {
      itemCount = 40;
      contentHeight = 1000;
      isLoadingMore = false;
    });
    await tester.pump();

    expect(find.text('Laster flere resultater'), findsNothing);
    expect(loadCalls, 1);
  });

  testWidgets('split graph calculates missing ranks from split times', (
    WidgetTester tester,
  ) async {
    RaceResult result(String id, String name, int timeMs) {
      return RaceResult.fromMap(id, {
        'name': name,
        'totalMs': timeMs,
        'status': 'TIME',
        'rawPasses': [
          {'setupUid': 'split-1', 'code': 'MT1', 'cumMs': timeMs},
        ],
      });
    }

    final rows = [
      ResultTableRow(
        result: result('first', 'Første utøver', 1000),
        classId: 'class-1',
        className: 'Testklasse',
        color: null,
        originalPlacementLabel: '1',
      ),
      ResultTableRow(
        result: result('second', 'Andre utøver', 1200),
        classId: 'class-1',
        className: 'Testklasse',
        color: null,
        originalPlacementLabel: '2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 420,
            child: ResultsSplitGraph(
              rows: rows,
              splitOptions: const [
                SplitOption(
                  id: 'split-1',
                  label: 'MT1',
                  sort: 1,
                  kind: 'split',
                ),
              ],
              selectedSplitId: 'split-1',
              splitRange: null,
              onAthleteTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ingen splitgrafdata'), findsNothing);
    expect(find.text('Første utøver'), findsOneWidget);
    expect(find.text('Andre utøver'), findsOneWidget);
  });

  testWidgets('sprint stages reuse the ordinary result table', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _FakeResultsRepository(
      stages: const [
        CompetitionStage(
          id: 'prolog',
          name: 'Prolog',
          type: 'interval',
          level: 1,
          order: 0,
          classIds: ['other-class', '1292218'],
          profile: ResultProfile.sprint,
          profileSource: ResultProfileSource.eq,
        ),
        CompetitionStage(
          id: 'final',
          name: 'Finale',
          type: 'heats',
          level: 7,
          order: 1,
          classIds: ['other-class', '1292218'],
          profile: ResultProfile.sprint,
          profileSource: ResultProfileSource.eq,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          eventsRepositoryProvider.overrideWithValue(_FakeEventsRepository()),
          resultsRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
        ],
        child: const ResultsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AKSA Cup 7'));
    await tester.pumpAndSettle();

    expect(find.text('Konkurranseledd'), findsOneWidget);
    expect(find.text('Prolog'), findsWidgets);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Elle Simensen'), findsOneWidget);

    await tester.tap(find.text('Elle Simensen'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('athlete-stage-results-panel')),
      findsOneWidget,
    );
    expect(find.text('Alle tider'), findsOneWidget);
    expect(find.text('Finale'), findsOneWidget);
    expect(
      find.byKey(const Key('show-athlete-stage-result-lists')),
      findsOneWidget,
    );
  });

  testWidgets('relay details add runners and leg times', (tester) async {
    final result = RaceResult.fromMap('team', {
      'entrant': {'kind': 'team', 'name': 'Oslo lag 1'},
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'Ada'},
          {'legNumber': 2, 'name': 'Grace'},
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'exchange',
          'code': '1. Veksling',
          'sort': 1,
          'legNumber': 1,
          'cumMs': 60000,
        },
        {
          'setupUid': 'finish',
          'code': 'Mål',
          'sort': 2,
          'legNumber': 2,
          'cumMs': 130000,
        },
      ],
    });
    final fasterResult = RaceResult.fromMap('faster-team', {
      'entrant': {'kind': 'team', 'name': 'Bergen lag 1'},
      'team': {
        'members': [
          {'legNumber': 1, 'name': 'Lin'},
          {'legNumber': 2, 'name': 'Mia'},
        ],
      },
      'timingPoints': [
        {
          'setupUid': 'exchange',
          'code': '1. Veksling',
          'sort': 1,
          'legNumber': 1,
          'cumMs': 55000,
        },
        {
          'setupUid': 'finish',
          'code': 'Mål',
          'sort': 2,
          'legNumber': 2,
          'cumMs': 125000,
        },
      ],
    });
    String? selectedSplitId;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RelayTeamPanel(
              result: result,
              classResults: [result, fasterResult],
              onSplitSelected: (splitId) => selectedSplitId = splitId,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Lagoppstilling og etappetider'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('1:00.0'), findsNWidgets(2));
    expect(find.text('1:10.0'), findsOneWidget);
    expect(find.text('Totalt'), findsNWidgets(2));
    expect(find.text('Etappe'), findsNWidgets(2));
    expect(find.text('Rank 2'), findsNWidgets(3));
    expect(find.text('Rank 1'), findsOneWidget);

    await tester.tap(find.text('Ada'));
    expect(selectedSplitId, 'exchange');
  });

  testWidgets('biathlon details show metrics and every shooting pass', (
    tester,
  ) async {
    const analysis = BiathlonAnalysis(
      skiTimeMs: 58000,
      netSkiTimeMs: 59000,
      shootingTimeMs: 11000,
      penaltyTimeMs: 1000,
      missesTotal: 1,
      skiRank: null,
      netSkiRank: null,
      shootingRank: null,
      penaltyRank: null,
      passes: [
        ShootingPass(
          index: 3,
          rangeMs: 5000,
          misses: 1,
          penaltyMs: 1000,
          position: 'prone',
        ),
        ShootingPass(
          index: 4,
          rangeMs: 6000,
          misses: 0,
          penaltyMs: 0,
          position: 'standing',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: BiathlonResultPanel(analysis: analysis),
          ),
        ),
      ),
    );

    expect(find.text('Skiskytinganalyse'), findsOneWidget);
    expect(find.text('Skyting 3 · liggende'), findsOneWidget);
    expect(find.text('Skyting 4 · stående'), findsOneWidget);
    expect(find.textContaining('1 bom'), findsOneWidget);
  });

  testWidgets('relay leg row selects a primary leg and extra comparisons', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(340, 500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    int? primaryLeg = 99;
    final comparisonChanges = <(int, bool)>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: Scaffold(
          body: RelayLegSelector(
            legNumbers: const [1, 2, 3],
            activeLegNumber: 1,
            comparisonLegNumbers: const [3],
            onPrimaryChanged: (value) => primaryLeg = value,
            onComparisonChanged: (leg, selected) {
              comparisonChanges.add((leg, selected));
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('relay-leg-selector')), findsOneWidget);
    expect(find.text('Lagresultat'), findsOneWidget);
    expect(find.text('Etappe 1'), findsOneWidget);
    expect(find.text('Etappe 2'), findsOneWidget);

    await tester.tap(find.text('Etappe 1'));
    expect(primaryLeg, 1);

    final secondLegCheckbox = find.descendant(
      of: find.byKey(const Key('relay-leg-2')),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(secondLegCheckbox);
    await tester.tap(secondLegCheckbox);
    expect(comparisonChanges, [(2, true)]);
  });

  testWidgets('biathlon relay keeps analysis inside the selected leg', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          eventsRepositoryProvider.overrideWithValue(_FakeEventsRepository()),
          resultsRepositoryProvider.overrideWithValue(
            _FakeRelayResultsRepository(),
          ),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
        ],
        child: const ResultsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AKSA Cup 7'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('relay-leg-selector')), findsOneWidget);
    await tester.tap(find.text('Etappe 2'));
    await tester.pumpAndSettle();

    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
    expect(find.text('1(1)'), findsOneWidget);
    final firstLegCheckbox = find.descendant(
      of: find.byKey(const Key('relay-leg-1')),
      matching: find.byType(Checkbox),
    );
    await tester.tap(firstLegCheckbox);
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    final splitPicker = find.byType(DropdownButtonFormField<String>);
    expect(splitPicker, findsOneWidget);
    await tester.tap(splitPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skiskytinganalyse').last);
    await tester.pumpAndSettle();
    expect(find.text('SKITID'), findsOneWidget);
    expect(find.text('SKYTETID'), findsOneWidget);
    expect(find.text('BOM'), findsOneWidget);
    await tester.ensureVisible(find.text('Grace Hopper'));
    await tester.tap(find.text('Grace Hopper'));
    await tester.pumpAndSettle();

    expect(find.text('Athlete details'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsWidgets);
    expect(find.text('Etappe 2'), findsWidgets);
    expect(find.textContaining('inkludert splitter'), findsOneWidget);
    expect(find.text('Skiskytinganalyse'), findsOneWidget);
    expect(find.text('Etappe 2 mellomtid'), findsWidgets);
    expect(find.text('Etappe 1 mellomtid'), findsNothing);
  });

  testWidgets('routes from event to result list and athlete details', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final resultsRepository = _FakeResultsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          eventsRepositoryProvider.overrideWithValue(_FakeEventsRepository()),
          resultsRepositoryProvider.overrideWithValue(resultsRepository),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          linkedAthleteIdProvider.overrideWith(
            (ref) => Stream.value('athlete-1'),
          ),
          athleteProfileProvider.overrideWith(
            (ref, athleteId) => Stream.value(
              const AthleteProfile(
                athleteId: 'athlete-1',
                displayName: 'Elle Simensen',
                normalizedName: 'elle simensen',
                primaryClubId: null,
                primaryTeamId: null,
                events: [
                  AthleteEvent(
                    eventId: '83078',
                    name: 'AKSA Cup 7',
                    classId: '1292218',
                    className: 'J11-12, 5 x 400 m',
                    rank: 37,
                    finishRank: 37,
                  ),
                ],
              ),
            ),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
        ],
        child: const ResultsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AKSA Cup 7'), findsOneWidget);

    await tester.tap(find.text('AKSA Cup 7'));
    await tester.pumpAndSettle();

    expect(
      resultsRepository.watchedRequests,
      contains((classId: '1292218', limit: 37)),
    );
    expect(find.text('Sprint / Fellesstart'), findsOneWidget);
    expect(find.text('J11-12, 5 x 400 m'), findsWidgets);
    expect(find.text('CLUB/TEAM'), findsOneWidget);
    expect(find.text('Elle Simensen'), findsOneWidget);
    expect(find.text('Alta Skiskytterlag'), findsOneWidget);
    expect(find.text('Team Alta'), findsNothing);
    expect(find.text('Maal'), findsOneWidget);
    expect(tester.widget<DataTable>(find.byType(DataTable)).sortColumnIndex, 5);

    final resultSearch = find.byKey(const Key('result-search-field'));
    expect(resultSearch, findsOneWidget);
    await tester.enterText(resultSearch, 'ingen treff');
    await tester.pumpAndSettle();
    expect(find.text('Elle Simensen'), findsNothing);
    await tester.enterText(resultSearch, 'team alta');
    await tester.pumpAndSettle();
    expect(find.text('Elle Simensen'), findsOneWidget);
    await tester.enterText(resultSearch, '');
    await tester.pumpAndSettle();

    final selectors = find.byType(DropdownButtonFormField<String>);
    expect(selectors, findsNWidgets(2));
    await tester.tap(selectors.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mellomtid').last);
    await tester.pumpAndSettle();
    tester.widget<DataTable>(find.byType(DataTable)).columns[4].onSort!(
      4,
      true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('G10, 3 x 400 m (1)').last);
    await tester.pumpAndSettle();

    expect(find.text('Mellomtid'), findsOneWidget);
    expect(tester.widget<DataTable>(find.byType(DataTable)).sortColumnIndex, 4);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('J11-12, 5 x 400 m (1)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next split'));
    await tester.pumpAndSettle();
    tester.widget<DataTable>(find.byType(DataTable)).columns[5].onSort!(
      5,
      true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CLUB/TEAM'));
    await tester.pumpAndSettle();

    expect(find.text('TEAM/CLUB'), findsOneWidget);
    expect(find.text('Team Alta'), findsOneWidget);
    expect(find.text('2:04.1'), findsWidgets);

    await tester.ensureVisible(find.text('Elle Simensen'));
    await tester.tap(find.text('Elle Simensen'));
    await tester.pumpAndSettle();

    expect(find.text('Athlete details'), findsOneWidget);
    expect(find.text('Split breakdown'), findsOneWidget);
    expect(find.text('Head to head'), findsNothing);
  });
}

class _FakeEventsRepository implements EventsRepository {
  @override
  Stream<List<ResultEvent>> watchEvents() {
    return Stream.value([
      ResultEvent(
        id: '83078',
        name: 'AKSA Cup 7',
        sportName: 'Skiskyting',
        date: DateTime(2026, 5, 26),
        place: 'Alta',
      ),
    ]);
  }
}

class _FakeResultsRepository implements ResultsRepository {
  _FakeResultsRepository({List<CompetitionStage>? stages})
    : stages = stages ?? _defaultStages;

  final List<CompetitionStage> stages;
  final watchedRequests = <({String classId, int limit})>[];

  static const _defaultStages = [
    CompetitionStage(
      id: '337936',
      name: 'Sprint jenter',
      type: 'mass',
      level: 1,
      order: 0,
      classIds: ['other-class', '1292218'],
      profile: ResultProfile.standard,
      profileSource: ResultProfileSource.eq,
    ),
  ];

  @override
  Stream<List<ResultClass>> watchClasses(String eventId) {
    return Stream.value(const [
      ResultClass(
        id: 'other-class',
        name: 'G10, 3 x 400 m',
        resultCount: 1,
        participantCount: 50,
        etappeUid: 337935,
        etappeName: 'Fellesstart gutter',
      ),
      ResultClass(
        id: '1292218',
        name: 'J11-12, 5 x 400 m',
        resultCount: 1,
        participantCount: 1,
        etappeUid: 337936,
        etappeName: 'Sprint jenter',
      ),
    ]);
  }

  @override
  Stream<List<CompetitionStage>> watchStages(String eventId) {
    return Stream.value(stages);
  }

  @override
  Stream<List<SplitDef>> watchStageSplitDefs(
    String eventId,
    String stageId,
    String classId,
  ) => watchSplitDefs(eventId, classId);

  @override
  Stream<List<RaceResult>> watchStageResults(
    String eventId,
    String stageId,
    String classId, {
    int limit = initialResultsLimit,
  }) => watchResults(eventId, classId, limit: limit);

  @override
  Future<List<RaceResult>> fetchStageResults(
    String eventId,
    String stageId,
    String classId,
  ) => fetchResults(eventId, classId);

  @override
  Stream<RaceResult?> watchStageResult(
    String eventId,
    String stageId,
    String classId,
    String resultId,
  ) => watchResult(eventId, classId, resultId);

  @override
  Stream<List<SplitDef>> watchSplitDefs(String eventId, String classId) {
    return Stream.value(const [
      SplitDef(
        id: 'mid',
        label: 'Mellomtid',
        sort: 10,
        kind: 'split',
        stationName: 'Mellomtid',
        isPublic: true,
      ),
      SplitDef(
        id: 'finish',
        label: 'Maal',
        sort: 50,
        kind: 'finish',
        stationName: 'Maal',
        isPublic: true,
      ),
    ]);
  }

  @override
  Stream<List<RaceResult>> watchResults(
    String eventId,
    String classId, {
    int limit = initialResultsLimit,
  }) {
    watchedRequests.add((classId: classId, limit: limit));
    return Stream.value([_result]);
  }

  @override
  Future<List<RaceResult>> fetchResults(String eventId, String classId) async {
    return [_result];
  }

  @override
  Stream<RaceResult?> watchResult(
    String eventId,
    String classId,
    String resultId,
  ) {
    return Stream.value(_result);
  }

  static const _result = RaceResult(
    id: '14503260',
    athleteId: 'athlete-1',
    rank: 1,
    bib: '15',
    name: 'Elle Simensen',
    club: 'Alta Skiskytterlag',
    team: 'Team Alta',
    totalMs: 124100,
    totalText: '2:04.1',
    shooting: '0+0',
    status: 'TIME',
    splitValues: {
      'mid': SplitValue(
        id: 'mid',
        label: 'Mellomtid',
        sort: 10,
        cumRank: 1,
        legRank: 1,
        cumMs: 60000,
        legMs: 60000,
        cumText: '1:00.0',
        legText: '1:00.0',
        status: 'TIME',
        addition: '0',
        additionParts: [0],
      ),
      'finish': SplitValue(
        id: 'finish',
        label: 'Maal',
        sort: 50,
        cumRank: null,
        legRank: null,
        cumMs: 124100,
        legMs: 124100,
        cumText: '2:04.1',
        legText: '2:04.1',
        status: 'TIME',
        addition: '0+0',
        additionParts: [0, 0],
      ),
    },
  );
}

class _FakeRelayResultsRepository extends _FakeResultsRepository {
  _FakeRelayResultsRepository()
    : super(
        stages: const [
          CompetitionStage(
            id: '337936',
            name: 'Skiskytterstafett',
            type: 'interval-relay',
            level: 1,
            order: 0,
            classIds: ['other-class', '1292218'],
            profile: ResultProfile.biathlon,
            profileSource: ResultProfileSource.eq,
            hasRelayCapability: true,
            hasBiathlonCapability: true,
          ),
        ],
      );

  @override
  Stream<List<SplitDef>> watchSplitDefs(String eventId, String classId) {
    return Stream.value(const [
      SplitDef(
        id: 'leg-1-mid',
        label: 'Etappe 1 mellomtid',
        sort: 10,
        kind: 'split',
        stationName: 'Kort løype',
        isPublic: true,
        legNumber: 1,
      ),
      SplitDef(
        id: 'leg-1-finish',
        label: 'Veksling',
        sort: 20,
        kind: 'split',
        stationName: 'Veksling',
        isPublic: true,
        legNumber: 1,
      ),
      SplitDef(
        id: 'leg-2-mid',
        label: 'Etappe 2 mellomtid',
        sort: 30,
        kind: 'split',
        stationName: 'Lang løype',
        isPublic: true,
        legNumber: 2,
      ),
      SplitDef(
        id: 'leg-2-finish',
        label: 'Mål',
        sort: 40,
        kind: 'finish',
        stationName: 'Mål',
        isPublic: true,
        legNumber: 2,
      ),
    ]);
  }

  @override
  Stream<List<RaceResult>> watchResults(
    String eventId,
    String classId, {
    int limit = initialResultsLimit,
  }) {
    return Stream.value(const [_relayResult]);
  }

  @override
  Future<List<RaceResult>> fetchResults(String eventId, String classId) async {
    return const [_relayResult];
  }

  @override
  Stream<RaceResult?> watchResult(
    String eventId,
    String classId,
    String resultId,
  ) {
    return Stream.value(_relayResult);
  }

  static const _relayResult = RaceResult(
    id: 'relay-team-1',
    rank: 1,
    bib: '7',
    name: 'Oslo lag 1',
    club: 'Oslo Skiklubb',
    totalMs: 130000,
    totalText: '2:10.0',
    shooting: '',
    status: 'TIME',
    entrant: ResultEntrant(
      kind: ResultEntrantKind.team,
      name: 'Oslo lag 1',
      bib: '7',
      clubName: 'Oslo Skiklubb',
    ),
    relayMembers: [
      RelayMember(legNumber: 1, name: 'Ada Lovelace', athleteId: 'athlete:1'),
      RelayMember(legNumber: 2, name: 'Grace Hopper', athleteId: 'athlete:2'),
    ],
    biathlon: BiathlonAnalysis(
      skiTimeMs: 115000,
      netSkiTimeMs: 116000,
      shootingTimeMs: 11000,
      penaltyTimeMs: 1000,
      missesTotal: 1,
      skiRank: 1,
      netSkiRank: 1,
      shootingRank: 1,
      penaltyRank: 1,
      passes: [
        ShootingPass(
          index: 3,
          rangeMs: 5000,
          misses: 1,
          penaltyMs: 1000,
          position: 'prone',
        ),
        ShootingPass(
          index: 4,
          rangeMs: 6000,
          misses: 0,
          penaltyMs: 0,
          position: 'standing',
        ),
      ],
    ),
    splitValues: {
      'leg-1-mid': SplitValue(
        id: 'leg-1-mid',
        label: 'Etappe 1 mellomtid',
        sort: 10,
        cumRank: 1,
        legRank: 1,
        cumMs: 30000,
        legMs: 30000,
        cumText: '0:30.0',
        legText: '0:30.0',
        status: 'TIME',
        addition: '',
        additionParts: [],
        legNumber: 1,
      ),
      'leg-1-finish': SplitValue(
        id: 'leg-1-finish',
        label: 'Veksling',
        sort: 20,
        cumRank: 1,
        legRank: 1,
        cumMs: 60000,
        legMs: 30000,
        cumText: '1:00.0',
        legText: '0:30.0',
        status: 'TIME',
        addition: '',
        additionParts: [],
        legNumber: 1,
      ),
      'leg-2-mid': SplitValue(
        id: 'leg-2-mid',
        label: 'Etappe 2 mellomtid',
        sort: 30,
        cumRank: 1,
        legRank: 1,
        cumMs: 90000,
        legMs: 30000,
        cumText: '1:30.0',
        legText: '0:30.0',
        status: 'TIME',
        addition: '',
        additionParts: [],
        legNumber: 2,
      ),
      'leg-2-shoot-3': SplitValue(
        id: 'leg-2-shoot-3',
        label: 'S3',
        sort: 32,
        cumRank: 1,
        legRank: 1,
        cumMs: 100000,
        legMs: 10000,
        cumText: '1:40.0',
        legText: '0:10.0',
        status: 'TIME',
        addition: '0+0+1',
        additionParts: [0, 0, 1],
        kind: 'shooting',
        legNumber: 2,
      ),
      'leg-2-shoot-4': SplitValue(
        id: 'leg-2-shoot-4',
        label: 'S4',
        sort: 35,
        cumRank: 1,
        legRank: 1,
        cumMs: 115000,
        legMs: 15000,
        cumText: '1:55.0',
        legText: '0:15.0',
        status: 'TIME',
        addition: '0+0+1+0',
        additionParts: [0, 0, 1, 0],
        kind: 'shooting',
        legNumber: 2,
      ),
      'leg-2-finish': SplitValue(
        id: 'leg-2-finish',
        label: 'Mål',
        sort: 40,
        cumRank: 1,
        legRank: 1,
        cumMs: 130000,
        legMs: 40000,
        cumText: '2:10.0',
        legText: '0:40.0',
        status: 'TIME',
        addition: '',
        additionParts: [],
        legNumber: 2,
      ),
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  String? resetEmail;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => Stream.value(null);

  @override
  Future<void> createUserWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetEmail = email;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeSettingsRepository implements SettingsRepository {
  var settings = UserSettings.defaults().copyWith(
    localeCode: 'en',
    preferredSplitId: 'mid',
  );

  @override
  Future<UserSettings> load() async => settings;

  @override
  Future<void> save(UserSettings settings) async {
    this.settings = settings;
  }
}
