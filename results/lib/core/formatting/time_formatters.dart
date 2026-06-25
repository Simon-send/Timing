String formatDate(DateTime? date) {
  if (date == null) return '';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String formatDurationMs(int? ms) {
  if (ms == null) return '';
  final tenths = (ms / 100).round();
  final totalSeconds = tenths ~/ 10;
  final tenth = tenths % 10;
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds.$tenth';
}
