import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/profile/domain/athlete_profile.dart';
import 'package:results/features/profile/domain/race_pacing_profile.dart';
import 'package:results/features/profile/presentation/race_pacing_profile_panel.dart';

void main() {
  test('normalizes all splits and averages races on a common time axis', () {
    final profile = buildRacePacingProfile([
      _race(
        resultId: 'first',
        ranks: const [(250, 20), (500, 10)],
        finishRank: 5,
      ),
      _race(
        resultId: 'second',
        ranks: const [(250, 40), (500, 20)],
        finishRank: 10,
      ),
    ], intervalCount: 4);

    expect(profile.raceCount, 2);
    expect(profile.splitCount, 4);
    expect(profile.samples.map((sample) => sample.timeFraction), [
      0.25,
      0.5,
      0.75,
      1,
    ]);
    expect(profile.samples[0].averageRankFraction, closeTo(0.30, 0.0001));
    expect(profile.samples[1].averageRankFraction, closeTo(0.15, 0.0001));
    expect(profile.samples.last.averageRankFraction, closeTo(0.075, 0.0001));
    expect(profile.samples.every((sample) => sample.raceCount == 2), isTrue);
  });

  test('excludes relay races from the pacing profile', () {
    final profile = buildRacePacingProfile([
      _race(resultId: 'individual', ranks: const [(500, 10)], finishRank: 5),
      _race(
        resultId: 'relay',
        ranks: const [(500, 90)],
        finishRank: 95,
        isRelay: true,
      ),
    ], intervalCount: 2);

    expect(profile.raceCount, 1);
    expect(profile.excludedRelayCount, 1);
    expect(profile.samples.first.averageRankFraction, closeTo(0.10, 0.0001));
  });

  test('uses the number of ranked athletes at each split', () {
    final profile = buildRacePacingProfile([
      _race(
        resultId: 'individual',
        ranks: const [(500, 10)],
        splitParticipantCounts: const [20],
        finishRank: 10,
      ),
    ], intervalCount: 2);

    expect(profile.samples.first.timeFraction, 0.5);
    expect(profile.samples.first.averageRankFraction, closeTo(0.5, 0.0001));
    expect(profile.samples.last.averageRankFraction, closeTo(0.1, 0.0001));
  });

  testWidgets('pacing chart exposes aggregate details on hover', (
    tester,
  ) async {
    final race = _race(
      resultId: 'individual',
      ranks: const [(250, 20), (500, 10)],
      finishRank: 5,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeVariant.alpineLight),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 800,
              child: RacePacingProfilePanel(races: [race]),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Løpsoppbygging'), findsOneWidget);
    expect(find.text('1 løp'), findsOneWidget);
    expect(find.text('2 splitter'), findsOneWidget);

    final chart = find.byKey(const Key('race-pacing-chart'));
    final chartRect = tester.getRect(chart);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(chartRect.left, chartRect.top));
    await mouse.moveTo(
      Offset(
        chartRect.left + 52 + (chartRect.width - 74) * 0.5,
        chartRect.center.dy,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('race-pacing-hover-detail')), findsOneWidget);
    expect(find.text('50 % av totaltid'), findsOneWidget);
    expect(find.text('Snitt: topp 10 %'), findsOneWidget);
  });
}

AthleteRace _race({
  required String resultId,
  required List<(int, int)> ranks,
  required int finishRank,
  List<int?>? splitParticipantCounts,
  bool isRelay = false,
}) {
  return AthleteRace(
    eventId: 'event',
    classId: 'class',
    resultId: resultId,
    athleteId: 'athlete',
    name: 'Testutøver',
    className: 'Senior',
    clubName: 'Klubb',
    teamName: '',
    bib: '1',
    rank: finishRank,
    finishRank: finishRank,
    totalText: '16:40',
    shooting: '',
    status: '',
    participantCount: 100,
    totalMs: 1000,
    isRelay: isRelay,
    splits: [
      for (var index = 0; index < ranks.length; index++)
        AthleteRaceSplit(
          id: 'split-$index',
          label: 'Split ${index + 1}',
          sort: index,
          cumRank: ranks[index].$2,
          cumMs: ranks[index].$1,
          participantCount: splitParticipantCounts?[index],
        ),
    ],
  );
}
