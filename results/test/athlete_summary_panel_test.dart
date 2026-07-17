import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/athlete/presentation/athlete_summary_panel.dart';
import 'package:results/features/results/domain/race_result.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  Widget buildPanel(String shooting) {
    return MaterialApp(
      theme: buildAppTheme(AppThemeVariant.nordicDark),
      locale: const Locale('nb'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: AthleteSummaryPanel(
          result: RaceResult(
            id: 'result-1',
            rank: 1,
            bib: '12',
            name: 'Testutøver',
            club: 'Testklubb',
            totalMs: 60000,
            totalText: '1:00.0',
            shooting: shooting,
            status: 'TIME',
            splitValues: const {},
          ),
        ),
      ),
    );
  }

  testWidgets('hides shooting when the result has no shooting data', (
    tester,
  ) async {
    await tester.pumpWidget(buildPanel(''));

    expect(find.text('Skyting'), findsNothing);
  });

  testWidgets('shows shooting when the result has shooting data', (
    tester,
  ) async {
    await tester.pumpWidget(buildPanel('0+1'));

    expect(find.text('Skyting'), findsOneWidget);
    expect(find.text('0+1'), findsOneWidget);
  });
}
