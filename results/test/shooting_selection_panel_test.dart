import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/athlete/presentation/biathlon_result_panel.dart';
import 'package:results/features/events/domain/result_event.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/biathlon_comparison.dart';
import 'package:results/features/profile/presentation/me_page.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/presentation/shooting_selection_panel.dart';
import 'package:results/l10n/app_localizations.dart';

RaceResult result(
  String id, {
  String status = '',
  bool relay = false,
  int count = 4,
}) {
  final data = <String, dynamic>{
    'totalMs': 60000,
    'status': status,
    'isRelay': relay,
    'analysisSummary': {
      'biathlon': {
        'metrics': {'shootingCount': count, 'skiTimeMs': 20000, 'skiRank': 1},
        'passes': {
          for (var i = count; i >= 1; i--)
            'shoot$i': {
              'index': i,
              'position': i <= count ~/ 2 ? 'prone' : 'standing',
              'rangeMs': i * 10000,
              'misses': i - 1,
              'rangeRank': 1,
            },
        },
      },
    },
  };
  if (!relay) return RaceResult.fromMap(id, data);
  data['entrant'] = {'kind': 'team'};
  data['team'] = {
    'members': [
      {'legNumber': 1, 'name': 'Athlete'},
    ],
    'legs': [
      {
        'legNumber': 1,
        'biathlon': (data['analysisSummary'] as Map)['biathlon'],
      },
    ],
  };
  return relayLegRaceResult(RaceResult.fromMap(id, data), 1)!;
}

