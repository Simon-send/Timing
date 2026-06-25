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
    this.disabledResultId,
    this.onLoadMore,
    this.isLoadingMore = false,
    required this.onAthleteTap,
  });

  final List<ResultTableRow> rows;
  final String sortKey;
  final ValueChanged<String> onSortKeyChanged;
  final TableDensity tableDensity;
  final String? disabledResultId;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final ValueChanged<ResultTableRow> onAthleteTap;

  @override
  Widget build(BuildContext context) {
    final columns = _visibleColumns(rows);
    final activeSortKey = columns.any((column) => column.key == sortKey)
        ? sortKey
        : columns.firstOrNull?.key ?? 'ski';
    final sortedRows = _sortedRows(rows, activeSortKey);
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
              sortColumnIndex: columns.isEmpty
                  ? null
                  : _sortColumnIndex(activeSortKey, columns),
              sortAscending: true,
              headingRowHeight: 42,
              dataRowMinHeight: rowHeight,
              dataRowMaxHeight: rowHeight + 8,
              horizontalMargin: 12,
              columnSpacing: 26,
              columns: [
                const DataColumn(label: Text('STARTNR')),
                const DataColumn(label: Text('UTOVER')),
                const DataColumn(label: Text('TEAM')),
                for (final column in columns)
                  DataColumn(
                    label: Text(column.label),
                    numeric: true,
                    onSort: (_, _) => onSortKeyChanged(column.key),
                  ),
              ],
              rows: [
                for (var index = 0; index < sortedRows.length; index++)
                  DataRow(
                    color: _rowColor(context, sortedRows[index]),
                    onSelectChanged: _isDisabled(sortedRows[index])
                        ? null
                        : (_) => onAthleteTap(sortedRows[index]),
                    cells: _cellsForResult(
                      sortedRows,
                      index,
                      columns,
                      activeSortKey,
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
    List<ResultTableRow> sortedRows,
    int index,
    List<_BiathlonColumn> columns,
    String activeSortKey,
  ) {
    final row = sortedRows[index];
    final result = row.result;
    final analysis = result.biathlon;
    return [
      DataCell(_MonoText(result.bib.isEmpty ? '-' : result.bib)),
      DataCell(
        _NameCell(
          row: row,
          placement: _placement(
            sortedRows,
            index,
            activeSortKey,
            showOriginalPlacement: true,
          ),
        ),
      ),
      DataCell(Text(result.club.isEmpty ? '-' : result.club)),
      for (final column in columns)
        DataCell(_MonoText(column.text(analysis), alignEnd: true)),
    ];
  }

  static bool hasBiathlonData(List<ResultTableRow> rows) {
    return rows.any((row) => row.result.biathlon.hasData);
  }

  static List<_BiathlonColumn> _visibleColumns(List<ResultTableRow> rows) {
    final columns = <_BiathlonColumn>[];
    if (rows.any((row) => row.result.biathlon.netSkiTimeMs != null)) {
      columns.add(
        _BiathlonColumn(
          key: 'ski',
          label: 'SKITID',
          text: (analysis) => _timeText(analysis.netSkiTimeMs),
        ),
      );
    }
    if (rows.any((row) => row.result.biathlon.shootingTimeMs != null)) {
      columns.add(
        _BiathlonColumn(
          key: 'shooting',
          label: 'SKYTETID',
          text: (analysis) => _timeText(analysis.shootingTimeMs),
        ),
      );
    }
    if (rows.any((row) => row.result.biathlon.penaltyTimeMs != null)) {
      columns.add(
        _BiathlonColumn(
          key: 'penalty',
          label: 'STRAFF',
          text: (analysis) => _timeText(analysis.penaltyTimeMs),
        ),
      );
    }
    if (rows.any((row) => row.result.biathlon.missesTotal != null)) {
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
        row.result.biathlon.passes
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
      if (a.result.isFinished != b.result.isFinished) {
        return a.result.isFinished ? -1 : 1;
      }
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
    if (sortKey == 'ski') return analysis.netSkiTimeMs;
    if (sortKey == 'shooting') return analysis.shootingTimeMs;
    if (sortKey == 'penalty') return analysis.penaltyTimeMs;
    if (sortKey == 'misses') return analysis.missesTotal;
    if (sortKey.startsWith('range:')) {
      final index = int.tryParse(sortKey.substring('range:'.length));
      if (index == null) return null;
      return analysis.passAt(index)?.rangeMs;
    }
    return analysis.netSkiTimeMs;
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
