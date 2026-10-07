import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/race_result.dart';

void main() {
  test(
    'sparse importer relay analysis retains measured data without whole-leg time',
    () {
      final data =
          jsonDecode(
                File(
                  'test/fixtures/relay_biathlon_unknown_start.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final team = RaceResult.fromMap('local-team', data);
      final third = relayLegRaceResult(team, 3)!;

      expect(third.totalMs, isNull);
      expect(third.biathlon?.skiTimeMs, isNull);
      expect(third.biathlon?.netSkiTimeMs, isNull);
      expect(third.biathlon?.shootingTimeMs, 6000);
      expect(third.biathlon?.missesTotal, 2);
      expect(third.biathlon?.passAt(1)?.rangeMs, 6000);
      expect(third.splitValues['in3']?.cumMs, isNull);
      expect(third.splitValues['in3']?.legMs, 12000);
    },
  );
}
