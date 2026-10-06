import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/results/presentation/result_distribution_button.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  testWidgets('choosing ski time returns to the same split regression', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    ResultRegressionData regression(
      String target,
      List<ResultRegressionPoint> points,
    ) => ResultRegressionData(
      title: 'Regresjon: Første splitt mot $target',
      subjectLabel: 'Første splitt',
      xLabel: target,
      yLabel: 'Første splitt',
      points: points,
      formatX: (value) => '$value',
      formatY: (value) => '$value',
    );
    final finish = regression('sluttid', const [
      ResultRegressionPoint(x: 100, y: 25, label: 'Ada'),
      ResultRegressionPoint(x: 110, y: 28, label: 'Grace'),
      ResultRegressionPoint(x: 120, y: 32, label: 'Lin'),
    ]);
    final ski = regression('Skitid', const [
      ResultRegressionPoint(x: 80, y: 25, label: 'Ada'),
      ResultRegressionPoint(x: 90, y: 28, label: 'Grace'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ResultDistributionButton(
            data: ResultDistributionData(
              title: 'Første splitt',
              values: const [25, 28, 32],
              formatValue: (value) => '$value',
              regression: finish,
              regressionTargets: [
                ResultRegressionTarget(
                  key: 'finish',
                  label: 'Sluttid',
                  regression: finish,
                ),
                ResultRegressionTarget(
                  key: 'ski',
                  label: 'Skitid',
                  regression: ski,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Fordeling, regresjon og splittanalyse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regresjon'));
    await tester.pumpAndSettle();
    expect(find.text('Regresjon: Første splitt mot sluttid'), findsOneWidget);

    await tester.tap(find.byKey(const Key('regression-target-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('regression-target-ski')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();
    expect(find.text('Regresjon: Første splitt mot sluttid'), findsOneWidget);

    await tester.tap(find.byKey(const Key('regression-target-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('regression-target-ski')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Regresjon: Første splitt mot Skitid'), findsOneWidget);
    expect(find.text('Sammenlign med: Skitid'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Regresjon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows split analysis as a third interactive graph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selectedSplitId;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: Scaffold(
          body: ResultDistributionButton(
            data: ResultDistributionData(
              title: 'Fordeling: tid',
              values: const [100, 110, 120],
              formatValue: (value) => '$value',
              regression: ResultRegressionData(
                title: 'Regresjon',
                subjectLabel: 'Tid',
                xLabel: 'Splitt',
                yLabel: 'Sluttid',
                points: const [
                  ResultRegressionPoint(x: 100, y: 200, label: 'Ada'),
                  ResultRegressionPoint(x: 110, y: 215, label: 'Grace'),
                ],
                formatX: (value) => '$value',
                formatY: (value) => '$value',
              ),
              splitAnalysis: const ResultSplitAnalysisData(
                points: [
                  ResultSplitAnalysisPoint(
                    splitId: 'split-1',
                    label: '1 km',
                    sort: 1,
                    timeCorrelation: 0.72,
                    rankCorrelation: 0.69,
                    sampleSize: 24,
                  ),
                  ResultSplitAnalysisPoint(
                    splitId: 'split-2',
                    label: '2 km',
                    sort: 2,
                    timeCorrelation: 0.84,
                    rankCorrelation: 0.81,
                    sampleSize: 24,
                  ),
                  ResultSplitAnalysisPoint(
                    splitId: 'split-3',
                    label: '3 km',
                    sort: 3,
                    timeCorrelation: 0.93,
                    rankCorrelation: 0.9,
                    sampleSize: 23,
                  ),
                ],
              ),
            ),
            onSplitSelected: (splitId) => selectedSplitId = splitId,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Fordeling, regresjon og splittanalyse'));
    await tester.pumpAndSettle();

    expect(find.text('Fordeling'), findsOneWidget);
    expect(find.text('Regresjon'), findsOneWidget);
    expect(find.text('Splitter'), findsOneWidget);

    await tester.tap(find.text('Splitter'));
    await tester.pumpAndSettle();

    final chart = find.byKey(const Key('split-analysis-chart'));
    expect(chart, findsOneWidget);
    expect(find.text('Splittid ↔ sluttid'), findsOneWidget);
    expect(find.text('Splitplassering ↔ sluttplassering'), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(chart));
    await tester.pump();
    expect(find.text('2 km'), findsWidgets);
    expect(find.text('24 resultater'), findsOneWidget);

    await tester.tapAt(tester.getCenter(chart));
    await tester.pumpAndSettle();
    expect(selectedSplitId, 'split-2');
    expect(find.byType(AlertDialog), findsNothing);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pump();
    await tester.tap(find.byTooltip('Fordeling, regresjon og splittanalyse'));
    await tester.pumpAndSettle();
    expect(find.text('Fordeling'), findsOneWidget);
    expect(find.text('Regresjon'), findsOneWidget);
    expect(find.text('Splitter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
