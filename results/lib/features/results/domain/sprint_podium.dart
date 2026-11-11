import '../../../core/firebase/firestore_mappers.dart';

enum SprintPhase { prolog, quarterfinal, semifinal, finalRound }

typedef SprintPodiumMean = ({int meanMs, int count});
typedef SprintPodiumPoint = ({
  SprintPodiumMean? cumulative,
  SprintPodiumMean? leg,
});

class SprintPodium {
  const SprintPodium._(this.phase, this.points);

  static SprintPodium? fromMap(Object? value) {
    final data = asStringMap(value);
    final phase = switch (data['phase']) {
      'prolog' => SprintPhase.prolog,
      'quarterfinal' => SprintPhase.quarterfinal,
      'semifinal' => SprintPhase.semifinal,
      'final' => SprintPhase.finalRound,
      _ => null,
    };
    if (phase == null) return null;

    final points = <String, SprintPodiumPoint>{};
    for (final entry in asStringMap(data['points']).entries) {
      final point = asStringMap(entry.value);
      final cumulative = _readMean(point['cumMeanMs'], point['cumCount']);
      final leg = _readMean(point['legMeanMs'], point['legCount']);
      if (cumulative != null || leg != null) {
        points[entry.key] = (cumulative: cumulative, leg: leg);
      }
    }
    return points.isEmpty
        ? null
        : SprintPodium._(phase, Map.unmodifiable(points));
  }

  final SprintPhase phase;
  final Map<String, SprintPodiumPoint> points;
}

SprintPodiumMean? _readMean(Object? meanMs, Object? count) {
  if (meanMs is! num || !meanMs.isFinite || meanMs < 1) return null;
  if (count is! int || count < 1 || count > 3) return null;
  return (meanMs: meanMs.round(), count: count);
}
