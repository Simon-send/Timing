import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/presentation/me_page.dart';
import 'package:results/features/profile/presentation/race_pacing_profile_panel.dart';
import 'package:results/features/profile/presentation/result_history_panel.dart';
import 'package:results/l10n/app_localizations.dart';

import 'athlete_season_test.dart' as fixtures;

const _profile = AthleteProfile(
  athleteId: 'athlete',
  displayName: 'Athlete',
  normalizedName: 'athlete',
  primaryClubId: null,
  primaryTeamId: null,
  events: [],
);

void main() {
  testWidgets('result IDs can repeat across events, classes and stages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        fixtures.race('old', 'shared'),
        fixtures.race('new', 'shared', stageId: 'prologue'),
        fixtures.race('new', 'shared', stageId: 'final'),
        fixtures.race('new', 'shared', stageId: 'final', classId: 'other'),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(
        const ValueKey<(String, String, String?, String)>((
          'old',
          'class',
          null,
          'shared',
        )),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<(String, String, String?, String)>((
          'new',
          'class',
          'prologue',
          'shared',
        )),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<(String, String, String?, String)>((
          'new',
          'class',
          'final',
          'shared',
        )),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<(String, String, String?, String)>((
          'new',
          'other',
          'final',
          'shared',
        )),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'one selection controls every result and analysis over all pages',
    (tester) async {
      final races = [
        for (var index = 0; index < 205; index++)
          fixtures.race('old', 'old-$index'),
        fixtures.race('new', 'new'),
        fixtures.race('old', 'excluded', status: 'DFQ'),
        fixtures.race('unknown', 'unknown'),
      ];
      await tester.pumpWidget(_app(races));
      expect(
        tester
            .widget<ResultHistoryPanel>(find.byType(ResultHistoryPanel))
            .entries,
        hasLength(207),
      );
      await tester.tap(find.byKey(const Key('season-2025')));
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<(String, String, String?, String)>((
            'old',
            'class',
            null,
            'old-204',
          )),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<(String, String, String?, String)>((
            'new',
            'class',
            null,
            'new',
          )),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<(String, String, String?, String)>((
            'unknown',
            'class',
            null,
            'unknown',
          )),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ResultHistoryPanel>(find.byType(ResultHistoryPanel))
            .entries,
        hasLength(1),
      );
      expect(
        tester
            .widget<RacePacingProfilePanel>(find.byType(RacePacingProfilePanel))
            .races,
        hasLength(1),
      );
      await tester.tap(find.byKey(const Key('season-2024')));
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<(String, String, String?, String)>((
            'old',
            'class',
            null,
            'old-204',
          )),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<(String, String, String?, String)>((
            'old',
            'class',
            null,
            'excluded',
          )),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ResultHistoryPanel>(find.byType(ResultHistoryPanel))
            .entries,
        hasLength(206),
      );
      await tester.tap(find.byKey(const Key('season-2025')));
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<(String, String, String?, String)>((
            'new',
            'class',
            null,
            'new',
          )),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('season-all')));
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<(String, String, String?, String)>((
            'new',
            'class',
            null,
            'new',
          )),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in [320.0, 1280.0]) {
      testWidgets('season overview fits $width in ${locale.languageCode}', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app([
            fixtures.race('old', 'old'),
            fixtures.race('new', 'new'),
            fixtures.race('unknown', 'unknown'),
          ], locale: locale),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AthleteSeasonResults)),
        );
        expect(find.text(l10n.seasonTitle), findsOneWidget);
        expect(find.text(l10n.seasonAll), findsOneWidget);
        expect(find.text(l10n.seasonUnassignedNotice(1)), findsOneWidget);
        expect(find.text(l10n.seasonUnknown), findsOneWidget);
        expect(find.text(l10n.seasonCompletedCount(3)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('empty history has zero counts and no analysis', (tester) async {
    await tester.pumpWidget(_app([]));
    expect(find.text('0 races'), findsWidgets);
    expect(find.byType(ResultHistoryPanel), findsNothing);
    expect(find.byType(RacePacingProfilePanel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(List<AthleteRace> races, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: buildAppTheme(AppThemeVariant.alpineLight),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AthleteSeasonResults(
            profile: _profile,
            races: races,
            events: [
              fixtures.event('old', DateTime(2025, 4, 30)),
              fixtures.event('new', DateTime(2025, 5, 1)),
            ],
          ),
        ),
      ),
    );
