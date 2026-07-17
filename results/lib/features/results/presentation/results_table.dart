import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../app/app_theme.dart';
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
  final ValueChanged<ResultTableRow> onAthleteTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
    final rowHeight = tableDensity == TableDensity.compact ? 42.0 : 54.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      primary: false,
      child: ResultsLoadMoreScrollView(
        onLoadMore: onLoadMore,
        isLoadingMore: isLoadingMore,
        itemCount: rows.length,
        child: RepaintBoundary(
          child: DataTable(
            showCheckboxColumn: false,
            sortColumnIndex: _sortColumnIndex(
              effectiveSortMode,
              hasShootingData: hasShootingData,
            ),
            sortAscending: true,
            headingRowHeight: 42,
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight + 8,
            horizontalMargin: 8,
            columnSpacing: 26,
            columns: [
              DataColumn(label: Text(l10n.place.toUpperCase())),
              DataColumn(label: Text(l10n.athlete.toUpperCase())),
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
              DataColumn(
                label: SortableTableHeader(label: l10n.split.toUpperCase()),
                onSort: (columnIndex, ascending) {
                  onSortModeChanged(ResultSortMode.split);
                },
              ),
              DataColumn(
                label: splitRange?.isIndependent == true
                    ? Text(l10n.time.toUpperCase())
                    : SortableTableHeader(label: l10n.time.toUpperCase()),
                numeric: true,
                onSort: splitRange?.isIndependent == true
                    ? null
                    : (columnIndex, ascending) {
                        onSortModeChanged(ResultSortMode.cumulative);
                      },
              ),
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
                  ),
                ),
            ],
          ),
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
    ResultTableRow row,
    List<ResultTableRow> sortedRows,
    String? selectedSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
    int? winnerMs,
    int index,
    ResultAffiliationView affiliationView,
    bool hasShootingData,
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
    return [
      DataCell(_MonoText(placement)),
      DataCell(_NameCell(row: row)),
      DataCell(Text(_affiliationText(result, affiliationView))),
      if (hasShootingData)
        DataCell(_MonoText(_shootingText(result, selectedSplitId, splitRange))),
      DataCell(
        _MonoText(
          _splitText(result, selectedSplitId, splitRange),
          alignEnd: true,
        ),
      ),
      DataCell(
        _MonoText(
          _timeText(result, selectedSplitId, splitRange),
          alignEnd: true,
        ),
      ),
      DataCell(
        _MonoText(
          _gapText(result, selectedSplitId, splitRange, sortMode, winnerMs),
          alignEnd: true,
        ),
      ),
    ];
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
  }) {
    final shootingOffset = hasShootingData ? 1 : 0;
    return switch (sortMode) {
      ResultSortMode.split => 3 + shootingOffset,
      ResultSortMode.cumulative => 4 + shootingOffset,
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
    final palette = context.palette;
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
          style: TextStyle(
            color: _hovering ? palette.primary : null,
            fontWeight: FontWeight.w800,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class TableLoadMoreFooter extends StatelessWidget {
  const TableLoadMoreFooter({super.key, required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: isLoading
          ? const TableLoadingMoreIndicator()
          : const SizedBox.shrink(),
    );
  }
}

class TableLoadingMoreIndicator extends StatelessWidget {
  const TableLoadingMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Laster flere resultater',
      liveRegion: true,
      child: const SizedBox(
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
          TableLoadMoreFooter(
            isLoading: widget.isLoadingMore || _loadRequestPending,
          ),
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
