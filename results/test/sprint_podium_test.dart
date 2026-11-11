import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/results/domain/sprint_podium.dart';

void main() {
  test('reads both time measures and preserves independent sample sizes', () {
    final podium = SprintPodium.fromMap({
      'phase': 'semifinal',
      'points': {
        'local-mid': {
          'cumMeanMs': 46021,
          'cumCount': 3,
          'legMeanMs': 15941,
          'legCount': 2,
        },
        'local-finish': {'cumMeanMs': 148200, 'cumCount': 1},
        'unknown': {'legMeanMs': 13500, 'legCount': 0},
      },
    });

    expect(podium?.phase, SprintPhase.semifinal);
    expect(podium?.points['local-mid'], (
      cumulative: (meanMs: 46021, count: 3),
      leg: (meanMs: 15941, count: 2),
    ));
    expect(podium?.points['local-finish'], (
      cumulative: (meanMs: 148200, count: 1),
      leg: null,
    ));
    expect(podium?.points.containsKey('unknown'), isFalse);
  });

  test('ignores absent, unknown-phase and incomplete reference data', () {
    expect(SprintPodium.fromMap(null), isNull);
    expect(SprintPodium.fromMap({'phase': 'overall'}), isNull);
    expect(
      SprintPodium.fromMap({
        'phase': 'prolog',
        'points': {
          'first': {
            'cumMeanMs': 0,
            'cumCount': 3,
            'legMeanMs': 11000,
            'legCount': 4,
          },
          'second': {'cumCount': 1},
          'third': {'cumMeanMs': 28000},
          'fourth': {'cumMeanMs': double.nan, 'cumCount': 2},
        },
      }),
      isNull,
    );
  });
}
