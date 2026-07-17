import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/athlete/domain/athlete_stage_result.dart';
import 'package:results/features/athlete/presentation/athlete_stage_results_panel.dart';
import 'package:results/features/results/domain/competition_stage.dart';
import 'package:results/features/results/domain/race_result.dart';

void main() {
  const prologue = CompetitionStage(
    id: 'prologue',
    name: 'Prolog',
    type: 'interval',
    level: 1,
    order: 0,
    classIds: ['class-1'],
    profile: ResultProfile.sprint,
    profileSource: ResultProfileSource.eq,
  );
  const heat = CompetitionStage(
    id: 'heat-1',
    name: 'Heat 1',
    type: 'heats',
    level: 2,
    order: 1,
    classIds: ['class-1'],
    profile: ResultProfile.sprint,
    profileSource: ResultProfileSource.eq,
  );

  test('collects the same athlete from prologue and heat', () {
    final results = buildAthleteStageResults(
      stages: const [heat, prologue],
      resultsByStageId: {
        'prologue': [
          _result('prologue-other', 'athlete:1', 'Annen', 61000),
          _result('prologue-ada', 'athlete:2', 'Ada Lovelace', 62000),
        ],
        'heat-1': [
          _result('heat-ada', 'athlete:2', 'Ada Lovelace', 59000),
          _result('heat-other', 'athlete:3', 'Tredje', 60000),
        ],
      },
      athleteId: 'athlete:2',
      athleteName: 'Ada Lovelace',
    );

    expect(results.map((result) => result.stage.id), ['prologue', 'heat-1']);
    expect(results.map((result) => result.athleteResult.id), [
      'prologue-ada',
      'heat-ada',
    ]);
    expect(results.map((result) => result.athleteResult.totalMs), [
      62000,
      59000,
    ]);
  });

  test('finds a relay athlete even when the leg changes between heats', () {
    final results = buildAthleteStageResults(
      stages: const [prologue, heat],
      resultsByStageId: {
        'prologue': [_relayTeam('prologue-team', adaLeg: 1)],
        'heat-1': [_relayTeam('heat-team', adaLeg: 2)],
      },
      athleteId: 'athlete:2',
      athleteName: 'Ada Lovelace',
    );

    expect(results, hasLength(2));
    expect(results.map((result) => result.relayLegNumber), [1, 2]);
    expect(results[0].athleteResult.name, 'Ada Lovelace');
    expect(results[0].athleteResult.totalMs, 60000);
    expect(results[1].athleteResult.totalMs, 70000);
    expect(results[1].results.single.relayLegNumber, 2);
  });

  testWidgets('shows all times and stacked result lists', (tester) async {
    AthleteStageResult? selectedStage;
    final stageResults = buildAthleteStageResults(
      stages: const [prologue, heat],
      resultsByStageId: {
        'prologue': [
          _result('prologue-ada', 'athlete:2', 'Ada Lovelace', 62000),
          _result('prologue-other', 'athlete:3', 'Grace Hopper', 63000),
        ],
        'heat-1': [
          _result('heat-other', 'athlete:3', 'Grace Hopper', 58000),
          _result('heat-ada', 'athlete:2', 'Ada Lovelace', 59000),
        ],
      },
      athleteId: 'athlete:2',
      athleteName: 'Ada Lovelace',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AthleteStageResultsPanel(
              athleteName: 'Ada Lovelace',
              stageResults: stageResults,
              onStageSelected: (value) => selectedStage = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Alle tider'), findsOneWidget);
    expect(find.text('1:02.0'), findsOneWidget);
    expect(find.text('0:59.0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('athlete-stage-heat-1')));
    expect(selectedStage?.stage.id, 'heat-1');

    await tester.tap(find.byKey(const Key('show-athlete-stage-result-lists')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('athlete-stage-result-lists-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('athlete-stage-result-list-prologue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('athlete-stage-result-list-heat-1')),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNWidgets(2));
  });
}

RaceResult _result(String id, String athleteId, String name, int totalMs) {
  return RaceResult.fromMap(id, {
    'athleteId': athleteId,
    'name': name,
    'bib': id,
    'club': 'Testklubb',
    'rank': 1,
    'totalMs': totalMs,
    'status': 'TIME',
  });
}

RaceResult _relayTeam(String id, {required int adaLeg}) {
  final graceLeg = adaLeg == 1 ? 2 : 1;
  return RaceResult.fromMap(id, {
    'entrant': {
      'kind': 'team',
      'name': 'Testlaget',
      'bib': '7',
      'clubName': 'Testklubb',
    },
    'team': {
      'members': [
        {'legNumber': adaLeg, 'name': 'Ada Lovelace', 'athleteId': 'athlete:2'},
        {
          'legNumber': graceLeg,
          'name': 'Grace Hopper',
          'athleteId': 'athlete:3',
        },
      ],
    },
    'timingPoints': [
      {
        'setupUid': 'leg-1-finish',
        'code': 'Veksling',
        'sort': 1,
        'legNumber': 1,
        'cumMs': 60000,
      },
      {
        'setupUid': 'leg-2-finish',
        'code': 'Mål',
        'sort': 2,
        'legNumber': 2,
        'cumMs': 130000,
      },
    ],
    'totalMs': 130000,
    'status': 'TIME',
  });
}
