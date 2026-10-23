/// Shared exclusion contract for rows, aggregates, references and distributions.
/// Partial times or splits never override an explicit non-finishing status.
int resultStatusSortOrder(String status) {
  final normalized = status.trim().toUpperCase();
  if (normalized.contains('DNS') ||
      normalized.contains('DID NOT START') ||
      normalized.contains('IKKE STARTET') ||
      normalized.contains('STARTET IKKE')) {
    return 3;
  }
  if (normalized.contains('DNF') ||
      normalized.contains('DID NOT FINISH') ||
      normalized.contains('BRUTT') ||
      normalized.contains('IKKE FULLF')) {
    return 2;
  }
  if (RegExp(r'\b(DFQ|DSQ|DQ|NC|NQ)\b').hasMatch(normalized) ||
      normalized.contains('DISQUAL') ||
      normalized.contains('DISKVAL')) {
    return 1;
  }
  return 0;
}

bool isExcludedResultStatus(String status) => resultStatusSortOrder(status) > 0;
