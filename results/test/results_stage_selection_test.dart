import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/competition_stage.dart';
import 'package:results/features/results/domain/result_class.dart';
import 'package:results/features/results/presentation/results_page.dart';

void main() {
  const raceClass = ResultClass(
    id: 'class-a',
    name: 'J17',
    resultCount: 12,
    participantCount: 12,
    etappeUid: 100,
    primaryStageId: 'largest',
  );
  const stages = [
    CompetitionStage(
      id: 'largest',
      name: 'Flest utøvere',
      type: 'interval',
      level: 1,
      order: 0,
      classIds: ['class-a', 'class-b'],
      profile: ResultProfile.standard,
      profileSource: ResultProfileSource.eq,
    ),
    CompetitionStage(
      id: 'selected',
      name: 'Valgt ledd',
      type: 'interval',
      level: 2,
      order: 1,
      classIds: ['class-a', 'class-b'],
      profile: ResultProfile.standard,
      profileSource: ResultProfileSource.eq,
    ),
    CompetitionStage(
      id: 'other',
      name: 'Annet ledd',
      type: 'interval',
      level: 3,
      order: 2,
      classIds: ['class-c'],
      profile: ResultProfile.standard,
      profileSource: ResultProfileSource.eq,
    ),
  ];

  test('uses the largest stage only when no stage is selected in the URL', () {
    expect(
      selectActiveCompetitionStage(
        raceClass: raceClass,
        classStages: stages.take(2).toList(),
      )?.id,
      'largest',
    );
    expect(
      selectActiveCompetitionStage(
        raceClass: raceClass,
        classStages: stages.take(2).toList(),
        selectedStageId: 'selected',
      )?.id,
      'selected',
    );
  });

  test(
    'keeps an explicitly selected stage when the next class supports it',
    () {
      expect(
        preservedStageIdForClassChange(
          activeStageId: 'selected',
          targetClassId: 'class-b',
          stages: stages,
        ),
        'selected',
      );
      expect(
        preservedStageIdForClassChange(
          activeStageId: 'selected',
          targetClassId: 'class-c',
          stages: stages,
        ),
        isNull,
      );
    },
  );
}
