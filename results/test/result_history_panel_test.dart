import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/profile/presentation/result_history_panel.dart';

void main() {
  test('top percent is calculated from rank and participant count', () {
    const entry = ResultHistoryEntry(
      eventName: 'Testløp',
      className: 'Senior',
      date: null,
      rank: 3,
      participantCount: 30,
    );

    expect(entry.topPercent, 10);
  });

  testWidgets('result history switches between top percent and rank', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.alpineLight),
        home: const Scaffold(
          body: ResultHistoryPanel(
            entries: [
              ResultHistoryEntry(
                eventName: 'Første løp',
                className: 'Senior',
                date: null,
                rank: 4,
                participantCount: 40,
              ),
              ResultHistoryEntry(
                eventName: 'Andre løp',
                className: 'Senior',
                date: null,
                rank: 2,
                participantCount: 50,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Resultatutvikling'), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<ResultHistoryMetric>>(
            find.byType(SegmentedButton<ResultHistoryMetric>),
          )
          .selected,
      {ResultHistoryMetric.topPercent},
    );

    await tester.tap(find.text('Rank'));
    await tester.pump();

    expect(
      tester
          .widget<SegmentedButton<ResultHistoryMetric>>(
            find.byType(SegmentedButton<ResultHistoryMetric>),
          )
          .selected,
      {ResultHistoryMetric.rank},
    );
  });

  testWidgets('history point shows event details on hover and opens result', (
    tester,
  ) async {
    ResultHistoryEntry? openedEntry;
    const entry = ResultHistoryEntry(
      eventId: 'event-1',
      classId: 'class-1',
      resultId: 'result-1',
      eventName: 'SommerlÃ¸pet',
      className: 'Senior',
      date: null,
      rank: 3,
      participantCount: 30,
      totalText: '42:15',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.alpineLight),
        home: Scaffold(
          body: ResultHistoryPanel(
            entries: const [entry],
            onEntryTap: (value) => openedEntry = value,
          ),
        ),
      ),
    );

    final point = find.byKey(const ValueKey('result-history-point-0'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(point));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('SommerlÃ¸pet'), findsOneWidget);
    expect(
      find.textContaining('Resultat: Plass 3 av 30 · 42:15'),
      findsOneWidget,
    );

    await tester.tap(point);
    expect(openedEntry, same(entry));
  });
}
