import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/athlete/presentation/biathlon_result_panel.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  testWidgets('shows rank for every metric and opens the shooting split', (
    tester,
  ) async {
    const currentAnalysis = BiathlonAnalysis(
      skiTimeMs: 60000,
      netSkiTimeMs: 61000,
      shootingTimeMs: 10000,
      penaltyTimeMs: 1000,
      missesTotal: 1,
      skiRank: 2,
      netSkiRank: null,
      shootingRank: null,
      penaltyRank: null,
      passes: [
        ShootingPass(
          index: 1,
          rangeMs: 10000,
          misses: 1,
          position: 'prone',
          penaltyMs: 1000,
          rangeRank: 2,
        ),
      ],
      laps: [
        BiathlonLap(
          index: 1,
          skiMs: 30000,
          startCumMs: 0,
          endCumMs: 30000,
          startCode: 'start',
          endCode: 'INS1',
          beforeShooting: 1,
        ),
        BiathlonLap(
          index: 2,
          skiMs: 31000,
          startCumMs: 40000,
          endCumMs: 71000,
          startCode: 'UTS1',
          endCode: 'Maal',
          beforeShooting: null,
        ),
      ],
    );
    const fasterAnalysis = BiathlonAnalysis(
      skiTimeMs: 59000,
      netSkiTimeMs: 60000,
      shootingTimeMs: 9000,
      penaltyTimeMs: 0,
      missesTotal: 0,
      skiRank: 1,
      netSkiRank: null,
      shootingRank: null,
      penaltyRank: null,
      passes: [
        ShootingPass(
          index: 1,
          rangeMs: 9000,
          misses: 0,
          position: 'prone',
          penaltyMs: 0,
        ),
      ],
      laps: [
        BiathlonLap(
          index: 1,
          skiMs: 29000,
          startCumMs: 0,
          endCumMs: 29000,
          startCode: 'start',
          endCode: 'INS1',
          beforeShooting: 1,
        ),
        BiathlonLap(
          index: 2,
          skiMs: 30000,
          startCumMs: 38000,
          endCumMs: 68000,
          startCode: 'UTS1',
          endCode: 'Maal',
          beforeShooting: null,
        ),
      ],
    );
    final current = _result(
      id: 'current',
      analysis: currentAnalysis,
      splitValues: const {
        'shoot-1': SplitValue(
          id: 'shoot-1',
          label: 'S1',
          sort: 3,
          cumRank: 2,
          legRank: 2,
          cumMs: 30000,
          legMs: 10000,
          cumText: '0:30.0',
          legText: '0:10.0',
          status: '',
          addition: '1',
          additionParts: [1],
          kind: 'shooting',
          roundNumber: 1,
        ),
      },
    );
    final faster = _result(id: 'faster', analysis: fasterAnalysis);
    String? selectedSplitId;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BiathlonResultPanel(
              analysis: currentAnalysis,
              result: current,
              classResults: [current, faster],
              onSplitSelected: (splitId) => selectedSplitId = splitId,
            ),
          ),
        ),
      ),
    );

    for (final id in const [
      'ski',
      'net-ski',
      'shooting',
      'penalty',
      'misses',
    ]) {
      expect(find.byKey(ValueKey('biathlon-$id-rank')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(ValueKey('biathlon-$id-rank'))).data,
        'Rank 2',
      );
    }
    final shootingRank = find.byKey(
      const ValueKey('biathlon-shooting-1-time-rank'),
    );
    expect(shootingRank, findsOneWidget);
    expect(tester.widget<Text>(shootingRank).data, 'Nr 2');
    final missesText = find.textContaining('1 bom');
    expect(missesText, findsOneWidget);
    expect(tester.widget<Text>(missesText).style?.fontSize, 11);
    expect(find.text('Start → inn skyting 1'), findsOneWidget);
    expect(find.text('Ut skyting 1 → mål'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('biathlon-lap-2-rank')))
          .data,
      'Rank 2',
    );

    await tester.tap(find.byKey(const ValueKey('biathlon-shooting-1-link')));
    expect(selectedSplitId, 'shoot-1');
  });

  testWidgets('shooting pass layout fits on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(250, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const analysis = BiathlonAnalysis(
      skiTimeMs: null,
      netSkiTimeMs: null,
      shootingTimeMs: null,
      penaltyTimeMs: null,
      missesTotal: 2,
      skiRank: null,
      netSkiRank: null,
      shootingRank: null,
      penaltyRank: null,
      passes: [
        ShootingPass(
          index: 1,
          rangeMs: 12345,
          misses: 2,
          position: 'standing',
          penaltyMs: 1000,
          rangeRank: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: BiathlonResultPanel(analysis: analysis),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Nr 2'), findsOneWidget);
    expect(find.text('0:12.3'), findsOneWidget);
  });
}

RaceResult _result({
  required String id,
  required BiathlonAnalysis analysis,
  Map<String, SplitValue> splitValues = const {},
}) {
  return RaceResult(
    id: id,
    rank: null,
    bib: id,
    name: id,
    club: '',
    totalMs: 70000,
    totalText: '1:10.0',
    shooting: '',
    status: '',
    splitValues: splitValues,
    biathlon: analysis,
  );
}
