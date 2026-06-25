import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../core/formatting/time_formatters.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/race_result.dart';
import '../domain/result_sort_mode.dart';
import '../domain/split_def.dart';

class ResultsTable extends StatelessWidget {
  const ResultsTable({
    super.key,
    required this.rows,
    required this.selectedSplitId,
    required this.splitRange,
    required this.sortMode,
    required this.onSortModeChanged,
    required this.tableDensity,
    this.disabledResultId,
    this.onLoadMore,
    this.isLoadingMore = false,
    required this.onAthleteTap,
  });

  final List<ResultTableRow> rows;
  final String? selectedSplitId;
  final SplitRangeSelection? splitRange;
  final ResultSortMode sortMode;
  final ValueChanged<ResultSortMode> onSortModeChanged;
  final TableDensity tableDensity;
  final String? disabledResultId;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final ValueChanged<ResultTableRow> onAthleteTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sortedRows = _sortedRows(rows, selectedSplitId, splitRange, sortMode);
    final winnerMs = _winnerMs(
      sortedRows,
      selectedSplitId,
      splitRange,
      sortMode,
    );
    final rowHeight = tableDensity == TableDensity.compact ? 42.0 : 54.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      primary: false,
      child: ResultsLoadMoreScrollView(
        onLoadMore: onLoadMore,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DataTable(
              showCheckboxColumn: false,
              sortColumnIndex: _sortColumnIndex(sortMode),
              sortAscending: true,
              headingRowHeight: 42,
              dataRowMinHeight: rowHeight,
              dataRowMaxHeight: rowHeight + 8,
              horizontalMargin: 12,
              columnSpacing: 26,
              columns: [
                DataColumn(label: Text(l10n.bib.toUpperCase())),
                DataColumn(label: Text(l10n.athlete.toUpperCase())),
                DataColumn(label: Text(l10n.club.toUpperCase())),
                DataColumn(label: Text(l10n.shooting.toUpperCase())),
                DataColumn(
                  label: Text(l10n.split.toUpperCase()),
                  onSort: (columnIndex, ascending) {
                    onSortModeChanged(ResultSortMode.split);
                  },
                ),
                DataColumn(
                  label: Text(l10n.time.toUpperCase()),
                  numeric: true,
                  onSort: (columnIndex, ascending) {
                    onSortModeChanged(ResultSortMode.cumulative);
                  },
                ),
                DataColumn(label: Text(l10n.gap.toUpperCase()), numeric: true),
              ],
              rows: [
                for (var index = 0; index < sortedRows.length; index++)
                  DataRow(
                    color: _rowColor(context, sortedRows[index]),
                    onSelectChanged: _isDisabled(sortedRows[index])
                        ? null
                        : (_) => onAthleteTap(sortedRows[index]),
                    cells: _cellsForResult(
                      sortedRows[index],
                      selectedSplitId,
                      splitRange,
                      sortMode,
                      winnerMs,
                      index,
                    ),
                  ),
              ],
            ),
            if (isLoadingMore) const TableLoadingMoreIndicator(),
          ],
        ),
      ),
    );
  }

  bool _isDisabled(ResultTableRow row) {
    return disabledResultId != null && row.result.id == disabledResultId;
  }

  WidgetStateProperty<Color?>? _rowColor(
    BuildContext context,
    ResultTableRow row,
  ) {
    if (!_isDisabled(row)) return null;
    return WidgetStatePropertyAll(
      Theme.of(context).disabledColor.withValues(alpha: 0.16),
    );
  }

  List<DataCell> _cellsForResult(
    ResultTableRow row,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
    int? winnerMs,
    int index,
  ) {
    final result = row.result;
    final displayRow = row.copyWith(
      activeSplitRankLabel: _activeSplitRankLabel(
        result,
        selectedSplitId,
        splitRange,
      ),
    );
    final showOriginalPlacement = !_isFinalTimeSort(
      result,
      selectedSplitId,
      splitRange,
      sortMode,
    );
    return [
      DataCell(_MonoText(result.bib.isEmpty ? '-' : result.bib)),
      DataCell(
        _NameCell(
          row: displayRow,
          placement: _placement(
            displayRow,
            index,
            showOriginalPlacement: showOriginalPlacement,
          ),
        ),
      ),
      DataCell(Text(result.club.isEmpty ? '-' : result.club)),
      DataCell(_MonoText(_shootingText(result, selectedSplitId, splitRange))),
      DataCell(
        _MonoText(
          _splitText(result, selectedSplitId, splitRange),
          alignEnd: true,
        ),
      ),
      DataCell(_MonoText(_timeText(result, selectedSplitId), alignEnd: true)),
      DataCell(
        _MonoText(
          _gapText(result, selectedSplitId, splitRange, sortMode, winnerMs),
          alignEnd: true,
        ),
      ),
    ];
  }

  static List<ResultTableRow> _sortedRows(
    List<ResultTableRow> rows,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
  ) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      if (a.result.isFinished != b.result.isFinished) {
        return a.result.isFinished ? -1 : 1;
      }
      final aMs = _sortMs(a.result, selectedSplitId, splitRange, sortMode);
      final bMs = _sortMs(b.result, selectedSplitId, splitRange, sortMode);
      if (aMs != null && bMs != null && aMs != bMs) {
        return aMs - bMs;
      }
      if (aMs != null) return -1;
      if (bMs != null) return 1;
      return a.result.name.compareTo(b.result.name);
    });
    return sorted;
  }

  static int? _winnerMs(
    List<ResultTableRow> rows,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
  ) {
    int? best;
    for (final row in rows) {
      final timeMs = _sortMs(row.result, selectedSplitId, splitRange, sortMode);
      if (timeMs == null || timeMs <= 0) continue;
      if (best == null || timeMs < best) best = timeMs;
    }
    return best;
  }

  static String _splitText(
    RaceResult result,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
  ) {
    final rangeMs = _rangeSplitMs(result, splitRange);
    if (rangeMs != null) {
      final text = formatDurationMs(rangeMs);
      return text.isEmpty ? '-' : text;
    }
    if (selectedSplitId == null) return '-';
    final split = result.splitValues[selectedSplitId];
    if (split == null || split.legText.isEmpty) return '-';
    return split.legText;
  }

  static String _timeText(RaceResult result, String? selectedSplitId) {
    if (selectedSplitId == null) {
      return result.totalText.isEmpty ? '-' : result.totalText;
    }
    final split = result.splitValues[selectedSplitId];
    if (split == null || split.cumText.isEmpty) return '-';
    return split.cumText;
  }

  static String _shootingText(
    RaceResult result,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
  ) {
    final rangeText = _rangeShootingText(result, splitRange);
    if (rangeText != null) return rangeText;
    if (selectedSplitId != null) {
      final split = result.splitValues[selectedSplitId];
      if (split != null) {
        if (split.additionParts.isNotEmpty) {
          return split.additionParts.join('+');
        }
        if (split.addition.isNotEmpty) {
          return split.addition;
        }
      }
      return '';
    }
    return result.shooting.isEmpty ? '-' : result.shooting;
  }

  static int? _sortMs(
    RaceResult result,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
  ) {
    if (sortMode == ResultSortMode.split) {
      final rangeMs = _rangeSplitMs(result, splitRange);
      if (rangeMs != null) return rangeMs;
    }
    if (selectedSplitId == null) return result.totalMs;
    final split = result.splitValues[selectedSplitId];
    return switch (sortMode) {
      ResultSortMode.cumulative => split?.cumMs,
      ResultSortMode.split => split?.legMs,
    };
  }

  static String _gapText(
    RaceResult result,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
    int? winnerMs,
  ) {
    final timeMs = _sortMs(result, selectedSplitId, splitRange, sortMode);
    if (winnerMs == null || timeMs == null) return '-';
    final gap = timeMs - winnerMs;
    if (gap <= 0) return '+0.0';
    final tenths = (gap / 100).round();
    final totalSeconds = tenths ~/ 10;
    final tenth = tenths % 10;
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '+$minutes:$seconds.$tenth';
  }

  static String _placement(
    ResultTableRow row,
    int index, {
    required bool showOriginalPlacement,
  }) {
    final result = row.result;
    if (result.isFinished) {
      final sortedPlacement = '${index + 1}';
      final originalPlacement =
          row.activeSplitRankLabel ?? row.originalPlacementLabel;
      if (!showOriginalPlacement || originalPlacement.isEmpty) {
        return sortedPlacement;
      }
      return '$sortedPlacement($originalPlacement)';
    }
    final status = result.status.trim();
    final placement = status.isEmpty ? 'DNF' : status;
    return showOriginalPlacement ? '$placement(DNF)' : placement;
  }

  static int _sortColumnIndex(ResultSortMode sortMode) {
    return switch (sortMode) {
      ResultSortMode.split => 4,
      ResultSortMode.cumulative => 5,
    };
  }

  static bool _isFinalTimeSort(
    RaceResult result,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
  ) {
    if (sortMode != ResultSortMode.cumulative) return false;
    final effectiveSplitId = splitRange?.toSplitId ?? selectedSplitId;
    if (effectiveSplitId == null) return true;
    final split = result.splitValues[effectiveSplitId];
    return split?.cumMs != null &&
        result.totalMs != null &&
        split!.cumMs == result.totalMs;
  }

  static int? _rangeSplitMs(
    RaceResult result,
    SplitRangeSelection? splitRange,
  ) {
    if (splitRange == null) return null;
    final toMs = result.splitValues[splitRange.toSplitId]?.cumMs;
    if (toMs == null) return null;
    final fromSplitId = splitRange.fromSplitId;
    if (fromSplitId == null) return toMs;
    final fromMs = result.splitValues[fromSplitId]?.cumMs;
    if (fromMs == null) return null;
    final delta = toMs - fromMs;
    return delta >= 0 ? delta : null;
  }

  static String? _activeSplitRankLabel(
    RaceResult result,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
  ) {
    final effectiveSplitId = splitRange?.toSplitId ?? selectedSplitId;
    if (effectiveSplitId == null) return null;
    final rank = result.splitValues[effectiveSplitId]?.cumRank;
    return rank != null && rank > 0 ? '$rank' : null;
  }

  static String? _rangeShootingText(
    RaceResult result,
    SplitRangeSelection? splitRange,
  ) {
    if (splitRange == null) return null;
    final split = result.splitValues[splitRange.toSplitId];
    if (split == null) return '';
    if (split.additionParts.isNotEmpty) {
      return split.additionParts.join('+');
    }
    if (split.addition.isNotEmpty) return split.addition;
    return '';
  }
}

