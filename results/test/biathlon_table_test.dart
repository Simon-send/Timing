import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/presentation/biathlon_table.dart';
import 'package:results/features/results/presentation/results_table.dart';
import 'package:results/features/settings/domain/user_settings.dart';

void main() {
  testWidgets('uses persisted ski ranks in the biathlon result list', (
    tester,
  ) async {
    final fasterByTime = _result(
      id: 'faster-by-time',
      name: 'Faster by time',
      skiTimeMs: 100000,
      skiRank: 2,
    );
    final slowerByTime = _result(
      id: 'slower-by-time',
      name: 'Slower by time',
      skiTimeMs: 200000,
      skiRank: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: Scaffold(
          body: BiathlonTable(
            rows: [_row(fasterByTime, 'FAST'), _row(slowerByTime, 'SLOW')],
            sortKey: 'ski',
            onSortKeyChanged: (_) {},
            tableDensity: TableDensity.comfortable,
            affiliationView: ResultAffiliationView.club,
            onAffiliationViewToggle: () {},
            onAthleteTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('2(FAST)'), findsOneWidget);
    expect(find.text('3(SLOW)'), findsOneWidget);
  });
}

ResultTableRow _row(RaceResult result, String originalPlacement) {
  return ResultTableRow(
    result: result,
    classId: 'class-1',
    className: 'Senior',
    color: null,
    originalPlacementLabel: originalPlacement,
  );
}

RaceResult _result({
  required String id,
  required String name,
  required int skiTimeMs,
  required int skiRank,
}) {
  return RaceResult(
    id: id,
    rank: null,
    bib: id,
    name: name,
    club: '',
    totalMs: skiTimeMs,
    totalText: '2:00.0',
    shooting: '',
    status: 'TIME',
    splitValues: const {},
    biathlon: BiathlonAnalysis(
      skiTimeMs: skiTimeMs,
      netSkiTimeMs: null,
      shootingTimeMs: null,
      penaltyTimeMs: null,
      missesTotal: null,
      skiRank: skiRank,
      netSkiRank: null,
      shootingRank: null,
      penaltyRank: null,
      passes: const [],
    ),
  );
}
