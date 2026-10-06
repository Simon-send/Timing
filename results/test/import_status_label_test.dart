import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/competition_stage.dart';
import 'package:results/features/results/presentation/import_status_label.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  test('stage import status is separate for each class and optional', () {
    final stage = CompetitionStage.fromMap('stage', {
      'classImportStates': {'one': 'partial', 'two': 'updated', 'bad': 3},
    });
    expect(stage.classImportStates, {'one': 'partial', 'two': 'updated'});
    expect(CompetitionStage.fromMap('old', {}).classImportStates, isEmpty);
  });

  testWidgets('shows all import states on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in {
      'waiting': 'Venter på resultater',
      'importing': 'Importerer',
      'partial': 'Delvis importert',
      'updated': 'Oppdatert',
    }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('nb'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ImportStatusLabel(state: entry.key)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
