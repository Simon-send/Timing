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
      await tester.pumpAndSettle();

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

  test('result highlighting prioritizes self and matches club or team', () {
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
  });

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
  final watchedRequests = <({String classId, int limit})>[];

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
