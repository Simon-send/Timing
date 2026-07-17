import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/athlete/presentation/biathlon_result_panel.dart';
import 'package:results/features/results/domain/race_result.dart';

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
      skiRank: null,
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
        ),
      ],
    );
    const fasterAnalysis = BiathlonAnalysis(
      skiTimeMs: 59000,
      netSkiTimeMs: 60000,
      shootingTimeMs: 9000,
      penaltyTimeMs: 0,
      missesTotal: 0,
      skiRank: null,
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
    for (final id in const ['time', 'misses', 'penalty']) {
      final finder = find.byKey(ValueKey('biathlon-shooting-1-$id-rank'));
      expect(finder, findsOneWidget);
      expect(tester.widget<Text>(finder).data, contains('Rank 2'));
    }

    await tester.tap(find.byKey(const ValueKey('biathlon-shooting-1-link')));
    expect(selectedSplitId, 'shoot-1');
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
