import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_providers.dart';
import 'package:results/features/auth/data/auth_repository.dart';
import 'package:results/features/settings/data/settings_repository.dart';
import 'package:results/features/settings/domain/user_settings.dart';
import 'package:results/results_app.dart';
import 'package:results/results_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('RaceResult prefers team name over club name', () {
    final result = RaceResult.fromMap('result-1', {
      'name': 'Elle Simensen',
      'clubName': 'Alta Skiskytterlag',
      'teamName': 'Team Alta',
    });

    expect(result.club, 'Team Alta');
  });

  testWidgets('routes from event to result list and athlete details', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          eventsRepositoryProvider.overrideWithValue(_FakeEventsRepository()),
          resultsRepositoryProvider.overrideWithValue(_FakeResultsRepository()),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
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

    expect(find.text('J11-12, 5 x 400 m'), findsWidgets);
    expect(find.text('TEAM'), findsOneWidget);
    expect(find.text('Elle Simensen'), findsOneWidget);
    expect(find.text('Team Alta'), findsOneWidget);
    expect(find.text('2:04.1'), findsWidgets);

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
  @override
  Stream<List<ResultClass>> watchClasses(String eventId) {
    return Stream.value(const [
      ResultClass(
        id: '1292218',
        name: 'J11-12, 5 x 400 m',
        resultCount: 1,
        participantCount: 1,
        etappeUid: 337936,
      ),
    ]);
  }

  @override
  Stream<List<SplitDef>> watchSplitDefs(String eventId, String classId) {
    return Stream.value(const [
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
    rank: 1,
    bib: '15',
    name: 'Elle Simensen',
    club: 'Team Alta',
    totalMs: 124100,
    totalText: '2:04.1',
    shooting: '0+0',
    status: 'TIME',
    splitValues: {
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
  var settings = UserSettings.defaults().copyWith(localeCode: 'en');

  @override
  Future<UserSettings> load() async => settings;

  @override
  Future<void> save(UserSettings settings) async {
    this.settings = settings;
  }
}
