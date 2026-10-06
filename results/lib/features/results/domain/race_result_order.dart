import 'race_result.dart';

/// Orders results by status, rank, time and name, with missing numbers last.
int compareRaceResults(RaceResult a, RaceResult b) {
  final statusCompare = a.statusSortOrder.compareTo(b.statusSortOrder);
  if (statusCompare != 0) return statusCompare;
  if (a.rank != b.rank) {
    if (a.rank == null) return 1;
    if (b.rank == null) return -1;
    return a.rank!.compareTo(b.rank!);
  }
  if (a.totalMs != b.totalMs) {
    if (a.totalMs == null) return 1;
    if (b.totalMs == null) return -1;
    return a.totalMs!.compareTo(b.totalMs!);
  }
  final nameCompare = a.name.compareTo(b.name);
  return nameCompare != 0 ? nameCompare : a.id.compareTo(b.id);
}
