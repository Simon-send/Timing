import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/features/results/domain/result_sort_mode.dart';
import 'package:results/features/results/presentation/results_table.dart';
import 'package:results/features/settings/domain/user_settings.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  testWidgets('sortable header stays white while retaining hover scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: const Scaffold(
          body: Center(child: SortableTableHeader(label: 'TID')),
        ),
      ),
    );

    final header = find.byType(SortableTableHeader);
    final animatedText = find.descendant(
      of: header,
      matching: find.byType(AnimatedDefaultTextStyle),
    );
    final animatedScale = find.descendant(
      of: header,
      matching: find.byType(AnimatedScale),
    );
    final context = tester.element(header);
    final expectedColor = Theme.of(
      context,
    ).dataTableTheme.headingTextStyle!.color;

    expect(
      tester.widget<AnimatedDefaultTextStyle>(animatedText).style.color,
      expectedColor,
    );
    expect(tester.widget<AnimatedScale>(animatedScale).scale, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(header));
    await mouse.moveTo(tester.getCenter(header));
    await tester.pump();

    expect(
      tester.widget<AnimatedDefaultTextStyle>(animatedText).style.color,
      expectedColor,
    );
    expect(tester.widget<AnimatedScale>(animatedScale).scale, 1.04);
  });

  testWidgets('class and table headings stay visible while results scroll', (
    tester,
  ) async {
    final pageScrollController = ScrollController();
    addTearDown(pageScrollController.dispose);

    Widget buildTable() {
      return DataTable(
        headingRowHeight: 42,
        columns: const [
          DataColumn(label: Text('PLASS')),
          DataColumn(label: Text('UTOVER')),
          DataColumn(label: Text('KLUBB')),
          DataColumn(label: SortableTableHeader(label: 'TID')),
        ],
        rows: [
          for (var index = 0; index < 40; index++)
            DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text('Utøver $index')),
                const DataCell(Text('Testklubb')),
                DataCell(Text('${10 + index}:00')),
              ],
            ),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        home: Scaffold(
          body: SingleChildScrollView(
            key: const Key('test-results-scroll'),
            controller: pageScrollController,
            child: Column(
              children: [
                const SizedBox(
                  key: Key('scrolling-result-controls'),
                  height: 260,
                ),
                ResultsLoadMoreViewport(
                  pageScrollController: pageScrollController,
                  itemCount: 40,
                  isLoadingMore: false,
                  stickyClassHeader: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Senior · Finale'),
                  ),
                  stickyTableHeader: buildTable(),
                  child: buildTable(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sticky-results-header')), findsNothing);

    pageScrollController.jumpTo(340);
    await tester.pumpAndSettle();

    final stickyHeader = find.byKey(const Key('sticky-results-header'));
    expect(stickyHeader, findsOneWidget);
    expect(find.byKey(const Key('sticky-result-class')), findsOneWidget);
    final stickyTableHeader = find.byKey(const Key('sticky-table-header'));
    expect(stickyTableHeader, findsOneWidget);
    expect(find.text('Senior · Finale'), findsOneWidget);
    for (final label in const ['PLASS', 'UTOVER', 'KLUBB', 'TID']) {
      final heading = find.descendant(
        of: stickyTableHeader,
        matching: find.text(label),
      );
      expect(heading, findsOneWidget);
      expect(
        tester.getCenter(heading).dy,
        inInclusiveRange(
          tester.getTopLeft(stickyTableHeader).dy,
          tester.getBottomLeft(stickyTableHeader).dy,
        ),
      );
    }
    expect(
      tester.getTopLeft(stickyHeader).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const Key('test-results-scroll'))).dy,
        0.1,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('scrolling-result-controls'))).dy,
      lessThan(0),
    );
  });

  testWidgets('place athlete and time fit on the narrowest mobile layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const result = RaceResult(
      id: 'result-1',
      rank: 1,
      bib: '123',
      name: 'Ola Nordmann',
      club: 'Testklubb',
      totalMs: 60000,
      totalText: '1:00.0',
      shooting: '',
      status: 'TIME',
      splitValues: {},
    );
    const row = ResultTableRow(
      result: result,
      classId: 'class-1',
      className: 'Senior',
      color: null,
      originalPlacementLabel: '1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.nordicDark),
        locale: const Locale('nb'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ResultsTable(
            rows: const [row],
            selectedSplitId: null,
            splitRange: null,
            sortMode: ResultSortMode.cumulative,
            onSortModeChanged: (_) {},
            tableDensity: TableDensity.compact,
            affiliationView: ResultAffiliationView.club,
            onAffiliationViewToggle: () {},
            onAthleteTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewportRight = tester
        .getTopRight(find.byType(ResultsLoadMoreViewport))
        .dx;
    for (final label in const ['#', 'UTØVER', 'TID', 'Ola Nordmann']) {
      final field = find.text(label);
      expect(field, findsOneWidget);
      expect(tester.getTopRight(field).dx, lessThanOrEqualTo(viewportRight));
    }
    expect(find.text('KLUBB/TEAM'), findsNothing);
    expect(find.text('123'), findsNothing);
  });
}
