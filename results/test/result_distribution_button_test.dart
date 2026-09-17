import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/results/presentation/result_distribution_button.dart';

void main() {
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
