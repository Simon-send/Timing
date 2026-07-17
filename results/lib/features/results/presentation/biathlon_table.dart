import 'package:flutter/material.dart';

import '../../../core/formatting/time_formatters.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/race_result.dart';
import 'results_table.dart';

class BiathlonTable extends StatelessWidget {
  const BiathlonTable({
    super.key,
    required this.rows,
    required this.sortKey,
    required this.onSortKeyChanged,
    required this.tableDensity,
    required this.affiliationView,
    required this.onAffiliationViewToggle,
    this.disabledResultId,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.searchQuery = '',
    required this.onAthleteTap,
  });

  final List<ResultTableRow> rows;
  final String sortKey;
  final ValueChanged<String> onSortKeyChanged;
  final TableDensity tableDensity;
  final ResultAffiliationView affiliationView;
  final VoidCallback onAffiliationViewToggle;
  final String? disabledResultId;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final String searchQuery;
  final ValueChanged<ResultTableRow> onAthleteTap;

  @override
  Widget build(BuildContext context) {
    final columns = _visibleColumns(rows);
    final activeSortKey = columns.any((column) => column.key == sortKey)
        ? sortKey
        : columns.firstOrNull?.key ?? 'ski';
    final sortedRows = _sortedRows(rows, activeSortKey);
    final visibleRows = sortedRows.indexed
        .where((entry) => entry.$2.result.matchesSearch(searchQuery))
        .toList();
    final rowHeight = tableDensity == TableDensity.compact ? 42.0 : 54.0;
    return ResultsLoadMoreViewport(
      onLoadMore: onLoadMore,
      isLoadingMore: isLoadingMore,
      itemCount: rows.length,
      child: RepaintBoundary(
        child: DataTable(
          showCheckboxColumn: false,
          sortColumnIndex: columns.isEmpty
              ? null
              : _sortColumnIndex(activeSortKey, columns),
          sortAscending: true,
          headingRowHeight: 42,
          dataRowMinHeight: rowHeight,
          dataRowMaxHeight: rowHeight + 8,
          horizontalMargin: 8,
          columnSpacing: 26,
          columns: [
            const DataColumn(label: Text('PLASS')),
            const DataColumn(label: Text('UTOVER')),
            DataColumn(
              label: ResultAffiliationHeader(
                view: affiliationView,
                clubLabel: 'KLUBB/TEAM',
                teamLabel: 'TEAM/KLUBB',
                onToggle: onAffiliationViewToggle,
              ),
            ),
            for (final column in columns)
              DataColumn(
                label: SortableTableHeader(label: column.label),
                numeric: true,
                onSort: (_, _) => onSortKeyChanged(column.key),
              ),
          ],
          rows: [
            for (final (index, row) in visibleRows)
              DataRow(
                color: _rowColor(context, row),
                onSelectChanged: _isDisabled(row)
                    ? null
                    : (_) => onAthleteTap(row),
                cells: _cellsForResult(
                  sortedRows,
                  index,
                  columns,
                  activeSortKey,
                  affiliationView,
                ),
              ),
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
    if (_isDisabled(row)) {
      return WidgetStatePropertyAll(
        Theme.of(context).disabledColor.withValues(alpha: 0.16),
      );
    }
    final color = switch (row.highlight) {
      ResultRowHighlight.favorite => Theme.of(context).colorScheme.tertiary,
      ResultRowHighlight.self => Theme.of(context).colorScheme.primary,
      ResultRowHighlight.affiliationMate => Theme.of(
        context,
      ).colorScheme.secondary,
      ResultRowHighlight.none => null,
    };
    if (color == null) return null;
    final alpha = switch (row.highlight) {
      ResultRowHighlight.favorite => 0.24,
      ResultRowHighlight.self => 0.22,
      ResultRowHighlight.affiliationMate => 0.14,
      ResultRowHighlight.none => 0.0,
    };
    return WidgetStatePropertyAll(color.withValues(alpha: alpha));
  }

  List<DataCell> _cellsForResult(
    List<ResultTableRow> sortedRows,
    int index,
    List<_BiathlonColumn> columns,
    String activeSortKey,
    ResultAffiliationView affiliationView,
  ) {
    final row = sortedRows[index];
    final result = row.result;
    final analysis = result.biathlon ?? const BiathlonAnalysis.empty();
    final placement = _placement(
      sortedRows,
      index,
      activeSortKey,
      showOriginalPlacement: true,
    );
    return [
      DataCell(_MonoText(placement)),
      DataCell(_NameCell(row: row)),
      DataCell(Text(_affiliationText(result, affiliationView))),
      for (final column in columns)
        DataCell(_MonoText(column.text(analysis), alignEnd: true)),
    ];
  }

  static String _affiliationText(
    RaceResult result,
    ResultAffiliationView view,
  ) {
    final value = result.affiliationName(view);
    return value.isEmpty ? '-' : value;
  }

  static bool hasBiathlonData(List<ResultTableRow> rows) {
    return rows.any((row) => row.result.biathlon?.hasData ?? false);
  }

  static List<_BiathlonColumn> _visibleColumns(List<ResultTableRow> rows) {
    final columns = <_BiathlonColumn>[];
    if (rows.any((row) => row.result.biathlon?.skiTimeMs != null)) {
      columns.add(
        _BiathlonColumn(
          key: 'ski',
          label: 'SKITID',
          text: (analysis) => _timeText(analysis.skiTimeMs),
        ),
      );
    }
    if (rows.any((row) => row.result.biathlon?.shootingTimeMs != null)) {
      columns.add(
        _BiathlonColumn(
          key: 'shooting',
          label: 'SKYTETID',
          text: (analysis) => _timeText(analysis.shootingTimeMs),
        ),
      );
    }
    if (rows.any((row) => row.result.biathlon?.penaltyTimeMs != null)) {
      columns.add(
        _BiathlonColumn(
          key: 'penalty',
          label: 'STRAFF',
          text: (analysis) => _timeText(analysis.penaltyTimeMs),
        ),
      );
    }
    if (rows.any((row) => row.result.biathlon?.missesTotal != null)) {
      columns.add(
        _BiathlonColumn(
          key: 'misses',
          label: 'BOM',
          text: (analysis) => _numberText(analysis.missesTotal),
        ),
      );
    }

    final indexes = <int>{};
    for (final row in rows) {
      indexes.addAll(
        (row.result.biathlon?.passes ?? const <ShootingPass>[])
            .where((pass) => pass.rangeMs != null)
            .map((pass) => pass.index),
      );
    }
    final sorted = indexes.toList()..sort();
    for (final index in sorted) {
      columns.add(
        _BiathlonColumn(
          key: 'range:$index',
          label: 'S$index',
          text: (analysis) => _timeText(analysis.passAt(index)?.rangeMs),
        ),
      );
    }
    return columns;
  }

  static List<ResultTableRow> _sortedRows(
    List<ResultTableRow> rows,
    String sortKey,
  ) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final statusCompare = a.result.statusSortOrder.compareTo(
        b.result.statusSortOrder,
      );
      if (statusCompare != 0) return statusCompare;
      final aValue = _sortValue(a.result, sortKey);
      final bValue = _sortValue(b.result, sortKey);
      if (aValue != null && bValue != null && aValue != bValue) {
        return aValue - bValue;
      }
      if (aValue != null) return -1;
      if (bValue != null) return 1;
      return a.result.name.compareTo(b.result.name);
    });
    return sorted;
  }

  static int? _sortValue(RaceResult result, String sortKey) {
    final analysis = result.biathlon;
    if (analysis == null) return null;
    if (sortKey == 'ski') return analysis.skiTimeMs;
    if (sortKey == 'shooting') return analysis.shootingTimeMs;
    if (sortKey == 'penalty') return analysis.penaltyTimeMs;
    if (sortKey == 'misses') return analysis.missesTotal;
    if (sortKey.startsWith('range:')) {
      final index = int.tryParse(sortKey.substring('range:'.length));
      if (index == null) return null;
      return analysis.passAt(index)?.rangeMs;
    }
    return analysis.skiTimeMs;
  }

  static String _timeText(int? ms) {
    final text = formatDurationMs(ms);
    return text.isEmpty ? '-' : text;
  }

  static String _numberText(int? value) {
    return value == null ? '-' : '$value';
  }

  String _placement(
    List<ResultTableRow> rows,
    int index,
    String sortKey, {
    required bool showOriginalPlacement,
  }) {
    final row = rows[index];
    final status = row.result.status.trim();
    if (!row.result.isFinished) {
      final placement = status.isEmpty ? 'DNF' : status;
      final relayOverallRank = row.result.relayOverallRank;
      if (relayOverallRank != null && relayOverallRank > 0) {
        return '$placement($relayOverallRank)';
      }
      return showOriginalPlacement ? '$placement(DNF)' : placement;
    }

    final currentSortValue = _sortValue(row.result, sortKey);
    if (currentSortValue == null) return '-';
    for (var i = 0; i < index; i++) {
      if (_sortValue(rows[i].result, sortKey) == currentSortValue) {
        return _withOriginalPlacement(
          i + 1,
          row,
          showOriginalPlacement: showOriginalPlacement,
        );
      }
    }
    return _withOriginalPlacement(
      index + 1,
      row,
      showOriginalPlacement: showOriginalPlacement,
    );
  }

  static int _sortColumnIndex(String sortKey, List<_BiathlonColumn> columns) {
    final index = columns.indexWhere((column) => column.key == sortKey);
    return index < 0 ? 3 : 3 + index;
  }

  static String _withOriginalPlacement(
    int sortedPlacement,
    ResultTableRow row, {
    required bool showOriginalPlacement,
  }) {
    final placement = '$sortedPlacement';
    final originalPlacement = row.originalPlacementLabel;
    if (!showOriginalPlacement || originalPlacement.isEmpty) {
      return placement;
    }
    return '$placement($originalPlacement)';
  }
}

class _BiathlonColumn {
  const _BiathlonColumn({
    required this.key,
    required this.label,
    required this.text,
  });

  final String key;
  final String label;
  final String Function(BiathlonAnalysis analysis) text;
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.row});

  final ResultTableRow row;

  @override
  Widget build(BuildContext context) {
    final result = row.result;
    return SizedBox(
      width: 320,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: _MonoText(result.bib.isEmpty ? '-' : result.bib),
          ),
          const SizedBox(width: 8),
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
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    result.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (result.advanced) ...[
                  const SizedBox(width: 8),
                  const AdvancementBadge(),
                ],
                if (row.highlight == ResultRowHighlight.favorite) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.star,
                    size: 18,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