class TableLoadingMoreIndicator extends StatelessWidget {
  const TableLoadingMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 12),
          Text(
            'Laster flere resultater',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class ResultsLoadMoreScrollView extends StatefulWidget {
  const ResultsLoadMoreScrollView({
    super.key,
    required this.child,
    this.onLoadMore,
  });

  final Widget child;
  final VoidCallback? onLoadMore;

  @override
  State<ResultsLoadMoreScrollView> createState() =>
      _ResultsLoadMoreScrollViewState();
}

class _ResultsLoadMoreScrollViewState extends State<ResultsLoadMoreScrollView> {
  static const _loadMoreExtent = 220.0;

  final _controller = ScrollController();
  bool _loadMoreQueued = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void didUpdateWidget(covariant ResultsLoadMoreScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!mounted || widget.onLoadMore == null || !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final nearBottom =
        position.maxScrollExtent <= 0 || position.extentAfter < _loadMoreExtent;
    if (!nearBottom || _loadMoreQueued) return;

    _loadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreQueued = false;
      if (!mounted) return;
      widget.onLoadMore?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      primary: false,
      child: widget.child,
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.row, required this.placement});

  final ResultTableRow row;
  final String placement;

  @override
  Widget build(BuildContext context) {
    final result = row.result;
    return SizedBox(
      width: 320,
      child: Row(
        children: [
          SizedBox(width: 78, child: _MonoText(placement)),
          const SizedBox(width: 10),
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
              color: row.color ?? Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultTableRow {
  const ResultTableRow({
    required this.result,
    required this.classId,
    required this.className,
    required this.color,
    required this.originalPlacementLabel,
    this.activeSplitRankLabel,
  });

  final RaceResult result;
  final String classId;
  final String className;
  final Color? color;
  final String originalPlacementLabel;
  final String? activeSplitRankLabel;

  ResultTableRow copyWith({
    String? originalPlacementLabel,
    String? activeSplitRankLabel,
  }) {
    return ResultTableRow(
      result: result,
      classId: classId,
      className: className,
      color: color,
      originalPlacementLabel:
          originalPlacementLabel ?? this.originalPlacementLabel,
      activeSplitRankLabel: activeSplitRankLabel ?? this.activeSplitRankLabel,
    );
  }
}

class _MonoText extends StatelessWidget {
  const _MonoText(this.text, {this.alignEnd = false});

  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontFeatures: [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
