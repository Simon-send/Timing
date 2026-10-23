import 'race_result.dart';

enum ShootingMetric { hits, misses, rangeTime }

enum ShootingSelection {
  all,
  prone,
  standing,
  firstProne,
  secondProne,
  firstStanding,
  secondStanding;

  String? get position => switch (this) {
    prone || firstProne || secondProne => 'prone',
    standing || firstStanding || secondStanding => 'standing',
    all => null,
  };

  int? get ordinal => switch (this) {
    firstProne || firstStanding => 1,
    secondProne || secondStanding => 2,
    _ => null,
  };
}

enum ShootingSelectionIssue {
  noMatchingShooting,
  ambiguousOrder,
  incompleteData,
  relayShotDataUnavailable,
  relayPositionsUnavailable,
}

/// One measured shooting, never an inferred zero or a pooled race average.
class ShootingObservation {
  const ShootingObservation({
    required this.index,
    required this.position,
    required this.value,
  });

  final int index;
  final String position;
  final int? value;
}

class ShootingSelectionResult {
  ShootingSelectionResult(
    Iterable<ShootingObservation> observations,
    this.issue,
  ) : observations = List.unmodifiable(observations);

  final List<ShootingObservation> observations;
  final ShootingSelectionIssue? issue;

  Iterable<ShootingObservation> get validObservations =>
      observations.where((observation) => observation.value != null);
}

/// Number within known positions in race order, independent of source order.
/// An unknown/missing earlier position can change an ordinal, so that ordinal
/// has no observations. Unnumbered selections retain known measured passes.
ShootingSelectionResult selectShootingObservations(
  Iterable<ShootingPass> passes,
  ShootingMetric metric,
  ShootingSelection selection, {
  bool isRelay = false,
  int? expectedShootingCount,
  bool positionsReliable = true,
}) {
  if (!positionsReliable && selection.position != null) {
    return ShootingSelectionResult(
      [],
      ShootingSelectionIssue.relayPositionsUnavailable,
    );
  }
  final ordered = passes.toList()..sort((a, b) => a.index.compareTo(b.index));
  final indexes = <int>{};
  final duplicateIndexes = <int>{};
  for (final pass in ordered) {
    if (!indexes.add(pass.index)) duplicateIndexes.add(pass.index);
  }
  String positionOf(ShootingPass pass) =>
      positionsReliable ? pass.position.trim().toLowerCase() : '';
  bool knownPosition(ShootingPass pass) =>
      const {'prone', 'standing'}.contains(positionOf(pass));

  var selected = ordered
      .where(
        (pass) =>
            pass.index > 0 &&
            !duplicateIndexes.contains(pass.index) &&
            (selection.position == null ||
                positionOf(pass) == selection.position),
      )
      .toList();
  final ordinal = selection.ordinal;
  if (ordinal != null) {
    // Persisted relay-leg passes are numbered locally from one. Older global
    // subsets cannot prove that an earlier position is absent, so stay missing.
    var previousIndex = 0;
    var found = 0;
    ShootingPass? match;
    for (final pass in ordered) {
      if (pass.index != previousIndex + 1 ||
          duplicateIndexes.contains(pass.index) ||
          !knownPosition(pass)) {
        return ShootingSelectionResult(
          [],
          ShootingSelectionIssue.ambiguousOrder,
        );
      }
      previousIndex = pass.index;
      if (positionOf(pass) == selection.position && ++found == ordinal) {
        match = pass;
        break;
      }
    }
    selected = match == null ? [] : [match];
  }
  if (selected.isEmpty) {
    return ShootingSelectionResult(
      [],
      ShootingSelectionIssue.noMatchingShooting,
    );
  }
  final relayShotsUnavailable = isRelay && metric != ShootingMetric.rangeTime;
  final observations = [
    for (final pass in selected)
      ShootingObservation(
        index: pass.index,
        position: positionOf(pass),
        value: relayShotsUnavailable
            ? null
            : switch (metric) {
                ShootingMetric.rangeTime =>
                  pass.rangeMs != null && pass.rangeMs! > 0
                      ? pass.rangeMs
                      : null,
                ShootingMetric.hits || ShootingMetric.misses =>
                  pass.misses != null && pass.misses! >= 0 && pass.misses! <= 5
                      ? metric == ShootingMetric.hits
                            ? 5 - pass.misses!
                            : pass.misses
                      : null,
              },
      ),
  ];
  final incomplete =
      duplicateIndexes.isNotEmpty ||
      ordered.indexed.any((item) => item.$2.index != item.$1 + 1) ||
      (expectedShootingCount != null &&
          ordered.length < expectedShootingCount) ||
      (selection.position != null &&
          ordinal == null &&
          ordered.any((pass) => !knownPosition(pass))) ||
      observations.any((observation) => observation.value == null);
  return ShootingSelectionResult(
    observations,
    relayShotsUnavailable
        ? ShootingSelectionIssue.relayShotDataUnavailable
        : !positionsReliable
        ? ShootingSelectionIssue.relayPositionsUnavailable
        : incomplete
        ? ShootingSelectionIssue.incompleteData
        : null,
  );
}
