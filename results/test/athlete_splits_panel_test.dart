import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/athlete/presentation/athlete_splits_panel.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/domain/split_def.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  test('split statistics exclude DNS, DNF and zero times', () {
    SplitValue split(int? cumulative, int? leg, {int? storedRank}) =>
        SplitValue(
          id: 'split-1',
          label: 'MT1',
          sort: 1,
          cumRank: storedRank,
          legRank: storedRank,
          cumMs: cumulative,
          legMs: leg,
          cumText: '',
          legText: '',
          status: '',
          addition: '',
          additionParts: const [],
        );

    RaceResult result(String id, String status, int? total, SplitValue value) =>
        RaceResult(
          id: id,
          rank: null,
          bib: id,
          name: id,
          club: '',
          totalMs: total,
          totalText: '',
          shooting: '',
          status: status,
          splitValues: {'split-1': value},
        );

    final winner = result(
      'winner',
      'TIME',
      10000,
      split(3000, 3000, storedRank: 8),
    );
    final runnerUp = result('second', 'TIME', 11000, split(4000, 4000));
    final dns = result('dns', 'DNS', null, split(0, 0));
    final dnf = result('dnf', 'DNF', null, split(1, 1));
    final zero = result('zero', 'TIME', 12000, split(0, 0));
    final classResults = [dns, dnf, zero, winner, runnerUp];

    final corrected = correctedSplitRank(
      winner.splitValues['split-1']!,
      winner,
      classResults,
    );
    expect(corrected.cumRank, 1);
    expect(corrected.legRank, 1);
    expect(corrected.cumRankCount, 2);
    expect(
      correctedSplitRank(
        runnerUp.splitValues['split-1']!,
        runnerUp,
        classResults,
      ).cumRank,
      2,
    );
    expect(
      correctedSplitRank(
        dnf.splitValues['split-1']!,
        dnf,
        classResults,
      ).cumRank,
      isNull,
    );
    expect(dnf.statusSortOrder, greaterThan(winner.statusSortOrder));
    expect(dns.statusSortOrder, greaterThan(dnf.statusSortOrder));
  });

  testWidgets('disposition shows every detected round', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const stations = [
      'A',
      'B',
      'C',
      'A',
      'B',
      'C',
      'A',
      'B',
      'C',
      'A',
      'B',
      'C',
      'A',
      'B',
      'C',
    ];
    var cumulativeMs = 0;
    final splitValues = <String, SplitValue>{};
    final splitDefs = <SplitDef>[];

    for (var index = 0; index < stations.length; index++) {
      final id = 'split-$index';
      final legMs = 10000 + index * 100;
      cumulativeMs += legMs;
      splitValues[id] = SplitValue(
        id: id,
        label: '${stations[index]} ${index + 1}',
        sort: index,
        cumRank: 1,
        legRank: 1,
        cumMs: cumulativeMs,
        legMs: legMs,
        cumText: '',
        legText: '',
        status: '',
        addition: '',
        additionParts: const [],
      );
      splitDefs.add(
        SplitDef(
          id: id,
          label: stations[index],
          sort: index,
          kind: 'split',
          stationName: stations[index],
          isPublic: true,
        ),
      );
    }

    final result = RaceResult(
      id: 'result-1',
      rank: 1,
      bib: '1',
      name: 'Testutover',
      club: 'Testklubb',
      totalMs: cumulativeMs,
      totalText: '',
      shooting: '',
      status: 'TIME',
      splitValues: splitValues,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        locale: const Locale('nb'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AthleteSplitsPanel(
              result: result,
              classResults: [result],
              publicSplitIds: splitValues.keys.toSet(),
              splitDefs: splitDefs,
              onSplitSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('athlete-split-times'))).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('athlete-disposition-overview')),
            )
            .dy,
      ),
    );
    expect(find.text('R4'), findsOneWidget);
    expect(find.text('R5'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('disposition-bar-split-13')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Differanse'));
    await tester.tap(find.text('Differanse'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('R5'));
    await tester.tap(find.text('R5'));
    await tester.pumpAndSettle();

    expect(find.text('Differanse fra R5 i tid'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('disposition-bar-split-13')),
      findsOneWidget,
    );
  });
}
