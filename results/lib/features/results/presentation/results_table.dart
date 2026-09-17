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
    required this.affiliationView,
    required this.onAffiliationViewToggle,
    this.disabledResultId,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.searchQuery = '',
    this.pageScrollController,
    this.stickyClassHeader,
    required this.onAthleteTap,
  });

  final List<ResultTableRow> rows;
  final String? selectedSplitId;
  final SplitRangeSelection? splitRange;
  final ResultSortMode sortMode;
  final ValueChanged<ResultSortMode> onSortModeChanged;
  final TableDensity tableDensity;
  final ResultAffiliationView affiliationView;
  final VoidCallback onAffiliationViewToggle;
  final String? disabledResultId;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final String searchQuery;
  final ScrollController? pageScrollController;
  final Widget? stickyClassHeader;
  final ValueChanged<ResultTableRow> onAthleteTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final prioritizeCoreColumns = width < 850;
    final ultraCompact = width < 320;
    final compact = width < 600;
    final showAffiliation = width >= 850;
    final showBib = width >= 480;
    final showGap = width >= 700;
    final athleteColumnWidth = prioritizeCoreColumns
        ? (width - (ultraCompact ? 170 : 202)).clamp(72.0, 300.0)
        : 320.0;
    final effectiveSortMode = splitRange?.isIndependent == true
        ? ResultSortMode.split
        : sortMode;
    final sortedRows = _sortedRows(
      rows,
      selectedSplitId,
      splitRange,
      effectiveSortMode,
    );
    final visibleRows = sortedRows.indexed
        .where((entry) => entry.$2.result.matchesSearch(searchQuery))
        .toList();
    final hasShootingData = sortedRows.any(
      (row) => _shootingText(
        row.result,
        selectedSplitId,
        splitRange,
      ).replaceAll('-', '').trim().isNotEmpty,
    );
    final winnerMs = _winnerMs(
      sortedRows,
      selectedSplitId,
      splitRange,
      effectiveSortMode,
    );
    final rowHeight = prioritizeCoreColumns
        ? tableDensity == TableDensity.compact
              ? 38.0
              : 44.0
        : tableDensity == TableDensity.compact
        ? 42.0
        : 54.0;
    final timeColumn = DataColumn(
      label: splitRange?.isIndependent == true
          ? Text(l10n.time.toUpperCase())
          : SortableTableHeader(label: l10n.time.toUpperCase()),
      numeric: true,
      onSort: splitRange?.isIndependent == true
          ? null
          : (columnIndex, ascending) {
              onSortModeChanged(ResultSortMode.cumulative);
            },
    );
    final splitColumn = DataColumn(
      label: SortableTableHeader(label: l10n.split.toUpperCase()),
      onSort: (columnIndex, ascending) {
        onSortModeChanged(ResultSortMode.split);
      },
    );
    final table = RepaintBoundary(
      child: DataTable(
        showCheckboxColumn: false,
        sortColumnIndex: _sortColumnIndex(
          effectiveSortMode,
          hasShootingData: hasShootingData,
          prioritizeCoreColumns: prioritizeCoreColumns,
          showAffiliation: showAffiliation,
        ),
        sortAscending: true,
        headingRowHeight: prioritizeCoreColumns ? 36 : 42,
        dataRowMinHeight: rowHeight,
        dataRowMaxHeight: rowHeight + (prioritizeCoreColumns ? 2 : 8),
        horizontalMargin: prioritizeCoreColumns ? 0 : 8,
        columnSpacing: prioritizeCoreColumns ? 4 : 26,
        columns: [
          DataColumn(
            label: Text(ultraCompact ? '#' : l10n.place.toUpperCase()),
          ),
          DataColumn(label: Text(l10n.athlete.toUpperCase())),
          if (prioritizeCoreColumns) timeColumn,
          if (showAffiliation)
            DataColumn(
              label: ResultAffiliationHeader(
                view: affiliationView,
                clubLabel: '${l10n.club.toUpperCase()}/TEAM',
                teamLabel: 'TEAM/${l10n.club.toUpperCase()}',
                onToggle: onAffiliationViewToggle,
              ),
            ),
          if (hasShootingData)
            DataColumn(label: Text(l10n.shooting.toUpperCase())),
          splitColumn,
          if (!prioritizeCoreColumns) timeColumn,
          if (showGap)
            DataColumn(label: Text(l10n.gap.toUpperCase()), numeric: true),
        ],
        rows: [
          for (final (index, row) in visibleRows)
            DataRow(
              color: _rowColor(context, row),
              onSelectChanged: _isDisabled(row)
                  ? null
                  : (_) => onAthleteTap(row),
              cells: _cellsForResult(
                row,
                sortedRows,
                selectedSplitId,
                splitRange,
                effectiveSortMode,
                winnerMs,
                index,
                affiliationView,
                hasShootingData,
                showAffiliation,
                showGap,
                compact,
                showBib,
                prioritizeCoreColumns,
                athleteColumnWidth,
              ),
            ),
        ],
      ),
    );
    return ResultsLoadMoreViewport(
      onLoadMore: onLoadMore,
      isLoadingMore: isLoadingMore,
      itemCount: rows.length,
      pageScrollController: pageScrollController,
      stickyClassHeader: stickyClassHeader,
      stickyTableHeader: table,
      child: table,
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
    ResultTableRow row,
    List<ResultTableRow> sortedRows,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
    int? winnerMs,
    int index,
    ResultAffiliationView affiliationView,
    bool hasShootingData,
    bool showAffiliation,
    bool showGap,
    bool compact,
    bool showBib,
    bool prioritizeCoreColumns,
    double athleteColumnWidth,
  ) {
    final result = row.result;
    final showOriginalPlacement = !_isFinalTimeSort(
      result,
      selectedSplitId,
      splitRange,
      sortMode,
    );
    final placement = _placement(
      row,
      sortedRows,
      index,
      selectedSplitId: selectedSplitId,
      splitRange: splitRange,
      sortMode: sortMode,
      showOriginalPlacement: showOriginalPlacement,
    );
    final placeCell = DataCell(_MonoText(placement));
    final athleteCell = DataCell(
      _NameCell(
        row: row,
        compact: compact,
        showBib: showBib,
        width: athleteColumnWidth,
      ),
    );
    final splitCell = DataCell(
      _MonoText(
        _splitText(result, selectedSplitId, splitRange),
        alignEnd: true,
      ),
    );
    final timeCell = DataCell(
      _MonoText(_timeText(result, selectedSplitId, splitRange), alignEnd: true),
    );
    final optionalCells = <DataCell>[
      if (showAffiliation)
        DataCell(Text(_affiliationText(result, affiliationView))),
      if (hasShootingData)
        DataCell(_MonoText(_shootingText(result, selectedSplitId, splitRange))),
      splitCell,
      if (!prioritizeCoreColumns) timeCell,
      if (showGap)
        DataCell(
          _MonoText(
            _gapText(result, selectedSplitId, splitRange, sortMode, winnerMs),
            alignEnd: true,
          ),
        ),
    ];
    if (prioritizeCoreColumns) {
      return [placeCell, athleteCell, timeCell, ...optionalCells];
    }
    return [placeCell, athleteCell, ...optionalCells];
  }

  static String _affiliationText(
    RaceResult result,
    ResultAffiliationView view,
  ) {
    final value = result.affiliationName(view);
    return value.isEmpty ? '-' : value;
  }

  static List<ResultTableRow> _sortedRows(
    List<ResultTableRow> rows,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
  ) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final statusCompare = a.result.statusSortOrder.compareTo(
        b.result.statusSortOrder,
      );
      if (statusCompare != 0) return statusCompare;
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
    if (split == null) return '-';
    if (split.legText.isNotEmpty) return split.legText;
    final derivedText = formatDurationMs(
      effectiveSplitLegMs(result, selectedSplitId),
    );
    return derivedText.isEmpty ? '-' : derivedText;
  }

  static String _timeText(
    RaceResult result,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
  ) {
    if (splitRange?.isIndependent == true) return '-';
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
      ResultSortMode.split => effectiveSplitLegMs(result, selectedSplitId),
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
    List<ResultTableRow> sortedRows,
    int index, {
    required String? selectedSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
    required bool showOriginalPlacement,
  }) {
    final result = row.result;
    if (result.isFinished) {
      final currentTime = _sortMs(
        result,
        selectedSplitId,
        splitRange,
        sortMode,
      );
      var rank = index + 1;
      if (currentTime != null) {
        for (var previousIndex = 0; previousIndex < index; previousIndex++) {
          final previousTime = _sortMs(
            sortedRows[previousIndex].result,
            selectedSplitId,
            splitRange,
            sortMode,
          );
          if (previousTime == currentTime) {
            rank = previousIndex + 1;
            break;
          }
        }
      }
      final sortedPlacement = '$rank';
      final originalPlacement = row.originalPlacementLabel;
      if (!showOriginalPlacement || originalPlacement.isEmpty) {
        return sortedPlacement;
      }
      return '$sortedPlacement($originalPlacement)';
    }
    final status = result.status.trim();
    final placement = status.isEmpty ? 'DNF' : status;
    final relayOverallRank = result.relayOverallRank;
    if (relayOverallRank != null && relayOverallRank > 0) {
      return '$placement($relayOverallRank)';
    }
    return showOriginalPlacement ? '$placement(DNF)' : placement;
  }

  static int _sortColumnIndex(
    ResultSortMode sortMode, {
    required bool hasShootingData,
    required bool prioritizeCoreColumns,
    required bool showAffiliation,
  }) {
    if (prioritizeCoreColumns) {
      return switch (sortMode) {
        ResultSortMode.cumulative => 2,
        ResultSortMode.split => 3 + (hasShootingData ? 1 : 0),
      };
    }
    final affiliationOffset = showAffiliation ? 1 : 0;
    final shootingOffset = hasShootingData ? 1 : 0;
    return switch (sortMode) {
      ResultSortMode.split => 2 + affiliationOffset + shootingOffset,
      ResultSortMode.cumulative => 3 + affiliationOffset + shootingOffset,
    };
  }

  static bool _isFinalTimeSort(
    RaceResult result,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
  ) {
    // A relay leg always keeps the team's overall relay placement in
    // parentheses, including when the selected split is Etappetid.
    if (result.relayLegNumber != null) return false;
    if (splitRange?.isIndependent == true) return false;
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
    if (splitRange.isIndependent) {
      return combinedSplitLegMs(result, splitRange.includedSplitIds);
    }
    final toMs = result.splitValues[splitRange.toSplitId]?.cumMs;
    if (toMs == null) return null;
    final fromSplitId = splitRange.fromSplitId;
    if (fromSplitId == null) return toMs;
    final fromMs = result.splitValues[fromSplitId]?.cumMs;
    if (fromMs == null) return null;
    final delta = toMs - fromMs;
    return delta >= 0 ? delta : null;
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

class SortableTableHeader extends StatefulWidget {
  const SortableTableHeader({super.key, required this.label});

  final String label;

  @override
  State<SortableTableHeader> createState() => _SortableTableHeaderState();
}

class _SortableTableHeaderState extends State<SortableTableHeader> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headingColor =
        theme.dataTableTheme.headingTextStyle?.color ??
        theme.colorScheme.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.04 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          style: TextStyle(color: headingColor, fontWeight: FontWeight.w800),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class ResultsLoadMoreViewport extends StatelessWidget {
  const ResultsLoadMoreViewport({
    super.key,
    required this.child,
    required this.itemCount,
    required this.isLoadingMore,
    this.onLoadMore,
    this.pageScrollController,
    this.stickyClassHeader,
    this.stickyTableHeader,
  });

  final Widget child;
  final int itemCount;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final ScrollController? pageScrollController;
  final Widget? stickyClassHeader;
  final Widget? stickyTableHeader;

  @override
  Widget build(BuildContext context) {
    if (pageScrollController != null) {
      return _PageEmbeddedResultsViewport(
        pageScrollController: pageScrollController!,
        enableStickyHeaders: MediaQuery.sizeOf(context).width >= 600,
        onLoadMore: onLoadMore,
        isLoadingMore: isLoadingMore,
        itemCount: itemCount,
        stickyClassHeader: stickyClassHeader,
        stickyTableHeader: stickyTableHeader,
        child: child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final overlayHeight = (constraints.maxHeight * 0.2).clamp(96.0, 180.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: ResultsLoadMoreScrollView(
                onLoadMore: onLoadMore,
                isLoadingMore: isLoadingMore,
                itemCount: itemCount,
                child: child,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: overlayHeight,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  reverseDuration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.16),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: isLoadingMore
                      ? const TableLoadingMoreIndicator(
                          key: ValueKey('results-loading-more'),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('results-loading-idle'),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PageEmbeddedResultsViewport extends StatefulWidget {
  const _PageEmbeddedResultsViewport({
    required this.pageScrollController,
    required this.enableStickyHeaders,
    required this.child,
    required this.itemCount,
    required this.isLoadingMore,
    required this.stickyClassHeader,
    required this.stickyTableHeader,
    this.onLoadMore,
  });

  final ScrollController pageScrollController;
  final bool enableStickyHeaders;
  final Widget child;
  final int itemCount;
  final bool isLoadingMore;
  final Widget? stickyClassHeader;
  final Widget? stickyTableHeader;
  final VoidCallback? onLoadMore;

  @override
  State<_PageEmbeddedResultsViewport> createState() =>
      _PageEmbeddedResultsViewportState();
}

class _PageEmbeddedResultsViewportState
    extends State<_PageEmbeddedResultsViewport> {
  static const _loadMoreExtent = 220.0;

  double get _stickyClassHeight =>
      MediaQuery.sizeOf(context).width < 600 ? 40 : 48;
  double get _stickyTableHeight =>
      MediaQuery.sizeOf(context).width < 850 ? 36 : 42;

  bool _loadRequestPending = false;
  bool _loadMoreQueued = false;
  bool _stickyVisible = false;
  bool _syncingHorizontalScroll = false;
  Rect _stickyRect = Rect.zero;
  double _tableContentWidth = 0;
  OverlayEntry? _stickyOverlay;
  final GlobalKey _horizontalViewportKey = GlobalKey();
  final GlobalKey _tableAnchorKey = GlobalKey();
  final ScrollController _bodyHorizontalController = ScrollController();
  final ScrollController _stickyHorizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.pageScrollController.addListener(_handlePageScroll);
    _bodyHorizontalController.addListener(_syncStickyHorizontalScroll);
    _stickyHorizontalController.addListener(_syncBodyHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncStickyOverlay();
      _maybeLoadMore();
    });
  }

  @override
  void didUpdateWidget(covariant _PageEmbeddedResultsViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageScrollController != widget.pageScrollController) {
      oldWidget.pageScrollController.removeListener(_handlePageScroll);
      widget.pageScrollController.addListener(_handlePageScroll);
    }
    final receivedMoreItems = widget.itemCount > oldWidget.itemCount;
    final loadFinished = oldWidget.isLoadingMore && !widget.isLoadingMore;
    if (receivedMoreItems || loadFinished) _loadRequestPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncStickyOverlay();
      _maybeLoadMore();
    });
  }

  @override
  void dispose() {
    widget.pageScrollController.removeListener(_handlePageScroll);
    _bodyHorizontalController.removeListener(_syncStickyHorizontalScroll);
    _stickyHorizontalController.removeListener(_syncBodyHorizontalScroll);
    _bodyHorizontalController.dispose();
    _stickyHorizontalController.dispose();
    _stickyOverlay?.remove();
    _stickyOverlay = null;
    super.dispose();
  }

  void _handlePageScroll() {
    _maybeLoadMore();
    if (widget.enableStickyHeaders) _updateStickyOverlay();
  }

  void _syncStickyOverlay() {
    if (!widget.enableStickyHeaders) {
      _stickyVisible = false;
      _stickyOverlay?.remove();
      _stickyOverlay = null;
      return;
    }
    _ensureStickyOverlay();
    _updateStickyOverlay();
  }

  void _ensureStickyOverlay() {
    if (!mounted ||
        widget.stickyClassHeader == null ||
        widget.stickyTableHeader == null) {
      _stickyOverlay?.remove();
      _stickyOverlay = null;
      return;
    }
    if (_stickyOverlay != null) return;
    _stickyOverlay = OverlayEntry(builder: _buildStickyOverlay);
    Overlay.of(context).insert(_stickyOverlay!);
  }

  Widget _buildStickyOverlay(BuildContext overlayContext) {
    if (!_stickyVisible || _stickyRect.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(overlayContext).colorScheme;
    return Positioned(
      key: const Key('sticky-results-header'),
      left: _stickyRect.left,
      top: _stickyRect.top,
      width: _stickyRect.width,
      height: _stickyClassHeight + _stickyTableHeight,
      child: Material(
        color: colors.surface,
        elevation: 4,
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const Key('sticky-result-class'),
              height: _stickyClassHeight,
              child: widget.stickyClassHeader,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.outlineVariant),
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: SizedBox(
                key: const Key('sticky-table-header'),
                height: _stickyTableHeight,
                child: SingleChildScrollView(
                  controller: _stickyHorizontalController,
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  child: SizedBox(
                    width: _tableContentWidth,
                    height: _stickyTableHeight,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: _tableContentWidth,
                        maxWidth: _tableContentWidth,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: SizedBox(
                          width: _tableContentWidth,
                          child: widget.stickyTableHeader,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStickyOverlay() {
    if (!mounted ||
        !widget.enableStickyHeaders ||
        _stickyOverlay == null ||
        !widget.pageScrollController.hasClients) {
      return;
    }
    final tableBox =
        _tableAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    final horizontalViewportBox =
        _horizontalViewportKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final verticalViewportBox =
        widget.pageScrollController.position.context.storageContext
                .findRenderObject()
            as RenderBox?;
    if (tableBox == null ||
        horizontalViewportBox == null ||
        overlayBox == null ||
        verticalViewportBox == null ||
        !tableBox.hasSize ||
        !horizontalViewportBox.hasSize ||
        !verticalViewportBox.hasSize) {
      return;
    }

    final tableTop = tableBox.localToGlobal(Offset.zero).dy;
    final tableBottom = tableBox
        .localToGlobal(Offset(0, tableBox.size.height))
        .dy;
    final viewportTop = verticalViewportBox.localToGlobal(Offset.zero).dy;
    final stickyHeight = _stickyClassHeight + _stickyTableHeight;
    final visible =
        tableTop <= viewportTop && tableBottom > viewportTop + stickyHeight;
    final viewportOrigin = horizontalViewportBox.localToGlobal(Offset.zero);
    final overlayOrigin = overlayBox.globalToLocal(
      Offset(viewportOrigin.dx, viewportTop),
    );
    final nextRect = Rect.fromLTWH(
      overlayOrigin.dx,
      overlayOrigin.dy,
      horizontalViewportBox.size.width,
      stickyHeight,
    );
    final nextTableWidth = tableBox.size.width;
    final changed =
        visible != _stickyVisible ||
        nextRect != _stickyRect ||
        nextTableWidth != _tableContentWidth;
    _stickyVisible = visible;
    _stickyRect = nextRect;
    _tableContentWidth = nextTableWidth;
    if (!changed) return;
    _stickyOverlay?.markNeedsBuild();
    if (visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncHorizontalOffset(
          _bodyHorizontalController,
          _stickyHorizontalController,
        );
      });
    }
  }

  void _syncStickyHorizontalScroll() {
    _syncHorizontalOffset(
      _bodyHorizontalController,
      _stickyHorizontalController,
    );
  }

  void _syncBodyHorizontalScroll() {
    _syncHorizontalOffset(
      _stickyHorizontalController,
      _bodyHorizontalController,
    );
  }

  void _syncHorizontalOffset(ScrollController source, ScrollController target) {
    if (_syncingHorizontalScroll || !source.hasClients || !target.hasClients) {
      return;
    }
    final nextOffset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - nextOffset).abs() < 0.5) return;
    _syncingHorizontalScroll = true;
    target.jumpTo(nextOffset);
    _syncingHorizontalScroll = false;
  }

  void _maybeLoadMore() {
    if (!mounted ||
        widget.onLoadMore == null ||
        !widget.pageScrollController.hasClients) {
      return;
    }
    final position = widget.pageScrollController.position;
    if (position.extentAfter >= _loadMoreExtent ||
        _loadMoreQueued ||
        _loadRequestPending ||
        widget.isLoadingMore) {
      return;
    }
    _loadMoreQueued = true;
    setState(() => _loadRequestPending = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreQueued = false;
      if (!mounted) return;
      widget.onLoadMore?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: _horizontalViewportKey,
      controller: _bodyHorizontalController,
      scrollDirection: Axis.horizontal,
      primary: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(key: _tableAnchorKey, child: widget.child),
          if (widget.isLoadingMore || _loadRequestPending)
            const PendingLoadMoreFooter(),
        ],
      ),
    );
  }
}

class TableLoadingMoreIndicator extends StatelessWidget {
  const TableLoadingMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Laster flere resultater',
      liveRegion: true,
      child: DecoratedBox(
        key: const ValueKey('results-loading-more-indicator'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.surface.withValues(alpha: 0),
              colors.surface.withValues(alpha: 0.94),
              colors.surface,
            ],
            stops: const [0, 0.28, 1],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3.2,
                  strokeCap: StrokeCap.round,
                  color: colors.primary,
                  backgroundColor: colors.primary.withValues(alpha: 0.16),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Laster flere resultater',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PendingLoadMoreFooter extends StatelessWidget {
  const PendingLoadMoreFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 132,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 30, 18, 54),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Laster flere resultater',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultsLoadMoreScrollView extends StatefulWidget {
  const ResultsLoadMoreScrollView({
    super.key,
    required this.child,
    required this.itemCount,
    required this.isLoadingMore,
    this.onLoadMore,
  });

  final Widget child;
  final int itemCount;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  @override
  State<ResultsLoadMoreScrollView> createState() =>
      _ResultsLoadMoreScrollViewState();
}

class _ResultsLoadMoreScrollViewState extends State<ResultsLoadMoreScrollView> {
  static const _loadMoreExtent = 220.0;

  final _controller = ScrollController();
  bool _loadMoreQueued = false;
  bool _loadRequestPending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void didUpdateWidget(covariant ResultsLoadMoreScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final receivedMoreItems = widget.itemCount > oldWidget.itemCount;
    final loadFinished = oldWidget.isLoadingMore && !widget.isLoadingMore;
    if (receivedMoreItems || loadFinished) {
      _loadRequestPending = false;
    }
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
    if (!nearBottom ||
        _loadMoreQueued ||
        _loadRequestPending ||
        widget.isLoadingMore) {
      return;
    }

    _loadMoreQueued = true;
    setState(() => _loadRequestPending = true);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.child,
          if (_loadRequestPending && !widget.isLoadingMore)
            const PendingLoadMoreFooter(),
        ],
      ),
    );
  }
}

