import 'race_result.dart';

/// Orders results by status, rank, time and name, with missing numbers last.
int compareRaceResults(RaceResult a, RaceResult b) {
  final statusCompare = a.statusSortOrder.compareTo(b.statusSortOrder);
  if (statusCompare != 0) return statusCompare;
  final aRank = a.classificationRank ?? a.rank;
  final bRank = b.classificationRank ?? b.rank;
  if (aRank != bRank) {
    if (aRank == null) return 1;
    if (bRank == null) return -1;
    return aRank.compareTo(bRank);
  }
  if (a.totalMs != b.totalMs) {
    if (a.totalMs == null) return 1;
    if (b.totalMs == null) return -1;
    return a.totalMs!.compareTo(b.totalMs!);
  }
  final nameCompare = a.name.compareTo(b.name);
  return nameCompare != 0 ? nameCompare : a.id.compareTo(b.id);
}
