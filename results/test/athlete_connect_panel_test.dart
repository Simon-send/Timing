import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_providers.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/profile/data/athlete_profile_repository.dart';
import 'package:results/features/profile/domain/athlete_link_state.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/presentation/me_page.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  testWidgets('prefills the Google display name and links a selected match', (
    tester,
  ) async {
    final repository = _FakeAthleteProfileRepository();
    await _pumpPanel(
      tester,
      repository: repository,
      initialName: 'Ada Lovelace',
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Ada Lovelace',
    );

    await tester.tap(find.text('Finn utøver'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'Koble til utøver'));
    await tester.pumpAndSettle();
    expect(repository.linkedAthleteId, 'athlete-ada');
  });

  testWidgets('lets the user skip athlete linking for now', (tester) async {
    final repository = _FakeAthleteProfileRepository();
    var skipped = false;
    await _pumpPanel(
      tester,
      repository: repository,
      allowSkip: true,
      onSkipped: () => skipped = true,
    );

    await tester.tap(find.text('Ikke nå'));
    await tester.pumpAndSettle();

    expect(repository.completedUid, 'user-1');
    expect(skipped, isTrue);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required _FakeAthleteProfileRepository repository,
  String initialName = '',
  bool allowSkip = false,
  VoidCallback? onSkipped,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        athleteProfileRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AthleteConnectPanel(
            uid: 'user-1',
            initialName: initialName,
            allowSkip: allowSkip,
            onSkipped: onSkipped,
          ),
        ),
      ),
    ),
  );
}

class _FakeAthleteProfileRepository implements AthleteProfileRepository {
  String? linkedAthleteId;
  String? completedUid;

  static const athlete = AthleteProfile(
    athleteId: 'athlete-ada',
    displayName: 'Ada Lovelace',
    normalizedName: 'ada lovelace',
    primaryClubId: null,
    primaryTeamId: null,
    events: [],
  );

  @override
  Future<void> clearLinkedAthlete(String uid) async {}

  @override
  Future<void> completeAthleteLinkOnboarding(String uid) async {
    completedUid = uid;
  }

  @override
  Future<AthleteAffiliations> fetchAffiliations({
    required String? clubId,
    required String? teamId,
  }) async => const AthleteAffiliations(clubName: null, teamName: null);

  @override
  Future<void> linkAthlete({
    required String uid,
    required AthleteProfile athlete,
  }) async {
    linkedAthleteId = athlete.athleteId;
  }

  @override
  Future<List<AthleteProfile>> searchAthletesByFullName(String fullName) async {
    return fullName == 'Ada Lovelace' ? [athlete] : const [];
  }

  @override
  Stream<AthleteProfile?> watchAthlete(String athleteId) => Stream.value(null);

  @override
  Stream<List<AthleteRace>> watchAthleteRaces(String athleteId) =>
      Stream.value(const []);

  @override
  Stream<AthleteLinkState> watchAthleteLinkState(String uid) => Stream.value(
    const AthleteLinkState(athleteId: null, onboardingCompleted: false),
  );

  @override
  Stream<String?> watchLinkedAthleteId(String uid) => Stream.value(null);
}
