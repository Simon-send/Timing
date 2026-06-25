import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/presentation/account_menu.dart';
import '../../events/domain/result_event.dart';
import '../../settings/presentation/settings_menu.dart';
import '../domain/race_result.dart';
import '../domain/result_class.dart';
import '../domain/result_sort_mode.dart';
import '../domain/split_def.dart';
import 'biathlon_table.dart';
import 'class_selector.dart';
import 'result_locations.dart';
import 'result_distribution_button.dart';
import 'results_table.dart';
import 'split_selector.dart';

const _biathlonSplitId = '__biathlon_analysis__';

class ResultsPage extends ConsumerWidget {
  const ResultsPage({
    super.key,
    required this.eventId,
    this.selectedClassId,
    this.selectedSplitId,
    this.compareBaseClassId,
    this.compareBaseResultId,
  });

  final String eventId;
  final String? selectedClassId;
  final String? selectedSplitId;
  final String? compareBaseClassId;
  final String? compareBaseResultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(eventsProvider);
    final classes = ref.watch(classesProvider(eventId));

    return AppShell(
      title: l10n.results,
      subtitle: eventId,
      leading: IconButton.outlined(
        tooltip: l10n.eventsTitle,
        onPressed: () => context.go('/events'),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: const [AccountMenu(), SettingsMenu()],
      child: ShellPanel(
        child: events.when(
          loading: () => LoadingState(label: l10n.loadingEvents),
          error: (error, _) =>
              ErrorState(title: l10n.couldNotReadEvents, error: error),
          data: (events) {
            final event = events
                .where((event) => event.id == eventId)
                .firstOrNull;
            return classes.when(
              loading: () => LoadingState(label: l10n.loadingResults),
              error: (error, _) =>
                  ErrorState(title: l10n.couldNotReadResults, error: error),
              data: (classes) {
                if (classes.isEmpty) {
                  return EmptyState(
                    title: l10n.noClassesTitle,
                    message: l10n.noClassesMessage,
                  );
                }
                return _ResultsContent(
                  eventId: eventId,
                  event: event,
                  classes: classes,
                  selectedClassId: selectedClassId,
                  selectedSplitId: selectedSplitId,
                  compareBaseClassId: compareBaseClassId,
                  compareBaseResultId: compareBaseResultId,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ResultsContent extends ConsumerWidget {
  const _ResultsContent({
    required this.eventId,
    required this.event,
    required this.classes,
    required this.selectedClassId,
    required this.selectedSplitId,
    required this.compareBaseClassId,
    required this.compareBaseResultId,
  });

  final String eventId;
  final ResultEvent? event;
  final List<ResultClass> classes;
  final String? selectedClassId;
  final String? selectedSplitId;
  final String? compareBaseClassId;
  final String? compareBaseResultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final compareSelection = _CompareSelection.tryParse(
      classId: compareBaseClassId,
      resultId: compareBaseResultId,
    );
    final activeClass = _activeClass(
      compareSelection?.classId ?? selectedClassId ?? settings.defaultClassId,
    );
    final classId = activeClass.id;
    final splitDefs = ref.watch(
      splitDefsProvider((eventId: eventId, classId: classId)),
    );
    final results = ref.watch(
      raceResultsProvider((eventId: eventId, classId: classId)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final showClassSidebar = constraints.maxWidth >= 880;
        final resultsArea = _ResultsArea(
          eventId: eventId,
          event: event,
          activeClass: activeClass,
          classes: classes,
          showClassDropdown: !showClassSidebar,
          splitDefs: splitDefs,
          results: results,
          selectedSplitId: selectedSplitId,
          compareSelection: compareSelection,
        );

        if (!showClassSidebar) return resultsArea;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: _ClassSidebar(
                eventId: eventId,
                classes: classes,
                selectedClassId: classId,
                activeSplitDefs: splitDefs,
                onChanged: (value) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .setDefaultClass(value);
                  ref.read(splitRangeSelectionProvider.notifier).state = null;
                  ref.read(comparisonClassIdsProvider.notifier).state = [];
                  context.go(
                    resultsLocation(
                      eventId: eventId,
                      classId: value,
                      splitId: selectedSplitId ?? settings.preferredSplitId,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: resultsArea),
          ],
        );
      },
    );
  }

  ResultClass _activeClass(String? preferredClassId) {
    for (final raceClass in classes) {
      if (raceClass.id == preferredClassId) return raceClass;
    }
    final withResults = classes.where((raceClass) => raceClass.resultCount > 0);
    return withResults.isNotEmpty ? withResults.first : classes.first;
  }
}

class _ResultsArea extends ConsumerWidget {
  const _ResultsArea({
    required this.eventId,
    required this.event,
    required this.activeClass,
    required this.classes,
    required this.showClassDropdown,
    required this.splitDefs,
    required this.results,
    required this.selectedSplitId,
    required this.compareSelection,
  });

  final String eventId;
  final ResultEvent? event;
  final ResultClass activeClass;
  final List<ResultClass> classes;
  final bool showClassDropdown;
  final AsyncValue<List<SplitDef>> splitDefs;
  final AsyncValue<List<RaceResult>> results;
  final String? selectedSplitId;
  final _CompareSelection? compareSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final sortMode = ref.watch(resultSortModeProvider);
    final biathlonSortKey = ref.watch(biathlonSortKeyProvider);
    final comparisonClassIds = compareSelection == null
        ? ref.watch(comparisonClassIdsProvider)
        : <String>[];
    final requestedSplitRange = ref.watch(splitRangeSelectionProvider);
    final classId = activeClass.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultTitle(event: event, raceClass: activeClass),
        if (showClassDropdown) ...[
          const SizedBox(height: 14),
          ClassSelector(
            classes: classes,
            selectedClassId: classId,
            onChanged: (value) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setDefaultClass(value);
              ref.read(splitRangeSelectionProvider.notifier).state = null;
              context.go(
                resultsLocation(
                  eventId: eventId,
                  classId: value,
                  splitId: selectedSplitId ?? settings.preferredSplitId,
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: splitDefs.when(
            loading: () => LoadingState(label: l10n.loadingResults),
            error: (error, _) =>
                ErrorState(title: l10n.couldNotReadResults, error: error),
            data: (splitDefs) {
              return results.when(
                skipLoadingOnReload: true,
                skipError: true,
                loading: () => LoadingState(label: l10n.loadingResults),
                error: (error, _) =>
                    ErrorState(title: l10n.couldNotReadResults, error: error),
                data: (loadedResults) {
                  if (loadedResults.isEmpty) {
                    return EmptyState(
                      title: l10n.noResultsTitle,
                      message: l10n.noResultsMessage,
                    );
                  }
                  final comparisonRead = _readComparisonData(
                    ref,
                    splitDefs,
                    comparisonClassIds,
                  );
                  if (comparisonRead.isLoading && comparisonRead.rows.isEmpty) {
                    return LoadingState(label: l10n.loadingResults);
                  }
                  if (comparisonRead.error != null) {
                    return ErrorState(
                      title: l10n.couldNotReadResults,
                      error: comparisonRead.error!,
                    );
                  }
                  final isLoadingMore =
                      (results.isLoading && results.hasValue) ||
                      comparisonRead.isLoading;
                  final tableRows = _buildTableRows(
                    primaryResults: loadedResults,
                    comparisons: comparisonRead.rows,
                  );
                  final baseRow = compareSelection == null
                      ? null
                      : tableRows.where((row) {
                          return row.classId == compareSelection!.classId &&
                              row.result.id == compareSelection!.resultId;
                        }).firstOrNull;
                  final hasBiathlonData = BiathlonTable.hasBiathlonData(
                    tableRows,
                  );
                  final splitOptions = _splitOptions(
                    splitDefs,
                    loadedResults,
                    hasBiathlonData,
                  );
                  final activeSplitId = _activeSplitId(
                    selectedSplitId ?? settings.preferredSplitId,
                    splitOptions,
                  );
                  final isBiathlonSplit = activeSplitId == _biathlonSplitId;
                  final rangeSplitOptions = splitOptions
                      .where((split) => split.id != _biathlonSplitId)
                      .toList();
                  final activeSplitRange = isBiathlonSplit
                      ? null
                      : _activeSplitRange(
                          requestedSplitRange,
                          activeSplitId,
                          rangeSplitOptions,
                        );
                  final selectedResultSplitId =
                      activeSplitRange?.toSplitId ?? activeSplitId;
                  final distributionData = _distributionData(
                    tableRows: tableRows,
                    isBiathlonSplit: isBiathlonSplit,
                    activeSplitId: selectedResultSplitId,
                    splitRange: activeSplitRange,
                    sortMode: sortMode,
                    biathlonSortKey: biathlonSortKey,
                  );
                  Future<ResultDistributionData?> loadFullDistributionData() {
                    return _loadFullDistributionData(
                      ref: ref,
                      primarySplitDefs: splitDefs,
                      comparisonClassIds: comparisonClassIds,
                      isBiathlonSplit: isBiathlonSplit,
                      activeSplitId: selectedResultSplitId,
                      splitRange: activeSplitRange,
                      sortMode: sortMode,
                      biathlonSortKey: biathlonSortKey,
                    );
                  }

                  void loadMoreResults() {
                    _loadMoreResults(
                      ref,
                      primaryResults: loadedResults,
                      comparisons: comparisonRead.rows,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (compareSelection != null) ...[
                        _CompareSelectionBanner(
                          baseName: baseRow?.result.name ?? 'Valgt utover',
                          onCancel: () => context.go(
                            resultsLocation(
                              eventId: eventId,
                              classId: classId,
                              splitId: selectedResultSplitId,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _SplitAndInfoRow(
                        event: event,
                        raceClass: activeClass,
                        resultCount: activeClass.resultCount > 0
                            ? activeClass.resultCount
                            : tableRows.length,
                        splitOptions: splitOptions,
                        rangeSplitOptions: rangeSplitOptions,
                        selectedSplitId: selectedResultSplitId,
                        splitRange: activeSplitRange,
                        distributionData: distributionData,
                        loadFullDistributionData: loadFullDistributionData,
                        onSplitChanged: (value) {
                          ref.read(splitRangeSelectionProvider.notifier).state =
                              null;
                          ref
                              .read(settingsControllerProvider.notifier)
                              .setPreferredSplit(value);
                          context.go(
                            resultsLocation(
                              eventId: eventId,
                              classId: classId,
                              splitId: value,
                              compareBaseClassId: compareSelection?.classId,
                              compareBaseResultId: compareSelection?.resultId,
                            ),
                          );
                        },
                        onRangeToggle: () {
                          final rangeNotifier = ref.read(
                            splitRangeSelectionProvider.notifier,
                          );
                          if (activeSplitRange != null) {
                            rangeNotifier.state = null;
                            return;
                          }
                          final range = _initialSplitRange(
                            activeSplitId,
                            rangeSplitOptions,
                          );
                          if (range != null) rangeNotifier.state = range;
                        },
                        onRangeFromChanged: (value) {
                          final current = activeSplitRange;
                          if (current == null) return;
                          ref
                              .read(splitRangeSelectionProvider.notifier)
                              .state = _normalizeSplitRange(
                            current.copyWith(
                              fromSplitId: value,
                              clearFromSplitId: value == null,
                            ),
                            rangeSplitOptions,
                          );
                        },
                        onRangeToChanged: (value) {
                          if (value == null) return;
                          final current = activeSplitRange;
                          if (current == null) return;
                          final next = _normalizeSplitRange(
                            current.copyWith(toSplitId: value),
                            rangeSplitOptions,
                          );
                          ref.read(splitRangeSelectionProvider.notifier).state =
                              next;
                          ref
                              .read(settingsControllerProvider.notifier)
                              .setPreferredSplit(next?.toSplitId);
                          context.go(
                            resultsLocation(
                              eventId: eventId,
                              classId: classId,
                              splitId: next?.toSplitId,
                              compareBaseClassId: compareSelection?.classId,
                              compareBaseResultId: compareSelection?.resultId,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: isBiathlonSplit
                            ? BiathlonTable(
                                rows: tableRows,
                                sortKey: biathlonSortKey,
                                onSortKeyChanged: (value) {
                                  ref
                                          .read(
                                            biathlonSortKeyProvider.notifier,
                                          )
                                          .state =
                                      value;
                                },
                                tableDensity: settings.tableDensity,
                                disabledResultId: compareSelection?.resultId,
                                onLoadMore: loadMoreResults,
                                isLoadingMore: isLoadingMore,
                                onAthleteTap: (row) {
                                  _openAthlete(
                                    context,
                                    row,
                                    compareSelection,
                                    splitId: selectedResultSplitId,
                                  );
                                },
                              )
                            : ResultsTable(
                                rows: tableRows,
                                selectedSplitId: selectedResultSplitId,
                                splitRange: activeSplitRange,
                                sortMode: sortMode,
                                onSortModeChanged: (value) {
                                  ref
                                          .read(resultSortModeProvider.notifier)
                                          .state =
                                      value;
                                },
                                tableDensity: settings.tableDensity,
                                disabledResultId: compareSelection?.resultId,
                                onLoadMore: loadMoreResults,
                                isLoadingMore: isLoadingMore,
                                onAthleteTap: (row) {
                                  _openAthlete(
                                    context,
                                    row,
                                    compareSelection,
                                    splitId: selectedResultSplitId,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openAthlete(
    BuildContext context,
    ResultTableRow row,
    _CompareSelection? compareSelection, {
    required String? splitId,
  }) {
    if (compareSelection == null) {
      context.go(
        athleteLocation(
          eventId: eventId,
          classId: row.classId,
          resultId: row.result.id,
          splitId: splitId,
        ),
      );
      return;
    }
    context.go(
      athleteLocation(
        eventId: eventId,
        classId: compareSelection.classId,
        resultId: compareSelection.resultId,
        splitId: splitId,
        compareWithResultId: row.result.id,
      ),
    );
  }

  List<SplitOption> _splitOptions(
    List<SplitDef> splitDefs,
    List<RaceResult> results,
    bool hasBiathlonData,
  ) {
    final options = buildSplitOptions(splitDefs, results);
    if (!hasBiathlonData) return options;
    return [
      ...options,
      const SplitOption(
        id: _biathlonSplitId,
        label: 'Skiskytinganalyse',
        sort: 1000000,
      ),
    ];
  }

  String? _activeSplitId(String? preferredSplitId, List<SplitOption> options) {
    if (options.isEmpty) return null;
    for (final split in options) {
      if (split.id == preferredSplitId) return split.id;
    }
    for (final split in options.reversed) {
      if (split.id != _biathlonSplitId) return split.id;
    }
    return options.last.id;
  }

  SplitRangeSelection? _activeSplitRange(
    SplitRangeSelection? requested,
    String? activeSplitId,
    List<SplitOption> splitOptions,
  ) {
    if (requested == null || activeSplitId == null || splitOptions.isEmpty) {
      return null;
    }
    final requestedExists = splitOptions.any(
      (split) => split.id == requested.toSplitId,
    );
    final normalizedRequest = requestedExists
        ? requested
        : requested.copyWith(toSplitId: activeSplitId);
    return _normalizeSplitRange(normalizedRequest, splitOptions);
  }

  SplitRangeSelection? _initialSplitRange(
    String? activeSplitId,
    List<SplitOption> splitOptions,
  ) {
    if (activeSplitId == null || splitOptions.isEmpty) return null;
    final toIndex = splitOptions.indexWhere(
      (split) => split.id == activeSplitId,
    );
    if (toIndex < 0) return null;
    return _normalizeSplitRange(
      SplitRangeSelection(
        fromSplitId: toIndex > 0 ? splitOptions[toIndex - 1].id : null,
        toSplitId: activeSplitId,
      ),
      splitOptions,
    );
  }

  SplitRangeSelection? _normalizeSplitRange(
    SplitRangeSelection range,
    List<SplitOption> splitOptions,
  ) {
    if (splitOptions.isEmpty) return null;
    final toIndex = splitOptions.indexWhere(
      (split) => split.id == range.toSplitId,
    );
    if (toIndex < 0) return null;

    final requestedFromId = range.fromSplitId;
    var fromIndex = requestedFromId == null
        ? -1
        : splitOptions.indexWhere((split) => split.id == requestedFromId);
    if (fromIndex >= toIndex) {
      fromIndex = toIndex - 1;
    }
    if (fromIndex < -1) {
      fromIndex = -1;
    }

    final includedSplitIds = splitOptions
        .skip(fromIndex + 1)
        .take(toIndex - fromIndex)
        .map((split) => split.id)
        .toList();
    return SplitRangeSelection(
      fromSplitId: fromIndex >= 0 ? splitOptions[fromIndex].id : null,
      toSplitId: splitOptions[toIndex].id,
      includedSplitIds: includedSplitIds,
    );
  }

  ResultDistributionData? _distributionData({
    required List<ResultTableRow> tableRows,
    required bool isBiathlonSplit,
    required String? activeSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
    required String biathlonSortKey,
  }) {
    if (isBiathlonSplit) {
      return _biathlonDistributionData(tableRows, biathlonSortKey);
    }

    final valueLabel = _resultValueLabel(
      activeSplitId: activeSplitId,
      splitRange: splitRange,
      sortMode: sortMode,
    );
    final values = tableRows
        .where((row) => row.result.isFinished)
        .map((row) {
          return _resultSortValue(
            row.result,
            activeSplitId,
            splitRange,
            sortMode,
          );
        })
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    return ResultDistributionData(
      title: 'Fordeling: $valueLabel',
      values: values,
      formatValue: formatDurationMs,
      regression: _resultRegressionData(
        tableRows: tableRows,
        activeSplitId: activeSplitId,
        splitRange: splitRange,
        sortMode: sortMode,
        valueLabel: valueLabel,
      ),
    );
  }

  ResultDistributionData _biathlonDistributionData(
    List<ResultTableRow> tableRows,
    String preferredSortKey,
  ) {
    final metrics = _biathlonMetrics(tableRows);
    final selected = metrics.firstWhere(
      (metric) => metric.key == preferredSortKey,
      orElse: () => metrics.first,
    );
    return ResultDistributionData(
      title: 'Fordeling: ${selected.label}',
      values: selected.values,
      formatValue: selected.isTime ? formatDurationMs : (value) => '$value',
      regression: _biathlonRegressionData(tableRows, selected),
    );
  }

  ResultRegressionData? _biathlonRegressionData(
    List<ResultTableRow> tableRows,
    _DistributionMetric metric,
  ) {
    final points = <ResultRegressionPoint>[];
    for (final row in tableRows) {
      final totalMs = row.result.totalMs;
      if (!row.result.isFinished || totalMs == null || totalMs <= 0) {
        continue;
      }
      final value = _biathlonMetricValue(row.result.biathlon, metric.key);
      if (value == null || value < 0 || (metric.isTime && value <= 0)) {
        continue;
      }
      points.add(
        ResultRegressionPoint(
          x: totalMs,
          y: value,
          label: row.result.name,
          color: row.color,
        ),
      );
    }

    if (points.length < 2) return null;
    return ResultRegressionData(
      title: 'Regresjon: ${metric.label} mot sluttid',
      subjectLabel: metric.label,
      xLabel: 'Sluttid',
      yLabel: metric.label,
      points: points,
      formatX: formatDurationMs,
      formatY: metric.isTime ? formatDurationMs : (value) => '$value',
    );
  }

  List<_DistributionMetric> _biathlonMetrics(List<ResultTableRow> tableRows) {
    final metrics = <_DistributionMetric>[];

    void addMetric({
      required String key,
      required String label,
      required bool isTime,
      required int? Function(BiathlonAnalysis analysis) read,
    }) {
      final values = tableRows
          .where((row) => row.result.isFinished)
          .map((row) => read(row.result.biathlon))
          .whereType<int>()
          .where((value) => isTime ? value > 0 : value >= 0)
          .toList();
      if (values.isEmpty) return;
      metrics.add(
        _DistributionMetric(
          key: key,
          label: label,
          values: values,
          isTime: isTime,
        ),
      );
    }

    addMetric(
      key: 'ski',
      label: 'Skitid',
      isTime: true,
      read: (analysis) => analysis.netSkiTimeMs,
    );
    addMetric(
      key: 'shooting',
      label: 'Skytetid',
      isTime: true,
      read: (analysis) => analysis.shootingTimeMs,
    );
    addMetric(
      key: 'penalty',
      label: 'Straff',
      isTime: true,
      read: (analysis) => analysis.penaltyTimeMs,
    );
    addMetric(
      key: 'misses',
      label: 'Bom',
      isTime: false,
      read: (analysis) => analysis.missesTotal,
    );

    final rangeIndexes = <int>{};
    for (final row in tableRows) {
      rangeIndexes.addAll(
        row.result.biathlon.passes
            .where((pass) => pass.rangeMs != null)
            .map((pass) => pass.index),
      );
    }
    final sortedRangeIndexes = rangeIndexes.toList()..sort();
    for (final index in sortedRangeIndexes) {
      addMetric(
        key: 'range:$index',
        label: 'S$index',
        isTime: true,
        read: (analysis) => analysis.passAt(index)?.rangeMs,
      );
    }

    return metrics.isEmpty
        ? [
            const _DistributionMetric(
              key: 'empty',
              label: 'Skiskytinganalyse',
              values: [],
              isTime: true,
            ),
          ]
        : metrics;
  }

  int? _biathlonMetricValue(BiathlonAnalysis analysis, String key) {
    if (key == 'ski') return analysis.netSkiTimeMs;
    if (key == 'shooting') return analysis.shootingTimeMs;
    if (key == 'penalty') return analysis.penaltyTimeMs;
    if (key == 'misses') return analysis.missesTotal;
    if (key.startsWith('range:')) {
      final index = int.tryParse(key.substring('range:'.length));
      if (index == null) return null;
      return analysis.passAt(index)?.rangeMs;
    }
    return analysis.netSkiTimeMs;
  }

  String _resultValueLabel({
    required String? activeSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
  }) {
    if (sortMode == ResultSortMode.split) {
      return splitRange == null ? 'Splittid' : 'Intervalltid';
    }
    return activeSplitId == null ? 'Sluttid' : 'Rangert tid';
  }

  ResultRegressionData? _resultRegressionData({
    required List<ResultTableRow> tableRows,
    required String? activeSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
    required String valueLabel,
  }) {
    final rankedTimeOnYAxis = sortMode == ResultSortMode.split;
    final points = <ResultRegressionPoint>[];

    for (final row in tableRows) {
      final totalMs = row.result.totalMs;
      if (!row.result.isFinished || totalMs == null || totalMs <= 0) {
        continue;
      }
      final rankedMs = _resultSortValue(
        row.result,
        activeSplitId,
        splitRange,
        sortMode,
      );
      if (rankedMs == null || rankedMs <= 0) continue;

      points.add(
        ResultRegressionPoint(
          x: rankedTimeOnYAxis ? totalMs : rankedMs,
          y: rankedTimeOnYAxis ? rankedMs : totalMs,
          label: row.result.name,
          color: row.color,
        ),
      );
    }

    if (points.length < 2) return null;
    return ResultRegressionData(
      title: 'Regresjon: $valueLabel mot sluttid',
      subjectLabel: valueLabel,
      xLabel: rankedTimeOnYAxis ? 'Sluttid' : valueLabel,
      yLabel: rankedTimeOnYAxis ? valueLabel : 'Sluttid',
      points: points,
      formatX: formatDurationMs,
      formatY: formatDurationMs,
    );
  }

  int? _resultSortValue(
    RaceResult result,
    String? activeSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
  ) {
    if (sortMode == ResultSortMode.split && splitRange != null) {
      final toMs = result.splitValues[splitRange.toSplitId]?.cumMs;
      if (toMs == null) return null;
      final fromSplitId = splitRange.fromSplitId;
      if (fromSplitId == null) return toMs;
      final fromMs = result.splitValues[fromSplitId]?.cumMs;
      if (fromMs == null) return null;
      final delta = toMs - fromMs;
      return delta >= 0 ? delta : null;
    }
    if (activeSplitId == null) return result.totalMs;
    final split = result.splitValues[activeSplitId];
    return switch (sortMode) {
      ResultSortMode.cumulative => split?.cumMs,
      ResultSortMode.split => split?.legMs,
    };
  }

  void _loadMoreResults(
    WidgetRef ref, {
    required List<RaceResult> primaryResults,
    required List<_ComparisonRows> comparisons,
  }) {
    _loadMoreClassResults(ref, activeClass, primaryResults.length);
    for (final comparison in comparisons) {
      _loadMoreClassResults(
        ref,
        comparison.raceClass,
        comparison.results.length,
      );
    }
  }

  void _loadMoreClassResults(
    WidgetRef ref,
    ResultClass raceClass,
    int loadedCount,
  ) {
    final args = (eventId: eventId, classId: raceClass.id);
    final currentLimit = ref.read(raceResultsLimitProvider(args));
    if (loadedCount < currentLimit) return;
    if (raceClass.resultCount > 0 && loadedCount >= raceClass.resultCount) {
      return;
    }
    ref.read(raceResultsLimitProvider(args).notifier).state =
        currentLimit + raceResultsPageSize;
  }

  Future<ResultDistributionData?> _loadFullDistributionData({
    required WidgetRef ref,
    required List<SplitDef> primarySplitDefs,
    required List<String> comparisonClassIds,
    required bool isBiathlonSplit,
    required String? activeSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
    required String biathlonSortKey,
  }) async {
    final repository = ref.read(resultsRepositoryProvider);
    final primaryResults = await repository.fetchResults(
      eventId,
      activeClass.id,
    );
    final comparisons = await _fetchFullComparisonData(
      ref,
      primarySplitDefs,
      comparisonClassIds,
    );
    final tableRows = _buildTableRows(
      primaryResults: primaryResults,
      comparisons: comparisons,
    );
    if (tableRows.isEmpty) return null;
    if (isBiathlonSplit && !BiathlonTable.hasBiathlonData(tableRows)) {
      return null;
    }
    return _distributionData(
      tableRows: tableRows,
      isBiathlonSplit: isBiathlonSplit,
      activeSplitId: activeSplitId,
      splitRange: splitRange,
      sortMode: sortMode,
      biathlonSortKey: biathlonSortKey,
    );
  }

  Future<List<_ComparisonRows>> _fetchFullComparisonData(
    WidgetRef ref,
    List<SplitDef> primarySplitDefs,
    List<String> comparisonClassIds,
  ) async {
    final primarySignature = _splitSignature(primarySplitDefs);
    final classesById = {
      for (final raceClass in classes) raceClass.id: raceClass,
    };
    final repository = ref.read(resultsRepositoryProvider);
    final reads = [
      for (final classId in comparisonClassIds)
        if (classesById[classId] != null && classId != activeClass.id)
          () async {
            final raceClass = classesById[classId]!;
            final splitDefs = await ref.read(
              splitDefsProvider((
                eventId: eventId,
                classId: raceClass.id,
              )).future,
            );
            if (_splitSignature(splitDefs) != primarySignature) return null;
            final results = await repository.fetchResults(
              eventId,
              raceClass.id,
            );
            return _ComparisonRows(raceClass: raceClass, results: results);
          }(),
    ];
    return (await Future.wait(reads)).whereType<_ComparisonRows>().toList();
  }

  _ComparisonRead _readComparisonData(
    WidgetRef ref,
    List<SplitDef> primarySplitDefs,
    List<String> comparisonClassIds,
  ) {
    final primarySignature = _splitSignature(primarySplitDefs);
    final comparisons = <_ComparisonRows>[];
    var isLoading = false;
    final classesById = {
      for (final raceClass in classes) raceClass.id: raceClass,
    };

    for (final classId in comparisonClassIds) {
      final raceClass = classesById[classId];
      if (raceClass == null) continue;
      if (raceClass.id == activeClass.id) continue;

      final splitDefs = ref.watch(
        splitDefsProvider((eventId: eventId, classId: raceClass.id)),
      );
      final splitDefData = splitDefs.value;
      if (splitDefs.isLoading && splitDefData == null) {
        return const _ComparisonRead.loading();
      }
      if (splitDefs.hasError && splitDefData == null) {
        return _ComparisonRead.error(splitDefs.error!);
      }
      if (splitDefs.isLoading) isLoading = true;
      if (splitDefData == null ||
          _splitSignature(splitDefData) != primarySignature) {
        continue;
      }

      final results = ref.watch(
        raceResultsProvider((eventId: eventId, classId: raceClass.id)),
      );
      final resultData = results.value;
      if (results.isLoading && resultData == null) {
        return const _ComparisonRead.loading();
      }
      if (results.hasError && resultData == null) {
        return _ComparisonRead.error(results.error!);
      }
      if (results.isLoading) isLoading = true;
      comparisons.add(
        _ComparisonRows(raceClass: raceClass, results: resultData ?? const []),
      );
    }

    return _ComparisonRead.data(comparisons, isLoading: isLoading);
  }

  List<ResultTableRow> _buildTableRows({
    required List<RaceResult> primaryResults,
    required List<_ComparisonRows> comparisons,
  }) {
    final hasComparison = comparisons.isNotEmpty;
    final rows = [
      for (final result in primaryResults)
        ResultTableRow(
          result: result,
          classId: activeClass.id,
          className: activeClass.name,
          color: hasComparison ? _classColor(0) : null,
          originalPlacementLabel: '',
        ),
    ];

    for (var i = 0; i < comparisons.length; i++) {
      final comparison = comparisons[i];
      for (final result in comparison.results) {
        rows.add(
          ResultTableRow(
            result: result,
            classId: comparison.raceClass.id,
            className: comparison.raceClass.name,
            color: _classColor(i + 1),
            originalPlacementLabel: '',
          ),
        );
      }
    }

    return _withOriginalPlacements(rows);
  }

  List<ResultTableRow> _withOriginalPlacements(List<ResultTableRow> rows) {
    final rowsByClass = <String, List<ResultTableRow>>{};
    for (final row in rows) {
      rowsByClass.putIfAbsent(row.classId, () => []).add(row);
    }

    final labels = <String, String>{};
    for (final classRows in rowsByClass.values) {
      final finished =
          classRows
              .where(
                (row) => row.result.isFinished && row.result.totalMs != null,
              )
              .toList()
            ..sort((a, b) {
              final timeCompare = a.result.totalMs!.compareTo(
                b.result.totalMs!,
              );
              if (timeCompare != 0) return timeCompare;
              final nameCompare = a.result.name.compareTo(b.result.name);
              if (nameCompare != 0) return nameCompare;
              return a.result.id.compareTo(b.result.id);
            });

      int? previousTime;
      int? previousRank;
      for (var i = 0; i < finished.length; i++) {
        final row = finished[i];
        final time = row.result.totalMs!;
        final calculatedRank = previousTime != null && time == previousTime
            ? previousRank!
            : i + 1;
        final storedRank = row.result.finishRank;
        labels[_rowKey(row)] = storedRank != null && storedRank > 0
            ? '$storedRank'
            : '$calculatedRank';
        previousTime = time;
        previousRank = calculatedRank;
      }

      for (final row in classRows) {
        labels.putIfAbsent(_rowKey(row), () {
          return row.result.isFinished ? '-' : 'DNF';
        });
      }
    }

    return [
      for (final row in rows)
        row.copyWith(
          originalPlacementLabel:
              labels[_rowKey(row)] ?? (row.result.isFinished ? '-' : 'DNF'),
        ),
    ];
  }
}

String _rowKey(ResultTableRow row) => '${row.classId}/${row.result.id}';

class _DistributionMetric {
  const _DistributionMetric({
    required this.key,
    required this.label,
    required this.values,
    required this.isTime,
  });

  final String key;
  final String label;
  final List<int> values;
  final bool isTime;
}

class _CompareSelection {
  const _CompareSelection({required this.classId, required this.resultId});

  static _CompareSelection? tryParse({String? classId, String? resultId}) {
    if (classId == null ||
        classId.trim().isEmpty ||
        resultId == null ||
        resultId.trim().isEmpty) {
      return null;
    }
    return _CompareSelection(classId: classId, resultId: resultId);
  }

  final String classId;
  final String resultId;
}

class _CompareSelectionBanner extends StatelessWidget {
  const _CompareSelectionBanner({
    required this.baseName,
    required this.onCancel,
  });

  final String baseName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.compare_arrows, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Velg motstander for $baseName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.outlined(
            tooltip: 'Avbryt',
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRows {
  const _ComparisonRows({required this.raceClass, required this.results});

  final ResultClass raceClass;
  final List<RaceResult> results;
}

class _ComparisonRead {
  const _ComparisonRead.data(this.rows, {this.isLoading = false})
    : error = null;

  const _ComparisonRead.loading()
    : rows = const [],
      isLoading = true,
      error = null;

  const _ComparisonRead.error(this.error) : rows = const [], isLoading = false;

  final List<_ComparisonRows> rows;
  final bool isLoading;
  final Object? error;
}

String _splitSignature(List<SplitDef> splitDefs) {
  final parts = [...splitDefs]
    ..sort((a, b) {
      if (a.sort != b.sort) return a.sort - b.sort;
      return a.id.compareTo(b.id);
    });
  return parts
      .map((split) => '${split.id}:${split.sort}:${split.kind}:${split.label}')
      .join('|');
}

Color _classColor(int index) {
  const colors = [
    Color(0xFF5CC8B2),
    Color(0xFFF4B45F),
    Color(0xFF8ED8FF),
    Color(0xFFFF8E72),
    Color(0xFFBBA6FF),
    Color(0xFF7EE081),
  ];
  return colors[index % colors.length];
}

class _ClassSidebar extends ConsumerWidget {
  const _ClassSidebar({
    required this.eventId,
    required this.classes,
    required this.selectedClassId,
    required this.activeSplitDefs,
    required this.onChanged,
  });

  final String eventId;
  final List<ResultClass> classes;
  final String selectedClassId;
  final AsyncValue<List<SplitDef>> activeSplitDefs;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final comparisonClassIds = ref.watch(comparisonClassIdsProvider);
    final activeSplitDefData = activeSplitDefs.asData?.value;
    final activeSignature = activeSplitDefData == null
        ? null
        : _splitSignature(activeSplitDefData);
    return Container(
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              l10n.classes,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              itemCount: classes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final raceClass = classes[index];
                final selected = raceClass.id == selectedClassId;
                return _ClassTile(
                  eventId: eventId,
                  raceClass: raceClass,
                  selected: selected,
                  activeSignature: activeSignature,
                  comparisonClassIds: comparisonClassIds,
                  onTap: () => onChanged(raceClass.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassTile extends ConsumerWidget {
  const _ClassTile({
    required this.eventId,
    required this.raceClass,
    required this.selected,
    required this.activeSignature,
    required this.comparisonClassIds,
    required this.onTap,
  });

  final String eventId;
  final ResultClass raceClass;
  final bool selected;
  final String? activeSignature;
  final List<String> comparisonClassIds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final splitDefs = ref.watch(
      splitDefsProvider((eventId: eventId, classId: raceClass.id)),
    );
    final splitDefData = splitDefs.asData?.value;
    final classSignature = splitDefData == null
        ? null
        : _splitSignature(splitDefData);
    final canCompare =
        !selected &&
        activeSignature != null &&
        classSignature != null &&
        classSignature == activeSignature;
    final checked = selected || comparisonClassIds.contains(raceClass.id);
    final comparisonIndex = comparisonClassIds.indexOf(raceClass.id);
    final comparisonActive = comparisonClassIds.isNotEmpty;
    final color = selected
        ? (comparisonActive ? _classColor(0) : null)
        : (comparisonIndex >= 0 ? _classColor(comparisonIndex + 1) : null);
    final tileColor = selected
        ? palette.primary.withValues(alpha: 0.16)
        : canCompare
        ? palette.panel
        : palette.panelAlt.withValues(alpha: 0.52);

    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: selected || !canCompare
                    ? null
                    : (value) {
                        final next = [...comparisonClassIds];
                        if (value ?? false) {
                          if (!next.contains(raceClass.id)) {
                            next.add(raceClass.id);
                          }
                        } else {
                          next.remove(raceClass.id);
                        }
                        ref.read(comparisonClassIdsProvider.notifier).state =
                            next;
                      },
                activeColor: color ?? palette.primary,
              ),
              SizedBox(
                width: 6,
                height: 32,
                child: color == null
                    ? const SizedBox.shrink()
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: canCompare || selected || checked ? 1 : 0.58,
                  child: Text(
                    raceClass.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${raceClass.resultCount}',
                style: TextStyle(
                  color: selected ? palette.primary : palette.mutedText,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTitle extends StatelessWidget {
  const _ResultTitle({required this.event, required this.raceClass});

  final ResultEvent? event;
  final ResultClass raceClass;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          raceClass.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          event?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SplitAndInfoRow extends StatelessWidget {
  const _SplitAndInfoRow({
    required this.event,
    required this.raceClass,
    required this.resultCount,
    required this.splitOptions,
    required this.rangeSplitOptions,
    required this.selectedSplitId,
    required this.splitRange,
    required this.distributionData,
    required this.loadFullDistributionData,
    required this.onSplitChanged,
    required this.onRangeToggle,
    required this.onRangeFromChanged,
    required this.onRangeToChanged,
  });

  final ResultEvent? event;
  final ResultClass raceClass;
  final int resultCount;
  final List<SplitOption> splitOptions;
  final List<SplitOption> rangeSplitOptions;
  final String? selectedSplitId;
  final SplitRangeSelection? splitRange;
  final ResultDistributionData? distributionData;
  final Future<ResultDistributionData?> Function() loadFullDistributionData;
  final ValueChanged<String?> onSplitChanged;
  final VoidCallback onRangeToggle;
  final ValueChanged<String?> onRangeFromChanged;
  final ValueChanged<String?> onRangeToChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final infoCard = _InfoCard(
          event: event,
          raceClass: raceClass,
          resultCount: resultCount,
        );
        final splitSelector = SplitSelector(
          splitOptions: splitRange == null ? splitOptions : rangeSplitOptions,
          selectedSplitId: selectedSplitId,
          onChanged: onSplitChanged,
          rangeSelection: splitRange,
          canUseRange: rangeSplitOptions.any(
            (split) => split.id == selectedSplitId,
          ),
          onRangeToggle: onRangeToggle,
          onRangeFromChanged: onRangeFromChanged,
          onRangeToChanged: onRangeToChanged,
        );
        final distributionButton = ResultDistributionButton(
          data: distributionData,
          loadData: loadFullDistributionData,
          loadingLabel: AppLocalizations.of(context).loadingResults,
          errorTitle: AppLocalizations.of(context).couldNotReadResults,
        );

        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: splitSelector),
                  const SizedBox(width: 10),
                  distributionButton,
                ],
              ),
              const SizedBox(height: 10),
              infoCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: splitSelector),
            const SizedBox(width: 10),
            distributionButton,
            const SizedBox(width: 12),
            SizedBox(width: 260, child: infoCard),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.event,
    required this.raceClass,
    required this.resultCount,
  });

  final ResultEvent? event;
  final ResultClass raceClass;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _InlineMetric(label: l10n.results, value: '$resultCount'),
          _InlineMetric(
            label: l10n.athlete,
            value: '${raceClass.participantCount}',
          ),
          _InlineMetric(label: l10n.date, value: event?.dateLabel ?? '-'),
          _InlineMetric(label: l10n.sport, value: event?.sportName ?? '-'),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92, maxWidth: 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