AthleteRace race(
  String event,
  String id, {
  String status = '',
  bool relay = false,
  int count = 4,
}) => AthleteRace(
  eventId: event,
  classId: 'class',
  resultId: id,
  athleteId: 'athlete',
  name: 'Athlete',
  className: 'Senior',
  clubName: '',
  teamName: '',
  bib: '1',
  rank: 1,
  finishRank: 1,
  totalText: '1:00',
  totalMs: 60000,
  shooting: '',
  status: status,
  isRelay: relay,
  biathlonMetrics: BiathlonRaceMetrics.fromResult(
    result(id, relay: relay, count: count),
  ),
);

Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: buildAppTheme(AppThemeVariant.alpineLight),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> choose(WidgetTester tester, String key, String label) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'single-race selector uses within-position ordinal and chosen metric',
    (tester) async {
      final current = result('single');
      await tester.pumpWidget(
        app(BiathlonResultPanel(analysis: current.biathlon!, result: current)),
      );
      expect(find.byKey(const Key('season-shooting-statistics')), findsNothing);
      await choose(tester, 'shooting-pass-selector', '1st standing');
      expect(
        find.byKey(const Key('shooting-observation-single-3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('shooting-observation-single-2')),
        findsNothing,
      );
      await choose(tester, 'shooting-metric-selector', 'Time on the range');
      expect(
        find.descendant(
          of: find.byKey(const Key('shooting-observation-single-3')),
          matching: find.text('0:30.0'),
        ),
        findsOneWidget,
      );
      await choose(tester, 'shooting-pass-selector', '2nd standing');
      expect(
        find.byKey(const Key('shooting-observation-single-4')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'season summary pools series and follows the existing pass selector',
    (tester) async {
      await tester.pumpWidget(
        app(
          AthleteSeasonResults(
            profile: const AthleteProfile(
              athleteId: 'athlete',
              displayName: 'Athlete',
              normalizedName: 'athlete',
              primaryClubId: null,
              primaryTeamId: null,
              events: [],
            ),
            races: [
              race('old', 'short', count: 2),
              race('new', 'long'),
              race('new', 'relay', relay: true, count: 2),
              for (final status in ['DNF', 'DNS', 'DFQ', 'DSQ', 'DQ'])
                race('new', status, status: status),
            ],
            events: [
              ResultEvent(
                id: 'old',
                name: 'Old',
                sportName: 'Biathlon',
                date: DateTime(2025, 4, 30),
                place: '',
              ),
              ResultEvent(
                id: 'new',
                name: 'New',
                sportName: 'Biathlon',
                date: DateTime(2025, 5, 1),
                place: '',
              ),
            ],
          ),
        ),
      );
      Finder card(String id) => find.byKey(Key('season-shooting-$id'));
      void value(String id, String text) => expect(
        find.descendant(of: card(id), matching: find.text(text)),
        findsOneWidget,
      );
      value('hit-percent', '76.7 %');
      value('hit-percent', '23 hits / 30 known shots');
      value('hit-percent', '6 valid series · 2 missing measurements');
      value('average-misses', '1.2');
      value('mean-range-time', '0:20.0');
      value('mean-range-time', '8 valid series · 0 missing measurements');
      value('median-range-time', '0:20.0');
      expect(
        find.byKey(const Key('biathlon-average-hit-percent')),
        findsNothing,
      );
      await choose(tester, 'shooting-pass-selector', '1st standing');
      value('hit-percent', '70.0 %');
      value('hit-percent', '7 hits / 10 known shots');
      value('mean-range-time', '0:23.3');
      await choose(tester, 'shooting-pass-selector', '2nd standing');
      value('hit-percent', '40.0 %');
      value('hit-percent', 'Races without selectable recorded series: 2');
      await tester.ensureVisible(find.byKey(const Key('season-2025')));
      await tester.tap(find.byKey(const Key('season-2025')));
      await tester.pumpAndSettle();
      value('hit-percent', 'Races without selectable recorded series: 1');
      await choose(tester, 'shooting-pass-selector', 'All shootings');
      value('hit-percent', '70.0 %');
      value('hit-percent', '14 hits / 20 known shots');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'season selection preserves shooting controls and excludes all nonfinishers',
    (tester) async {
      await tester.pumpWidget(
        app(
          AthleteSeasonResults(
            profile: const AthleteProfile(
              athleteId: 'athlete',
              displayName: 'Athlete',
              normalizedName: 'athlete',
              primaryClubId: null,
              primaryTeamId: null,
              events: [],
            ),
            races: [
              race('old', 'old'),
              race('new', 'new', relay: true, count: 2),
              race('unknown', 'unknown'),
              for (final status in ['DNF', 'DNS', 'DFQ', 'DSQ', 'DQ'])
                race('new', status, status: status),
            ],
            events: [
              ResultEvent(
                id: 'old',
                name: 'Old race',
                sportName: 'Biathlon',
                date: DateTime(2025, 4, 30),
                place: '',
              ),
              ResultEvent(
                id: 'new',
                name: 'New relay',
                sportName: 'Biathlon',
                date: DateTime(2025, 5, 1),
                place: '',
              ),
            ],
          ),
        ),
      );
      final panel = find.byType(ShootingSelectionPanel);
      expect(
        tester.widget<ShootingSelectionPanel>(panel).entries,
        hasLength(3),
      );
      await choose(tester, 'shooting-metric-selector', 'Time on the range');
      await choose(tester, 'shooting-pass-selector', '1st standing');
      await tester.ensureVisible(find.byKey(const Key('season-2025')));
      await tester.tap(find.byKey(const Key('season-2025')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ShootingSelectionPanel>(panel).entries.single.id,
        'new/class//new',
      );
      expect(
        find.byKey(const Key('shooting-observation-new/class//new-2')),
        findsOneWidget,
      );
      expect(find.text('0:20.0'), findsWidgets);
      expect(
        find.byKey(const Key('shooting-observation-old/class//old-3')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nonfinisher can be read without ranking against completed athletes',
    (tester) async {
      final current = result('dnf', status: 'DNF');
      await tester.pumpWidget(
        app(
          BiathlonResultPanel(
            analysis: current.biathlon!,
            result: current,
            classResults: [result('finished')],
          ),
        ),
      );
      expect(
        find.text('This result is excluded from statistics.'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('biathlon-ski-rank'))).data,
        'Rank –',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('biathlon-shooting-1-time-rank')),
            )
            .data,
        'No. –',
      );
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'localized relay selector fits 250px in ${locale.languageCode}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(250, 900);
        addTearDown(tester.view.reset);
        final current = result('relay', relay: true, count: 2);
        await tester.pumpWidget(
          app(
            ShootingSelectionPanel(
              statisticsRaces: [race('event', 'relay', relay: true, count: 2)],
              entries: [
                ShootingSelectionEntry(
                  id: 'relay',
                  label: 'Relay',
                  metrics: BiathlonRaceMetrics.fromResult(current)!,
                ),
              ],
            ),
            locale: locale,
          ),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ShootingSelectionPanel)),
        );
        expect(find.text(l10n.shootingRelayUnavailable), findsOneWidget);
        expect(find.text(l10n.seasonShootingTitle), findsOneWidget);
        expect(find.text(l10n.seasonShootingCoverage(0, 2)), findsNWidgets(2));
        await choose(
          tester,
          'shooting-metric-selector',
          l10n.biathlonRangeTime,
        );
        await choose(
          tester,
          'shooting-pass-selector',
          l10n.shootingSecondStanding,
        );
        expect(find.text(l10n.shootingNoMatch), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