class ResultAffiliationHeader extends StatelessWidget {
  const ResultAffiliationHeader({
    super.key,
    required this.view,
    required this.clubLabel,
    required this.teamLabel,
    required this.onToggle,
  });

  final ResultAffiliationView view;
  final String clubLabel;
  final String teamLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = view == ResultAffiliationView.club ? clubLabel : teamLabel;
    final tooltip = view == ResultAffiliationView.club
        ? 'Vis team'
        : 'Vis klubb';
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              const Icon(Icons.swap_horiz, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({
    required this.row,
    required this.width,
    this.compact = false,
    this.showBib = true,
  });

  final ResultTableRow row;
  final double width;
  final bool compact;
  final bool showBib;

  @override
  Widget build(BuildContext context) {
    final result = row.result;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          if (showBib) ...[
            SizedBox(
              width: compact ? 38 : 52,
              child: _MonoText(result.bib.isEmpty ? '-' : result.bib),
            ),
            SizedBox(width: compact ? 4 : 8),
          ],
          Container(
            width: compact ? 5 : 8,
            height: compact ? 26 : 32,
            decoration: BoxDecoration(
              color: row.color ?? Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
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

class AdvancementBadge extends StatelessWidget {
  const AdvancementBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Kvalifisert videre',
      child: Semantics(
        label: 'Kvalifisert videre',
        child: Container(
          key: const Key('advancement-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Q',
            style: TextStyle(
              color: colors.onTertiaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
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
    this.sourceClassId,
    this.highlight = ResultRowHighlight.none,
    this.isCurrentAthlete = false,
  });

  final RaceResult result;
  final String classId;
  final String className;
  final String? sourceClassId;
  final Color? color;
  final String originalPlacementLabel;
  final ResultRowHighlight highlight;
  final bool isCurrentAthlete;

  ResultTableRow copyWith({String? originalPlacementLabel}) {
    return ResultTableRow(
      result: result,
      classId: classId,
      className: className,
      sourceClassId: sourceClassId,
      color: color,
      originalPlacementLabel:
          originalPlacementLabel ?? this.originalPlacementLabel,
      highlight: highlight,
      isCurrentAthlete: isCurrentAthlete,
    );
  }
}

enum ResultRowHighlight { none, self, affiliationMate, favorite }

ResultRowHighlight resultHighlightFor(
  RaceResult result, {
  required String? linkedAthleteId,
  required String? linkedClubName,
  required String? linkedTeamName,
  Set<String> favoriteAthleteIds = const <String>{},
}) {
  final athleteId = result.athleteId?.trim();
  if (athleteId != null &&
      athleteId.isNotEmpty &&
      favoriteAthleteIds.contains(athleteId)) {
    return ResultRowHighlight.favorite;
  }
  final currentAthleteId = linkedAthleteId?.trim();
  if (athleteId != null &&
      athleteId.isNotEmpty &&
      currentAthleteId != null &&
      athleteId == currentAthleteId) {
    return ResultRowHighlight.self;
  }

  final resultClub = _normalizedAffiliation(result.club);
  final currentClub = _normalizedAffiliation(linkedClubName);
  final resultTeam = _normalizedAffiliation(result.team);
  final currentTeam = _normalizedAffiliation(linkedTeamName);
  if ((resultClub != null && resultClub == currentClub) ||
      (resultTeam != null && resultTeam == currentTeam)) {
    return ResultRowHighlight.affiliationMate;
  }
  return ResultRowHighlight.none;
}

String? _normalizedAffiliation(String? value) {
  final normalized = value
      ?.trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
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
