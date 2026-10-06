import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
import '../domain/competition_stage.dart';
import '../domain/result_class.dart';
import '../domain/result_sort_mode.dart';
import '../domain/split_def.dart';
import 'biathlon_table.dart';
import 'import_status_label.dart';
import 'result_distribution_button.dart';
import 'result_locations.dart';
import 'relay_leg_selector.dart';
import 'results_table.dart';
import 'split_selector.dart';

const _biathlonSplitId = '__biathlon_analysis__';

final _regressionSelectionProvider =
    StateProvider.autoDispose<_RegressionSelection?>((ref) => null);

class _RegressionMeasure {
  const _RegressionMeasure({
    required this.label,
    required this.isBiathlon,
    required this.isTime,
    this.splitId,
    this.splitRange,
    required this.sortMode,
    required this.biathlonKey,
  });

  final String label;
  final bool isBiathlon;
  final bool isTime;
  final String? splitId;
  final SplitRangeSelection? splitRange;
  final ResultSortMode sortMode;
  final String biathlonKey;
}

class _RegressionSelection {
  const _RegressionSelection({
    required this.eventId,
    required this.stageId,
    required this.classId,
    required this.sourceLocation,
    required this.subject,
    this.target,
  });

  final String eventId;
  final String stageId;
  final String classId;
  final String sourceLocation;
  final _RegressionMeasure subject;
  final _RegressionMeasure? target;

  _RegressionSelection withTarget(_RegressionMeasure measure) =>
      _RegressionSelection(
        eventId: eventId,
        stageId: stageId,
        classId: classId,
        sourceLocation: sourceLocation,
        subject: subject,
        target: measure,
      );
}

class ResultsPage extends ConsumerWidget {
  const ResultsPage({
    super.key,
    required this.eventId,
    this.selectedStageId,
    this.selectedClassId,
    this.selectedSplitId,
    this.selectedSplitRange,
    this.selectedRelayLegNumber,
    this.compareBaseClassId,
    this.compareBaseResultId,
    this.compareBaseRelayLegNumber,
  });

  final String eventId;
  final String? selectedStageId;
  final String? selectedClassId;
  final String? selectedSplitId;
  final SplitRangeSelection? selectedSplitRange;
  final int? selectedRelayLegNumber;
  final String? compareBaseClassId;
  final String? compareBaseResultId;
  final int? compareBaseRelayLegNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(eventsProvider);
    final classes = ref.watch(classesProvider(eventId));
    final stages = ref.watch(competitionStagesProvider(eventId));

    return AppShell(
      title:
          events.asData?.value
              .where((event) => event.id == eventId)
              .firstOrNull
              ?.name ??
          eventId,
      subtitle: null,
      leading: IconButton.outlined(
        tooltip: l10n.eventsTitle,
        onPressed: () => context.go('/events'),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: const [AccountMenu(), SettingsMenu()],
      child: ShellPanel(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 4 : 16,
        ),
        child: events.when(
          loading: () => LoadingState(label: l10n.loadingEvents),
          error: (error, _) => ErrorState(
            title: l10n.couldNotReadEvents,
            error: error,
            onRetry: () => refreshAppData(ref),
          ),
          data: (events) {
            final event = events
                .where((event) => event.id == eventId)
                .firstOrNull;
            return classes.when(
              loading: () => LoadingState(label: l10n.loadingResults),
              error: (error, _) => ErrorState(
                title: l10n.couldNotReadResults,
                error: error,
                onRetry: () => refreshAppData(ref),
              ),
              data: (classes) {
                if (classes.isEmpty) {
                  return EmptyState(
                    title: l10n.noClassesTitle,
                    message: l10n.noClassesMessage,
                  );
                }
                return stages.when(
                  loading: () => LoadingState(label: l10n.loadingResults),
                  error: (error, _) => ErrorState(
                    title: l10n.couldNotReadResults,
                    error: error,
                    onRetry: () => refreshAppData(ref),
                  ),
                  data: (stages) {
                    return _ResultsContent(
                      eventId: eventId,
                      event: event,
                      classes: classes,
                      stages: stages,
                      selectedStageId: selectedStageId,
                      selectedClassId: selectedClassId,
                      selectedSplitId: selectedSplitId,
                      selectedSplitRange: selectedSplitRange,
                      selectedRelayLegNumber: selectedRelayLegNumber,
                      compareBaseClassId: compareBaseClassId,
                      compareBaseResultId: compareBaseResultId,
                      compareBaseRelayLegNumber: compareBaseRelayLegNumber,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ResultsContent extends ConsumerStatefulWidget {
  const _ResultsContent({
    required this.eventId,
    required this.event,
    required this.classes,
    required this.stages,
    required this.selectedStageId,
    required this.selectedClassId,
    required this.selectedSplitId,
    required this.selectedSplitRange,
    required this.selectedRelayLegNumber,
    required this.compareBaseClassId,
    required this.compareBaseResultId,
    required this.compareBaseRelayLegNumber,
  });

  final String eventId;
  final ResultEvent? event;
  final List<ResultClass> classes;
  final List<CompetitionStage> stages;
  final String? selectedStageId;
  final String? selectedClassId;
  final String? selectedSplitId;
  final SplitRangeSelection? selectedSplitRange;
  final int? selectedRelayLegNumber;
  final String? compareBaseClassId;
  final String? compareBaseResultId;
  final int? compareBaseRelayLegNumber;

  @override
  ConsumerState<_ResultsContent> createState() => _ResultsContentState();
}

class _ResultsContentState extends ConsumerState<_ResultsContent> {
  bool _classesCollapsed = false;
  final ScrollController _pageScrollController = ScrollController();

  String get eventId => widget.eventId;
  ResultEvent? get event => widget.event;
  List<ResultClass> get classes => widget.classes;
  List<CompetitionStage> get stages => widget.stages;
  String? get selectedStageId => widget.selectedStageId;
  String? get selectedClassId => widget.selectedClassId;
  String? get selectedSplitId => widget.selectedSplitId;
  SplitRangeSelection? get selectedSplitRange => widget.selectedSplitRange;
  int? get selectedRelayLegNumber => widget.selectedRelayLegNumber;
  String? get compareBaseClassId => widget.compareBaseClassId;
  String? get compareBaseResultId => widget.compareBaseResultId;
  int? get compareBaseRelayLegNumber => widget.compareBaseRelayLegNumber;

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regressionSelection = ref.watch(_regressionSelectionProvider);
    final athleteEvent = ref.watch(linkedAthleteEventProvider(eventId));
    final compareSelection = _CompareSelection.tryParse(
      classId: compareBaseClassId,
      resultId: compareBaseResultId,
      relayLegNumber: compareBaseRelayLegNumber,
    );
    final activeClass = _activeClass(
      compareSelection?.classId ?? selectedClassId ?? athleteEvent?.classId,
    );
    final classId = activeClass.id;
    final classStages = stages
        .where((stage) => stage.supportsClass(classId))
        .toList();
    final activeStage = _activeStage(activeClass, classStages);
    if (activeStage == null) {
      return const EmptyState(
        title: 'Ingen konkurranseledd',
        message: 'Klassen har ingen importerte konkurranseledd ennå.',
      );
    }
    final splitDefs = ref.watch(
      stageSplitDefsProvider((
        eventId: eventId,
        stageId: activeStage.id,
        classId: classId,
      )),
    );
    final results = ref.watch(
      stageResultsProvider((
        eventId: eventId,
        stageId: activeStage.id,
        classId: classId,
      )),
    );

    return SingleChildScrollView(
      key: const Key('results-page-scroll'),
      controller: _pageScrollController,
      primary: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showClassSidebar = constraints.maxWidth >= 1050;
          void onClassChanged(String? value) {
            if (regressionSelection?.eventId == eventId &&
                regressionSelection?.target == null) {
              return;
            }
            ref.read(_regressionSelectionProvider.notifier).state = null;
            ref
                .read(settingsControllerProvider.notifier)
                .setDefaultClass(value);
            ref.read(comparisonClassIdsProvider.notifier).state = [];
            context.go(
              resultsLocation(
                eventId: eventId,
                classId: value,
                splitId: selectedSplitId,
              ),
            );
          }

          final Widget? headingLeading = !showClassSidebar
              ? _MobileClassMenu(
                  eventId: eventId,
                  classes: classes,
                  selectedClassId: classId,
                  activeSplitDefs: splitDefs,
                  onChanged: onClassChanged,
                )
              : _classesCollapsed
              ? IconButton(
                  key: const Key('classes-expand-inline'),
                  tooltip: 'Vis klasser',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: () => setState(() => _classesCollapsed = false),
                  icon: const Icon(Icons.chevron_right),
                )
              : null;
          final resultsArea = _ResultsArea(
            eventId: eventId,
            event: event,
            activeClass: activeClass,
            classes: classes,
            activeStage: activeStage,
            stages: classStages,
            headingLeading: headingLeading,
            splitDefs: splitDefs,
            results: results,
            selectedSplitId: selectedSplitId,
            selectedSplitRange: selectedSplitRange,
            selectedRelayLegNumber: selectedRelayLegNumber,
            compareSelection: compareSelection,
            pageScrollController: _pageScrollController,
          );

          if (!showClassSidebar) return resultsArea;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_classesCollapsed) ...[
                SizedBox(
                  width: 280,
                  child: _ClassSidebar(
                    eventId: eventId,
                    classes: classes,
                    selectedClassId: classId,
                    activeSplitDefs: splitDefs,
                    collapsed: false,
                    fillAvailableHeight: false,
                    onCollapseChanged: (collapsed) {
                      setState(() => _classesCollapsed = collapsed);
                    },
                    onChanged: onClassChanged,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(child: resultsArea),
            ],
          );
        },
      ),
    );
  }

  ResultClass _activeClass(String? preferredClassId) {
    return initialResultClass(classes, preferredClassId: preferredClassId);
  }

  CompetitionStage? _activeStage(
    ResultClass raceClass,
    List<CompetitionStage> classStages,
  ) {
    return selectActiveCompetitionStage(
      raceClass: raceClass,
      classStages: classStages,
      selectedStageId: selectedStageId,
    );
  }
}

CompetitionStage? selectActiveCompetitionStage({
  required ResultClass raceClass,
  required List<CompetitionStage> classStages,
  String? selectedStageId,
}) {
  if (classStages.isEmpty) return null;
  return classStages
          .where((stage) => stage.id == selectedStageId)
          .firstOrNull ??
      classStages
          .where((stage) => stage.id == raceClass.primaryStageId)
          .firstOrNull ??
      classStages.first;
}

class _ResultsArea extends ConsumerStatefulWidget {
  const _ResultsArea({
    required this.eventId,
    required this.event,
    required this.activeClass,
    required this.classes,
    required this.activeStage,
    required this.stages,
    required this.headingLeading,
    required this.splitDefs,
    required this.results,
    required this.selectedSplitId,
    required this.selectedSplitRange,
    required this.selectedRelayLegNumber,
    required this.compareSelection,
    required this.pageScrollController,
  });

  final String eventId;
  final ResultEvent? event;
  final ResultClass activeClass;
  final List<ResultClass> classes;
  final CompetitionStage activeStage;
  final List<CompetitionStage> stages;
  final Widget? headingLeading;
  final AsyncValue<List<SplitDef>> splitDefs;
  final AsyncValue<List<RaceResult>> results;
  final String? selectedSplitId;
  final SplitRangeSelection? selectedSplitRange;
  final int? selectedRelayLegNumber;
  final _CompareSelection? compareSelection;
  final ScrollController pageScrollController;

  @override
  ConsumerState<_ResultsArea> createState() => _ResultsAreaState();
}

class _ResultsAreaState extends ConsumerState<_ResultsArea> {
  bool _returnDialogScheduled = false;
  String get eventId => widget.eventId;
  ResultEvent? get event => widget.event;
  ResultClass get activeClass => widget.activeClass;
  List<ResultClass> get classes => widget.classes;
  CompetitionStage get activeStage => widget.activeStage;
  List<CompetitionStage> get stages => widget.stages;
  Widget? get headingLeading => widget.headingLeading;
  AsyncValue<List<SplitDef>> get splitDefs => widget.splitDefs;
  AsyncValue<List<RaceResult>> get results => widget.results;
  String? get selectedSplitId => widget.selectedSplitId;
  SplitRangeSelection? get selectedSplitRange => widget.selectedSplitRange;
  int? get selectedRelayLegNumber => widget.selectedRelayLegNumber;
  _CompareSelection? get compareSelection => widget.compareSelection;
  ScrollController get pageScrollController => widget.pageScrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final regressionSelection = ref.watch(_regressionSelectionProvider);
    final activeRegressionSelection =
        regressionSelection?.eventId == eventId &&
            regressionSelection?.stageId == activeStage.id &&
            regressionSelection?.classId == activeClass.id
        ? regressionSelection
        : null;
    final settings = ref.watch(settingsControllerProvider);
    final sortMode = ref.watch(resultSortModeProvider(eventId));
    final biathlonSortKey = ref.watch(biathlonSortKeyProvider);
    final affiliationView = ref.watch(resultAffiliationViewProvider);
    final linkedAthleteId = ref.watch(linkedAthleteIdProvider).asData?.value;
    final favoriteAthleteIds =
        ref.watch(favoriteAthleteIdsProvider).asData?.value ?? const <String>{};
    final linkedAthleteProfile = linkedAthleteId == null
        ? null
        : ref.watch(athleteProfileProvider(linkedAthleteId)).asData?.value;
    final linkedAffiliations = linkedAthleteProfile == null
        ? null
        : ref
              .watch(
                athleteAffiliationsProvider((
                  clubId: linkedAthleteProfile.primaryClubId,
                  teamId: linkedAthleteProfile.primaryTeamId,
                )),
              )
              .asData
              ?.value;
    final comparisonClassIds = compareSelection == null
        ? ref.watch(comparisonClassIdsProvider)
        : <String>[];
    final requestedSplitRange = selectedSplitRange;
    final classId = activeClass.id;
    final searchArgs = (
      eventId: eventId,
      stageId: activeStage.id,
      classId: classId,
    );
    final searchQuery = ref.watch(resultSearchQueryProvider(searchArgs));
    final relaySelectionArgs = (
      eventId: eventId,
      stageId: activeStage.id,
      classId: classId,
    );
    final requestedRelayComparisonLegs = ref.watch(
      relayComparisonLegNumbersProvider(relaySelectionArgs),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultTitle(
          event: event,
          raceClass: activeClass,
          stage: activeStage,
          leading: headingLeading,
        ),
        ImportStatusLabel(state: activeStage.classImportStates[classId]),
        if (stages.length > 1) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 300,
                child: _CompetitionStageSelector(
                  stages: stages,
                  selectedStageId: activeStage.id,
                  onChanged: (value) {
                    if (activeRegressionSelection?.target == null &&
                        activeRegressionSelection != null) {
                      return;
                    }
                    ref.read(_regressionSelectionProvider.notifier).state =
                        null;
                    ref.read(comparisonClassIdsProvider.notifier).state = [];
                    context.go(
                      resultsLocation(
                        eventId: eventId,
                        classId: classId,
                        stageId: value,
                        splitId: selectedSplitId,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        splitDefs.when(
          loading: () => LoadingState(label: l10n.loadingResults),
          error: (error, _) => ErrorState(
            title: l10n.couldNotReadResults,
            error: error,
            onRetry: () => refreshAppData(ref),
          ),
          data: (splitDefs) {
            return results.when(
              skipLoadingOnReload: true,
              skipError: true,
              loading: () => LoadingState(label: l10n.loadingResults),
              error: (error, _) => ErrorState(
                title: l10n.couldNotReadResults,
                error: error,
                onRetry: () => refreshAppData(ref),
              ),
              data: (loadedResults) {
                if (loadedResults.isEmpty) {
                  return EmptyState(
                    title: l10n.noResultsTitle,
                    message: l10n.noResultsMessage,
                  );
                }
                final availableRelayLegs =
                    activeStage.isRelay ||
                        loadedResults.any(
                          (result) =>
                              result.entrant?.kind == ResultEntrantKind.team,
                        )
                    ? relayLegNumbers(loadedResults)
                    : const <int>[];
                final preferredRelayLeg =
                    selectedRelayLegNumber ?? compareSelection?.relayLegNumber;
                final activeRelayLeg =
                    availableRelayLegs.contains(preferredRelayLeg)
                    ? preferredRelayLeg
                    : null;
                final relayComparisonLegs = activeRelayLeg == null
                    ? const <int>[]
                    : requestedRelayComparisonLegs
                          .where(
                            (leg) =>
                                leg != activeRelayLeg &&
                                availableRelayLegs.contains(leg),
                          )
                          .toList();
                final displayedPrimaryResults = activeRelayLeg == null
                    ? loadedResults
                    : relayLegRaceResults(loadedResults, activeRelayLeg);
                final displayedSplitDefs = activeRelayLeg == null
                    ? splitDefs
                    : relayLegSplitDefs(
                        splitDefs,
                        activeRelayLeg,
                        displayedPrimaryResults,
                      );
                final primaryViewClass = activeRelayLeg == null
                    ? activeClass
                    : _relayLegClass(
                        activeClass,
                        activeRelayLeg,
                        displayedPrimaryResults.length,
                      );
                final selectableSplitDefs =
                    activeRelayLeg != null && relayComparisonLegs.isNotEmpty
                    ? displayedSplitDefs
                          .where((split) => split.id == relayLegFinishSplitId)
                          .toList()
                    : displayedSplitDefs;
                final comparisonRead = activeRelayLeg == null
                    ? _readComparisonData(
                        ref,
                        displayedSplitDefs,
                        comparisonClassIds,
                      )
                    : _ComparisonRead.data([
                        for (final legNumber in relayComparisonLegs)
                          _ComparisonRows(
                            raceClass: _relayLegClass(
                              activeClass,
                              legNumber,
                              loadedResults.length,
                            ),
                            sourceClassId: activeClass.id,
                            results: relayLegRaceResults(
                              loadedResults,
                              legNumber,
                            ),
                          ),
                      ]);
                if (comparisonRead.isLoading && comparisonRead.rows.isEmpty) {
                  return LoadingState(label: l10n.loadingResults);
                }
                if (comparisonRead.error != null) {
                  return ErrorState(
                    title: l10n.couldNotReadResults,
                    error: comparisonRead.error!,
                    onRetry: () => refreshAppData(ref),
                  );
                }
                final isLoadingMore =
                    (results.isLoading && results.hasValue) ||
                    comparisonRead.isLoading;
                final canLoadMore = _canLoadMoreResults(
                  ref,
                  primaryResults: loadedResults,
                  comparisons: activeRelayLeg == null
                      ? comparisonRead.rows
                      : const [],
                );
                final tableRows = _buildTableRows(
                  primaryClass: primaryViewClass,
                  primaryResults: displayedPrimaryResults,
                  comparisons: comparisonRead.rows,
                  linkedAthleteId: linkedAthleteId,
                  linkedClubName: linkedAffiliations?.clubName,
                  linkedTeamName: linkedAffiliations?.teamName,
                  favoriteAthleteIds: favoriteAthleteIds,
                );
                final baseRow = compareSelection == null
                    ? null
                    : tableRows.where((row) {
                        return row.sourceClassId == compareSelection!.classId &&
                            row.result.detailResultId ==
                                compareSelection!.resultId &&
                            row.result.relayLegNumber ==
                                compareSelection!.relayLegNumber;
                      }).firstOrNull;
                final hasBiathlonData = BiathlonTable.hasBiathlonData(
                  tableRows,
                );
                final allSplitOptions = _splitOptions(
                  selectableSplitDefs,
                  displayedPrimaryResults,
                  hasBiathlonData,
                );
                final splitOptions =
                    activeRelayLeg != null && relayComparisonLegs.isNotEmpty
                    ? allSplitOptions
                          .where(
                            (split) =>
                                split.id == relayLegFinishSplitId ||
                                split.id == _biathlonSplitId,
                          )
                          .toList()
                    : allSplitOptions;
                final activeSplitId = _activeSplitId(
                  selectedSplitId,
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
                final effectiveSortMode =
                    activeSplitRange?.isIndependent == true
                    ? ResultSortMode.split
                    : sortMode;
                final currentMeasure = _regressionMeasure(
                  tableRows: tableRows,
                  splitOptions: splitOptions,
                  isBiathlonSplit: isBiathlonSplit,
                  splitId: selectedResultSplitId,
                  splitRange: activeSplitRange,
                  sortMode: effectiveSortMode,
                  biathlonSortKey: biathlonSortKey,
                );
                final comparisonTarget = activeRegressionSelection?.target;
                final distributionData = _distributionData(
                  tableRows: tableRows,
                  analysisClassId: primaryViewClass.id,
                  visibleSplits: rangeSplitOptions,
                  isBiathlonSplit: isBiathlonSplit,
                  activeSplitId: selectedResultSplitId,
                  splitRange: activeSplitRange,
                  sortMode: effectiveSortMode,
                  biathlonSortKey: biathlonSortKey,
                  comparisonTarget: comparisonTarget,
                );
                Future<ResultDistributionData?> loadFullDistributionData() {
                  return _loadFullDistributionData(
                    ref: ref,
                    primarySplitDefs: selectableSplitDefs,
                    visibleSplits: rangeSplitOptions,
                    comparisonClassIds: comparisonClassIds,
                    relayLegNumber: activeRelayLeg,
                    relayComparisonLegNumbers: relayComparisonLegs,
                    isBiathlonSplit: isBiathlonSplit,
                    activeSplitId: selectedResultSplitId,
                    splitRange: activeSplitRange,
                    sortMode: effectiveSortMode,
                    biathlonSortKey: biathlonSortKey,
                    comparisonTarget: comparisonTarget,
                    linkedAthleteId: linkedAthleteId,
                    linkedClubName: linkedAffiliations?.clubName,
                    linkedTeamName: linkedAffiliations?.teamName,
                    favoriteAthleteIds: favoriteAthleteIds,
                  );
                }

                void restoreSubject() {
                  final selection = activeRegressionSelection;
                  if (selection == null) return;
                  ref.read(resultSortModeProvider(eventId).notifier).state =
                      selection.subject.sortMode;
                  ref.read(biathlonSortKeyProvider.notifier).state =
                      selection.subject.biathlonKey;
                  context.go(selection.sourceLocation);
                }

                if (comparisonTarget != null &&
                    !_returnDialogScheduled &&
                    GoRouterState.of(context).uri.toString() ==
                        activeRegressionSelection!.sourceLocation) {
                  _returnDialogScheduled = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _returnDialogScheduled = false;
                    ref.read(_regressionSelectionProvider.notifier).state =
                        null;
                    showResultAnalysisDialog(
                      context,
                      data: distributionData,
                      loadData: () async {
                        final fullData = await loadFullDistributionData();
                        if (fullData == null ||
                            !fullData.regressionTargets.any(
                              (target) => target.key == 'selected',
                            )) {
                          return null;
                        }
                        return fullData;
                      },
                      loadingLabel: l10n.loadingResults,
                      errorTitle: l10n.couldNotReadResults,
                      openRegression: true,
                      initialRegressionTargetKey: 'selected',
                      onChooseFromResultsList: () {
                        ref
                            .read(_regressionSelectionProvider.notifier)
                            .state = _RegressionSelection(
                          eventId: eventId,
                          stageId: activeStage.id,
                          classId: classId,
                          sourceLocation: GoRouterState.of(
                            context,
                          ).uri.toString(),
                          subject: currentMeasure,
                        );
                      },
                    );
                  });
                }

                void loadMoreResults() {
                  _loadMoreResults(
                    ref,
                    primaryResults: loadedResults,
                    comparisons: activeRelayLeg == null
                        ? comparisonRead.rows
                        : const [],
                  );
                }

                final stickyClassHeader = _StickyResultClassHeader(
                  raceClass: primaryViewClass,
                  stage: activeStage,
                  leading: headingLeading,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (availableRelayLegs.isNotEmpty) ...[
                      RelayLegSelector(
                        legNumbers: availableRelayLegs,
                        activeLegNumber: activeRelayLeg,
                        comparisonLegNumbers: relayComparisonLegs,
                        onPrimaryChanged: (legNumber) {
                          ref
                                  .read(_regressionSelectionProvider.notifier)
                                  .state =
                              null;
                          ref
                                  .read(
                                    relayComparisonLegNumbersProvider(
                                      relaySelectionArgs,
                                    ).notifier,
                                  )
                                  .state =
                              [];
                          context.go(
                            resultsLocation(
                              eventId: eventId,
                              classId: classId,
                              stageId: activeStage.id,
                              relayLegNumber: legNumber,
                              splitId: legNumber == null
                                  ? null
                                  : relayLegFinishSplitId,
                            ),
                          );
                        },
                        onComparisonChanged: (legNumber, selected) {
                          final next = [...relayComparisonLegs];
                          if (selected) {
                            if (!next.contains(legNumber)) {
                              next.add(legNumber);
                            }
                          } else {
                            next.remove(legNumber);
                          }
                          next.sort();
                          ref
                                  .read(
                                    relayComparisonLegNumbersProvider(
                                      relaySelectionArgs,
                                    ).notifier,
                                  )
                                  .state =
                              next;
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (compareSelection != null) ...[
                      _CompareSelectionBanner(
                        baseName: baseRow?.result.name ?? 'Valgt utover',
                        onCancel: () => context.go(
                          resultsLocation(
                            eventId: eventId,
                            classId: classId,
                            stageId: activeStage.id,
                            relayLegNumber: activeRelayLeg,
                            splitId: selectedResultSplitId,
                            splitRange: activeSplitRange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (activeRegressionSelection != null &&
                        activeRegressionSelection.target == null) ...[
                      Card(
                        key: const Key('regression-list-selection'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                l10n.regressionSelectFromList(
                                  activeRegressionSelection.subject.label,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  restoreSubject();
                                  ref
                                          .read(
                                            _regressionSelectionProvider
                                                .notifier,
                                          )
                                          .state =
                                      null;
                                },
                                child: Text(l10n.regressionCancel),
                              ),
                              FilledButton(
                                key: const Key('regression-list-apply'),
                                onPressed: () {
                                  ref
                                      .read(
                                        _regressionSelectionProvider.notifier,
                                      )
                                      .state = activeRegressionSelection
                                      .withTarget(currentMeasure);
                                  restoreSubject();
                                },
                                child: Text(l10n.regressionApply),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _SplitAndInfoRow(
                      sticky: false,
                      splitOptions: splitOptions,
                      rangeSplitOptions: rangeSplitOptions,
                      selectedSplitId: selectedResultSplitId,
                      splitRange: activeSplitRange,
                      distributionData: distributionData,
                      loadFullDistributionData: loadFullDistributionData,
                      onChooseFromResultsList: () {
                        ref
                            .read(_regressionSelectionProvider.notifier)
                            .state = _RegressionSelection(
                          eventId: eventId,
                          stageId: activeStage.id,
                          classId: classId,
                          sourceLocation: GoRouterState.of(
                            context,
                          ).uri.toString(),
                          subject: currentMeasure,
                        );
                      },
                      searchField: _ResultSearchField(
                        key: ValueKey(
                          '${searchArgs.eventId}/${searchArgs.classId}',
                        ),
                        initialQuery: searchQuery,
                        onChanged: (value) {
                          ref
                                  .read(
                                    resultSearchQueryProvider(
                                      searchArgs,
                                    ).notifier,
                                  )
                                  .state =
                              value;
                          if (value.trim().isNotEmpty) {
                            _loadAllResultsForSearch(ref, comparisonClassIds);
                          }
                        },
                      ),
                      onSplitChanged: (value) {
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setPreferredSplit(value);
                        context.go(
                          resultsLocation(
                            eventId: eventId,
                            classId: classId,
                            stageId: activeStage.id,
                            relayLegNumber: activeRelayLeg,
                            splitId: value,
                            compareBaseClassId: compareSelection?.classId,
                            compareBaseResultId: compareSelection?.resultId,
                            compareBaseRelayLegNumber:
                                compareSelection?.relayLegNumber,
                          ),
                        );
                      },
                      onRangeToggle: () {
                        if (activeSplitRange != null) {
                          context.go(
                            resultsLocation(
                              eventId: eventId,
                              classId: classId,
                              stageId: activeStage.id,
                              relayLegNumber: activeRelayLeg,
                              splitId: selectedResultSplitId,
                              compareBaseClassId: compareSelection?.classId,
                              compareBaseResultId: compareSelection?.resultId,
                              compareBaseRelayLegNumber:
                                  compareSelection?.relayLegNumber,
                            ),
                          );
                          return;
                        }
                        final range = _initialSplitRange(
                          activeSplitId,
                          rangeSplitOptions,
                        );
                        if (range == null) return;
                        context.go(
                          resultsLocation(
                            eventId: eventId,
                            classId: classId,
                            stageId: activeStage.id,
                            relayLegNumber: activeRelayLeg,
                            splitRange: range,
                            compareBaseClassId: compareSelection?.classId,
                            compareBaseResultId: compareSelection?.resultId,
                            compareBaseRelayLegNumber:
                                compareSelection?.relayLegNumber,
                          ),
                        );
                      },
                      onRangeFromChanged: (value) {
                        final current = activeSplitRange;
                        if (current == null) return;
                        final next = _normalizeSplitRange(
                          current.copyWith(
                            fromSplitId: value,
                            clearFromSplitId: value == null,
                          ),
                          rangeSplitOptions,
                        );
                        context.go(
                          resultsLocation(
                            eventId: eventId,
                            classId: classId,
                            stageId: activeStage.id,
                            relayLegNumber: activeRelayLeg,
                            splitId: next?.toSplitId ?? selectedResultSplitId,
                            splitRange: next,
                            compareBaseClassId: compareSelection?.classId,
                            compareBaseResultId: compareSelection?.resultId,
                            compareBaseRelayLegNumber:
                                compareSelection?.relayLegNumber,
                          ),
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
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setPreferredSplit(next?.toSplitId);
                        context.go(
                          resultsLocation(
                            eventId: eventId,
                            classId: classId,
                            stageId: activeStage.id,
                            relayLegNumber: activeRelayLeg,
                            splitId: next?.toSplitId ?? selectedResultSplitId,
                            splitRange: next,
                            compareBaseClassId: compareSelection?.classId,
                            compareBaseResultId: compareSelection?.resultId,
                            compareBaseRelayLegNumber:
                                compareSelection?.relayLegNumber,
                          ),
                        );
                      },
                      onIndependentChanged: (enabled) {
                        final current = activeSplitRange;
                        if (current == null) return;
                        final next = _normalizeSplitRange(
                          current.copyWith(isIndependent: enabled),
                          rangeSplitOptions,
                        );
                        context.go(
                          resultsLocation(
                            eventId: eventId,
                            classId: classId,
                            stageId: activeStage.id,
                            relayLegNumber: activeRelayLeg,
                            splitId: next?.toSplitId ?? selectedResultSplitId,
                            splitRange: next,
                            compareBaseClassId: compareSelection?.classId,
                            compareBaseResultId: compareSelection?.resultId,
                            compareBaseRelayLegNumber:
                                compareSelection?.relayLegNumber,
                          ),
                        );
                      },
                      onIncludedSplitsChanged: (splitIds) {
                        final current = activeSplitRange;
                        if (current == null || !current.isIndependent) {
                          return;
                        }
                        final next = _normalizeSplitRange(
                          current.copyWith(includedSplitIds: splitIds),
                          rangeSplitOptions,
                        );
                        if (next != null) {
                          ref
                              .read(settingsControllerProvider.notifier)
                              .setPreferredSplit(next.toSplitId);
                        }
                        context.go(
                          resultsLocation(
                            eventId: eventId,
                            classId: classId,
                            stageId: activeStage.id,
                            relayLegNumber: activeRelayLeg,
                            splitId: next?.toSplitId ?? selectedResultSplitId,
                            splitRange: next,
                            compareBaseClassId: compareSelection?.classId,
                            compareBaseResultId: compareSelection?.resultId,
                            compareBaseRelayLegNumber:
                                compareSelection?.relayLegNumber,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    isBiathlonSplit
                        ? BiathlonTable(
                            rows: tableRows,
                            searchQuery: searchQuery,
                            sortKey: biathlonSortKey,
                            onSortKeyChanged: (value) {
                              ref.read(biathlonSortKeyProvider.notifier).state =
                                  value;
                            },
                            tableDensity: settings.tableDensity,
                            affiliationView: affiliationView,
                            onAffiliationViewToggle: () {
                              ref
                                      .read(
                                        resultAffiliationViewProvider.notifier,
                                      )
                                      .state =
                                  affiliationView == ResultAffiliationView.club
                                  ? ResultAffiliationView.team
                                  : ResultAffiliationView.club;
                            },
                            disabledResultId: baseRow?.result.id,
                            onLoadMore: canLoadMore ? loadMoreResults : null,
                            isLoadingMore: isLoadingMore,
                            pageScrollController: pageScrollController,
                            stickyClassHeader: stickyClassHeader,
                            onAthleteTap: (row) {
                              _openAthlete(
                                context,
                                row,
                                compareSelection,
                                splitId: selectedResultSplitId,
                                splitRange: activeSplitRange,
                              );
                            },
                          )
                        : ResultsTable(
                            rows: tableRows,
                            searchQuery: searchQuery,
                            selectedSplitId: selectedResultSplitId,
                            splitRange: activeSplitRange,
                            sortMode: effectiveSortMode,
                            onSortModeChanged: (value) {
                              ref
                                      .read(
                                        resultSortModeProvider(
                                          eventId,
                                        ).notifier,
                                      )
                                      .state =
                                  value;
                            },
                            tableDensity: settings.tableDensity,
                            affiliationView: affiliationView,
                            onAffiliationViewToggle: () {
                              ref
                                      .read(
                                        resultAffiliationViewProvider.notifier,
                                      )
                                      .state =
                                  affiliationView == ResultAffiliationView.club
                                  ? ResultAffiliationView.team
                                  : ResultAffiliationView.club;
                            },
                            disabledResultId: baseRow?.result.id,
                            onLoadMore: canLoadMore ? loadMoreResults : null,
                            isLoadingMore: isLoadingMore,
                            pageScrollController: pageScrollController,
                            stickyClassHeader: stickyClassHeader,
                            onAthleteTap: (row) {
                              _openAthlete(
                                context,
                                row,
                                compareSelection,
                                splitId: selectedResultSplitId,
                                splitRange: activeSplitRange,
                              );
                            },
                          ),
                    const SizedBox(height: 10),
                    _InfoCard(
                      event: event,
                      raceClass: primaryViewClass,
                      resultCount:
                          activeRelayLeg == null && activeClass.resultCount > 0
                          ? activeClass.resultCount
                          : tableRows.length,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _openAthlete(
    BuildContext context,
    ResultTableRow row,
    _CompareSelection? compareSelection, {
    required String? splitId,
    required SplitRangeSelection? splitRange,
  }) {
    if (compareSelection == null) {
      context.go(
        athleteLocation(
          eventId: eventId,
          classId: row.sourceClassId ?? row.classId,
          resultId: row.result.detailResultId,
          stageId: activeStage.id,
          relayLegNumber: row.result.relayLegNumber,
          splitId: splitId,
          splitRange: splitRange,
        ),
      );
      return;
    }
    context.go(
      athleteLocation(
        eventId: eventId,
        classId: compareSelection.classId,
        resultId: compareSelection.resultId,
        stageId: activeStage.id,
        relayLegNumber: compareSelection.relayLegNumber,
        splitId: splitId,
        splitRange: splitRange,
        compareWithResultId: row.result.detailResultId,
        compareWithRelayLegNumber: row.result.relayLegNumber,
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
        kind: 'analysis',
      ),
    ];
  }

  String? _activeSplitId(String? preferredSplitId, List<SplitOption> options) {
    if (options.isEmpty) return null;
    for (final split in options) {
      if (split.id == preferredSplitId) return split.id;
    }
    for (final split in options.reversed) {
      if (split.kind.toLowerCase() == 'finish') return split.id;
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
    return _normalizeSplitRange(requested, splitOptions);
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

    if (range.isIndependent) {
      final requestedIds = range.includedSplitIds.toSet();
      final includedSplitIds = splitOptions
          .where((split) => requestedIds.contains(split.id))
          .map((split) => split.id)
          .toList();
      if (includedSplitIds.isEmpty) return null;
      final focusedId = includedSplitIds.last;
      return SplitRangeSelection(
        fromSplitId: range.fromSplitId,
        toSplitId: focusedId,
        includedSplitIds: includedSplitIds,
        isIndependent: true,
      );
    }

    final requestedFromId = range.fromSplitId;
    final fromIndex = requestedFromId == null
        ? -1
        : splitOptions.indexWhere((split) => split.id == requestedFromId);
    if (fromIndex < -1 || fromIndex >= toIndex) return null;

    final includedSplitIds = splitOptions
        .skip(fromIndex + 1)
        .take(toIndex - fromIndex)
        .map((split) => split.id)
        .toList();
    return SplitRangeSelection(
      fromSplitId: fromIndex >= 0 ? splitOptions[fromIndex].id : null,
      toSplitId: splitOptions[toIndex].id,
      includedSplitIds: includedSplitIds,
      isIndependent: false,
    );
  }

  ResultDistributionData? _distributionData({
    required List<ResultTableRow> tableRows,
    required String analysisClassId,
    required List<SplitOption> visibleSplits,
    required bool isBiathlonSplit,
    required String? activeSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
    required String biathlonSortKey,
    _RegressionMeasure? comparisonTarget,
  }) {
    final subject = _regressionMeasure(
      tableRows: tableRows,
      splitOptions: visibleSplits,
      isBiathlonSplit: isBiathlonSplit,
      splitId: activeSplitId,
      splitRange: splitRange,
      sortMode: sortMode,
      biathlonSortKey: biathlonSortKey,
    );
    final selectedRegression = comparisonTarget == null
        ? null
        : _selectionRegressionData(tableRows, subject, comparisonTarget);
    if (isBiathlonSplit) {
      return _biathlonDistributionData(
        tableRows,
        biathlonSortKey,
        analysisClassId: analysisClassId,
        visibleSplits: visibleSplits,
        comparisonTarget: comparisonTarget,
        selectedRegression: selectedRegression,
      );
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
    final currentAthleteValue = tableRows
        .where((row) => row.result.isFinished && row.isCurrentAthlete)
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
        .firstOrNull;
    return ResultDistributionData(
      title: 'Fordeling: $valueLabel',
      values: values,
      formatValue: formatDurationMs,
      currentAthleteValue: currentAthleteValue,
      regression:
          selectedRegression ??
          _resultRegressionData(
            tableRows: tableRows,
            activeSplitId: activeSplitId,
            splitRange: splitRange,
            sortMode: sortMode,
            valueLabel: valueLabel,
          ),
      regressionTargets: [
        ..._resultRegressionTargets(
          tableRows: tableRows,
          activeSplitId: activeSplitId,
          splitRange: splitRange,
          sortMode: sortMode,
          valueLabel: valueLabel,
        ),
        if (selectedRegression != null)
          ResultRegressionTarget(
            key: 'selected',
            label: comparisonTarget!.label,
            regression: selectedRegression,
          ),
      ],
      splitAnalysis: _splitAnalysisData(
        tableRows,
        analysisClassId,
        visibleSplits,
      ),
    );
  }

  ResultDistributionData _biathlonDistributionData(
    List<ResultTableRow> tableRows,
    String preferredSortKey, {
    required String analysisClassId,
    required List<SplitOption> visibleSplits,
    _RegressionMeasure? comparisonTarget,
    ResultRegressionData? selectedRegression,
  }) {
    final metrics = _biathlonMetrics(tableRows);
    final selected = metrics.firstWhere(
      (metric) => metric.key == preferredSortKey,
      orElse: () => metrics.first,
    );
    return ResultDistributionData(
      title: 'Fordeling: ${selected.label}',
      values: selected.values,
      formatValue: selected.isTime ? formatDurationMs : (value) => '$value',
      currentAthleteLabel: selected.isTime ? 'Din tid' : 'Din verdi',
      currentAthleteValue: tableRows
          .where((row) => row.result.isFinished && row.isCurrentAthlete)
          .map((row) => _biathlonMetricValue(row.result.biathlon, selected.key))
          .whereType<int>()
          .where((value) => selected.isTime ? value > 0 : value >= 0)
          .firstOrNull,
      regression:
          selectedRegression ?? _biathlonRegressionData(tableRows, selected),
      regressionTargets: [
        ..._biathlonRegressionTargets(tableRows, selected),
        if (selectedRegression != null)
          ResultRegressionTarget(
            key: 'selected',
            label: comparisonTarget!.label,
            regression: selectedRegression,
          ),
      ],
      splitAnalysis: _splitAnalysisData(
        tableRows,
        analysisClassId,
        visibleSplits,
      ),
    );
  }

  ResultSplitAnalysisData? _splitAnalysisData(
    List<ResultTableRow> tableRows,
    String analysisClassId,
    List<SplitOption> visibleSplits,
  ) {
    return buildResultSplitAnalysis(
      tableRows
          .where((row) => row.classId == analysisClassId)
          .map((row) => row.result),
      visibleSplits: visibleSplits,
    );
  }

  ResultRegressionData? _biathlonRegressionData(
    List<ResultTableRow> tableRows,
    _DistributionMetric metric, {
    _DistributionMetric? target,
  }) {
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
      final targetValue = target == null
          ? totalMs
          : _biathlonMetricValue(row.result.biathlon, target.key);
      if (targetValue == null ||
          targetValue < 0 ||
          (target?.isTime == true && targetValue <= 0)) {
        continue;
      }
      points.add(
        ResultRegressionPoint(
          x: targetValue,
          y: value,
          label: row.result.name,
          color: row.color,
          isCurrentAthlete: row.isCurrentAthlete,
        ),
      );
    }

    if (points.length < 2) return null;
    return ResultRegressionData(
      title: 'Regresjon: ${metric.label} mot ${target?.label ?? 'sluttid'}',
      subjectLabel: metric.label,
      xLabel: target?.label ?? 'Sluttid',
      yLabel: metric.label,
      points: points,
      formatX: target == null || target.isTime
          ? formatDurationMs
          : (value) => '$value',
      formatY: metric.isTime ? formatDurationMs : (value) => '$value',
    );
  }

  List<ResultRegressionTarget> _biathlonRegressionTargets(
    List<ResultTableRow> tableRows,
    _DistributionMetric subject,
  ) {
    final baseline = _biathlonRegressionData(tableRows, subject);
    if (baseline == null) return const [];
    return [
      ResultRegressionTarget(
        key: 'finish',
        label: 'Sluttid',
        regression: baseline,
      ),
      for (final metric in _biathlonMetrics(tableRows))
        if (metric.key != subject.key)
          if (_biathlonRegressionData(tableRows, subject, target: metric)
              case final regression?)
            ResultRegressionTarget(
              key: metric.key,
              label: metric.label,
              regression: regression,
            ),
    ];
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
          .map((row) => row.result.biathlon)
          .whereType<BiathlonAnalysis>()
          .map(read)
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
      read: (analysis) => analysis.skiTimeMs,
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
        (row.result.biathlon?.passes ?? const <ShootingPass>[])
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

  int? _biathlonMetricValue(BiathlonAnalysis? analysis, String key) {
    if (analysis == null) return null;
    if (key == 'ski') return analysis.skiTimeMs;
    if (key == 'shooting') return analysis.shootingTimeMs;
    if (key == 'penalty') return analysis.penaltyTimeMs;
    if (key == 'misses') return analysis.missesTotal;
    if (key.startsWith('range:')) {
      final index = int.tryParse(key.substring('range:'.length));
      if (index == null) return null;
      return analysis.passAt(index)?.rangeMs;
    }
    return analysis.skiTimeMs;
  }

  _RegressionMeasure _regressionMeasure({
    required List<ResultTableRow> tableRows,
    required List<SplitOption> splitOptions,
    required bool isBiathlonSplit,
    required String? splitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
    required String biathlonSortKey,
  }) {
    if (isBiathlonSplit) {
      final metrics = _biathlonMetrics(tableRows);
      final metric = metrics.firstWhere(
        (metric) => metric.key == biathlonSortKey,
        orElse: () => metrics.first,
      );
      return _RegressionMeasure(
        label: metric.label,
        isBiathlon: true,
        isTime: metric.isTime,
        sortMode: sortMode,
        biathlonKey: metric.key,
      );
    }
    final selected = splitOptions
        .where((option) => option.id == splitId)
        .firstOrNull;
    final label = switch (splitRange) {
      null =>
        selected?.kind.toLowerCase() == 'finish' &&
                sortMode == ResultSortMode.cumulative
            ? 'Sluttid'
            : '${selected?.label ?? _resultValueLabel(activeSplitId: splitId, splitRange: null, sortMode: sortMode)}${sortMode == ResultSortMode.split ? ' (splittid)' : ''}',
      final range when range.isIndependent => 'Valgte splittider',
      final range =>
        '${splitOptions.where((option) => option.id == range.fromSplitId).firstOrNull?.label ?? 'Start'}–${selected?.label ?? range.toSplitId}',
    };
    return _RegressionMeasure(
      label: label,
      isBiathlon: false,
      isTime: true,
      splitId: splitId,
      splitRange: splitRange,
      sortMode: sortMode,
      biathlonKey: biathlonSortKey,
    );
  }

  int? _regressionMeasureValue(RaceResult result, _RegressionMeasure measure) {
    final value = measure.isBiathlon
        ? _biathlonMetricValue(result.biathlon, measure.biathlonKey)
        : _resultSortValue(
            result,
            measure.splitId,
            measure.splitRange,
            measure.sortMode,
          );
    if (value == null || value < 0 || (measure.isTime && value == 0)) {
      return null;
    }
    return value;
  }

  ResultRegressionData? _selectionRegressionData(
    List<ResultTableRow> rows,
    _RegressionMeasure subject,
    _RegressionMeasure target,
  ) {
    final points = <ResultRegressionPoint>[];
    for (final row in rows) {
      if (!row.result.isFinished) continue;
      final subjectValue = _regressionMeasureValue(row.result, subject);
      final targetValue = _regressionMeasureValue(row.result, target);
      if (subjectValue == null || targetValue == null) continue;
      points.add(
        ResultRegressionPoint(
          x: targetValue,
          y: subjectValue,
          label: row.result.name,
          color: row.color,
          isCurrentAthlete: row.isCurrentAthlete,
        ),
      );
    }
    if (points.length < 2) return null;
    return ResultRegressionData(
      title: 'Regresjon: ${subject.label} mot ${target.label}',
      subjectLabel: subject.label,
      xLabel: target.label,
      yLabel: subject.label,
      points: points,
      formatX: target.isTime ? formatDurationMs : (value) => '$value',
      formatY: subject.isTime ? formatDurationMs : (value) => '$value',
    );
  }

  String _resultValueLabel({
    required String? activeSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
  }) {
    if (sortMode == ResultSortMode.split) {
      if (splitRange?.isIndependent == true) return 'Valgte splittider';
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
    _DistributionMetric? target,
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
      final targetValue = target == null
          ? totalMs
          : _biathlonMetricValue(row.result.biathlon, target.key);
      if (targetValue == null ||
          targetValue < 0 ||
          (target?.isTime == true && targetValue <= 0)) {
        continue;
      }

      points.add(
        ResultRegressionPoint(
          x: target == null && !rankedTimeOnYAxis ? rankedMs : targetValue,
          y: target == null && !rankedTimeOnYAxis ? totalMs : rankedMs,
          label: row.result.name,
          color: row.color,
          isCurrentAthlete: row.isCurrentAthlete,
        ),
      );
    }

    if (points.length < 2) return null;
    return ResultRegressionData(
      title: 'Regresjon: $valueLabel mot ${target?.label ?? 'sluttid'}',
      subjectLabel: valueLabel,
      xLabel: target != null
          ? target.label
          : rankedTimeOnYAxis
          ? 'Sluttid'
          : valueLabel,
      yLabel: target != null
          ? valueLabel
          : rankedTimeOnYAxis
          ? valueLabel
          : 'Sluttid',
      points: points,
      formatX: target?.isTime == false ? (value) => '$value' : formatDurationMs,
      formatY: formatDurationMs,
    );
  }

  List<ResultRegressionTarget> _resultRegressionTargets({
    required List<ResultTableRow> tableRows,
    required String? activeSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
    required String valueLabel,
  }) {
    final baseline = _resultRegressionData(
      tableRows: tableRows,
      activeSplitId: activeSplitId,
      splitRange: splitRange,
      sortMode: sortMode,
      valueLabel: valueLabel,
    );
    if (baseline == null) return const [];
    return [
      ResultRegressionTarget(
        key: 'finish',
        label: 'Sluttid',
        regression: baseline,
      ),
      for (final metric in _biathlonMetrics(tableRows))
        if (_resultRegressionData(
              tableRows: tableRows,
              activeSplitId: activeSplitId,
              splitRange: splitRange,
              sortMode: sortMode,
              valueLabel: valueLabel,
              target: metric,
            )
            case final regression?)
          ResultRegressionTarget(
            key: metric.key,
            label: metric.label,
            regression: regression,
          ),
    ];
  }

  int? _resultSortValue(
    RaceResult result,
    String? activeSplitId,
    SplitRangeSelection? splitRange,
    ResultSortMode sortMode,
  ) {
    if (sortMode == ResultSortMode.split && splitRange != null) {
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
    _loadMoreClassResults(
      ref,
      activeClass,
      primaryResults.length,
      stageId: activeStage.id,
    );
    for (final comparison in comparisons) {
      _loadMoreClassResults(
        ref,
        comparison.raceClass,
        comparison.results.length,
        stageId: activeStage.supportsClass(comparison.raceClass.id)
            ? activeStage.id
            : null,
      );
    }
  }

  bool _canLoadMoreResults(
    WidgetRef ref, {
    required List<RaceResult> primaryResults,
    required List<_ComparisonRows> comparisons,
  }) {
    if (_canLoadMoreClassResults(
      ref,
      activeClass,
      primaryResults.length,
      stageId: activeStage.id,
    )) {
      return true;
    }
    return comparisons.any(
      (comparison) => _canLoadMoreClassResults(
        ref,
        comparison.raceClass,
        comparison.results.length,
        stageId: activeStage.supportsClass(comparison.raceClass.id)
            ? activeStage.id
            : null,
      ),
    );
  }

  bool _canLoadMoreClassResults(
    WidgetRef ref,
    ResultClass raceClass,
    int loadedCount, {
    String? stageId,
  }) {
    final currentLimit = stageId == null
        ? ref.read(
            raceResultsLimitProvider((eventId: eventId, classId: raceClass.id)),
          )
        : ref.read(
            stageResultsLimitProvider((
              eventId: eventId,
              stageId: stageId,
              classId: raceClass.id,
            )),
          );
    if (loadedCount < currentLimit) return false;
    return raceClass.resultCount <= 0 || loadedCount < raceClass.resultCount;
  }

  void _loadAllResultsForSearch(
    WidgetRef ref,
    List<String> comparisonClassIds,
  ) {
    final classIds = {activeClass.id, ...comparisonClassIds};
    for (final raceClass in classes.where(
      (raceClass) => classIds.contains(raceClass.id),
    )) {
      if (raceClass.resultCount <= 0) continue;
      final useActiveStage = activeStage.supportsClass(raceClass.id);
      final currentLimit = useActiveStage
          ? ref.read(
              stageResultsLimitProvider((
                eventId: eventId,
                stageId: activeStage.id,
                classId: raceClass.id,
              )),
            )
          : ref.read(
              raceResultsLimitProvider((
                eventId: eventId,
                classId: raceClass.id,
              )),
            );
      if (currentLimit >= raceClass.resultCount) continue;
      if (useActiveStage) {
        ref
                .read(
                  stageResultsLimitProvider((
                    eventId: eventId,
                    stageId: activeStage.id,
                    classId: raceClass.id,
                  )).notifier,
                )
                .state =
            raceClass.resultCount;
      } else {
        ref
                .read(
                  raceResultsLimitProvider((
                    eventId: eventId,
                    classId: raceClass.id,
                  )).notifier,
                )
                .state =
            raceClass.resultCount;
      }
    }
  }

  void _loadMoreClassResults(
    WidgetRef ref,
    ResultClass raceClass,
    int loadedCount, {
    String? stageId,
  }) {
    final currentLimit = stageId == null
        ? ref.read(
            raceResultsLimitProvider((eventId: eventId, classId: raceClass.id)),
          )
        : ref.read(
            stageResultsLimitProvider((
              eventId: eventId,
              stageId: stageId,
              classId: raceClass.id,
            )),
          );
    if (loadedCount < currentLimit) return;
    if (raceClass.resultCount > 0 && loadedCount >= raceClass.resultCount) {
      return;
    }
    if (stageId == null) {
      ref
              .read(
                raceResultsLimitProvider((
                  eventId: eventId,
                  classId: raceClass.id,
                )).notifier,
              )
              .state =
          currentLimit + raceResultsPageSize;
    } else {
      ref
              .read(
                stageResultsLimitProvider((
                  eventId: eventId,
                  stageId: stageId,
                  classId: raceClass.id,
                )).notifier,
              )
              .state =
          currentLimit + raceResultsPageSize;
    }
  }

  Future<ResultDistributionData?> _loadFullDistributionData({
    required WidgetRef ref,
    required List<SplitDef> primarySplitDefs,
    required List<SplitOption> visibleSplits,
    required List<String> comparisonClassIds,
    required int? relayLegNumber,
    required List<int> relayComparisonLegNumbers,
    required bool isBiathlonSplit,
    required String? activeSplitId,
    required SplitRangeSelection? splitRange,
    required ResultSortMode sortMode,
    required String biathlonSortKey,
    _RegressionMeasure? comparisonTarget,
    required String? linkedAthleteId,
    required String? linkedClubName,
    required String? linkedTeamName,
    required Set<String> favoriteAthleteIds,
  }) async {
    final repository = ref.read(resultsRepositoryProvider);
    final rawPrimaryResults = await repository.fetchStageResults(
      eventId,
      activeStage.id,
      activeClass.id,
    );
    final primaryResults = relayLegNumber == null
        ? rawPrimaryResults
        : relayLegRaceResults(rawPrimaryResults, relayLegNumber);
    final primaryClass = relayLegNumber == null
        ? activeClass
        : _relayLegClass(activeClass, relayLegNumber, primaryResults.length);
    final comparisons = relayLegNumber == null
        ? await _fetchFullComparisonData(
            ref,
            primarySplitDefs,
            comparisonClassIds,
          )
        : [
            for (final legNumber in relayComparisonLegNumbers)
              _ComparisonRows(
                raceClass: _relayLegClass(
                  activeClass,
                  legNumber,
                  rawPrimaryResults.length,
                ),
                sourceClassId: activeClass.id,
                results: relayLegRaceResults(rawPrimaryResults, legNumber),
              ),
          ];
    final tableRows = _buildTableRows(
      primaryClass: primaryClass,
      primaryResults: primaryResults,
      comparisons: comparisons,
      linkedAthleteId: linkedAthleteId,
      linkedClubName: linkedClubName,
      linkedTeamName: linkedTeamName,
      favoriteAthleteIds: favoriteAthleteIds,
    );
    if (tableRows.isEmpty) return null;
    if (isBiathlonSplit && !BiathlonTable.hasBiathlonData(tableRows)) {
      return null;
    }
    return _distributionData(
      tableRows: tableRows,
      analysisClassId: primaryClass.id,
      visibleSplits: visibleSplits,
      isBiathlonSplit: isBiathlonSplit,
      activeSplitId: activeSplitId,
      splitRange: splitRange,
      sortMode: sortMode,
      biathlonSortKey: biathlonSortKey,
      comparisonTarget: comparisonTarget,
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
            final useActiveStage = activeStage.supportsClass(raceClass.id);
            final splitDefs = useActiveStage
                ? await ref.read(
                    stageSplitDefsProvider((
                      eventId: eventId,
                      stageId: activeStage.id,
                      classId: raceClass.id,
                    )).future,
                  )
                : await ref.read(
                    splitDefsProvider((
                      eventId: eventId,
                      classId: raceClass.id,
                    )).future,
                  );
            if (_splitSignature(splitDefs) != primarySignature) return null;
            final results = useActiveStage
                ? await repository.fetchStageResults(
                    eventId,
                    activeStage.id,
                    raceClass.id,
                  )
                : await repository.fetchResults(eventId, raceClass.id);
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

      final useActiveStage = activeStage.supportsClass(raceClass.id);
      final splitDefs = useActiveStage
          ? ref.watch(
              stageSplitDefsProvider((
                eventId: eventId,
                stageId: activeStage.id,
                classId: raceClass.id,
              )),
            )
          : ref.watch(
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

      final results = useActiveStage
          ? ref.watch(
              stageResultsProvider((
                eventId: eventId,
                stageId: activeStage.id,
                classId: raceClass.id,
              )),
            )
          : ref.watch(
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
    required ResultClass primaryClass,
    required List<RaceResult> primaryResults,
    required List<_ComparisonRows> comparisons,
    String? linkedAthleteId,
    String? linkedClubName,
    String? linkedTeamName,
    Set<String> favoriteAthleteIds = const <String>{},
  }) {
    final hasComparison = comparisons.isNotEmpty;
    final rows = [
      for (final result in primaryResults)
        ResultTableRow(
          result: result,
          classId: primaryClass.id,
          sourceClassId: activeClass.id,
          className: primaryClass.name,
          color: hasComparison ? _classColor(0) : null,
          originalPlacementLabel: '',
          highlight: resultHighlightFor(
            result,
            linkedAthleteId: linkedAthleteId,
            linkedClubName: linkedClubName,
            linkedTeamName: linkedTeamName,
            favoriteAthleteIds: favoriteAthleteIds,
          ),
          isCurrentAthlete: _isCurrentAthlete(result, linkedAthleteId),
        ),
    ];

    for (var i = 0; i < comparisons.length; i++) {
      final comparison = comparisons[i];
      for (final result in comparison.results) {
        rows.add(
          ResultTableRow(
            result: result,
            classId: comparison.raceClass.id,
            sourceClassId: comparison.sourceClassId,
            className: comparison.raceClass.name,
            color: _classColor(i + 1),
            originalPlacementLabel: '',
            highlight: resultHighlightFor(
              result,
              linkedAthleteId: linkedAthleteId,
              linkedClubName: linkedClubName,
              linkedTeamName: linkedTeamName,
              favoriteAthleteIds: favoriteAthleteIds,
            ),
            isCurrentAthlete: _isCurrentAthlete(result, linkedAthleteId),
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
        final storedRank = row.result.relayOverallRank ?? row.result.finishRank;
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

bool _isCurrentAthlete(RaceResult result, String? linkedAthleteId) {
  final athleteId = result.athleteId?.trim();
  final currentAthleteId = linkedAthleteId?.trim();
  return athleteId != null &&
      athleteId.isNotEmpty &&
      currentAthleteId != null &&
      athleteId == currentAthleteId;
}

/// Builds the split analysis for one result group. Each split uses its own leg
/// time, while the final rank is calculated from the group's finish times.
ResultSplitAnalysisData? buildResultSplitAnalysis(
  Iterable<RaceResult> results, {
  Iterable<SplitOption>? visibleSplits,
}) {
  final finished = results.where((result) {
    final totalMs = result.totalMs;
    return result.isFinished && totalMs != null && totalMs > 0;
  }).toList();
  if (finished.length < 2) return null;

  final finishTimes = {
    for (final result in finished) result.id: result.totalMs!,
  };
  final finishRanks = _ranksByTime(finishTimes);
  final splitDefinitions = <String, SplitValue>{};
  final visibleById = visibleSplits == null
      ? null
      : {for (final split in visibleSplits) split.id: split};

  for (final result in finished) {
    for (final split in result.splitValues.values) {
      if (visibleById != null && !visibleById.containsKey(split.id)) continue;
      if (_isExcludedFromSplitAnalysis(split, visibleById?[split.id])) continue;
      final legMs = effectiveSplitLegMs(result, split.id);
      if (legMs == null || legMs <= 0) continue;
      splitDefinitions.putIfAbsent(split.id, () => split);
    }
  }

  final points = <ResultSplitAnalysisPoint>[];
  for (final split in splitDefinitions.values) {
    final splitTimes = <String, int>{
      for (final result in finished)
        if (effectiveSplitLegMs(result, split.id) case final legMs?
            when legMs > 0)
          result.id: legMs,
    };
    if (splitTimes.length < 2) continue;

    final splitRanks = _ranksByTime(splitTimes);
    final timeSamples = <(int, int)>[];
    final rankSamples = <(int, int)>[];
    for (final entry in splitTimes.entries) {
      final finishTime = finishTimes[entry.key];
      final finishRank = finishRanks[entry.key];
      final splitRank = splitRanks[entry.key];
      if (finishTime == null || finishRank == null || splitRank == null) {
        continue;
      }
      timeSamples.add((entry.value, finishTime));
      rankSamples.add((splitRank, finishRank));
    }

    final timeCorrelation = _pearsonCorrelation(timeSamples);
    final rankCorrelation = _pearsonCorrelation(rankSamples);
    if (timeCorrelation == null || rankCorrelation == null) continue;
    points.add(
      ResultSplitAnalysisPoint(
        splitId: split.id,
        label: visibleById?[split.id]?.label ?? split.label,
        sort: visibleById?[split.id]?.sort ?? split.sort,
        timeCorrelation: timeCorrelation.abs(),
        rankCorrelation: rankCorrelation.abs(),
        sampleSize: timeSamples.length,
      ),
    );
  }

  points.sort((left, right) {
    final bySort = left.sort.compareTo(right.sort);
    return bySort != 0 ? bySort : left.label.compareTo(right.label);
  });
  final preferredExitRounds = <int>{};
  for (final point in points) {
    final round =
        _shootingExitRound(point.label) ??
        _shootingExitRound(splitDefinitions[point.splitId]?.label ?? '');
    if (round != null) preferredExitRounds.add(round);
  }
  final visiblePoints = points.where((point) {
    final round =
        _shootingOutRound(point.label) ??
        _shootingOutRound(splitDefinitions[point.splitId]?.label ?? '');
    return round == null || !preferredExitRounds.contains(round);
  }).toList();
  return visiblePoints.length < 2
      ? null
      : ResultSplitAnalysisData(points: visiblePoints);
}

int? _shootingExitRound(String label) {
  final match = RegExp(
    r'^US0*(\d+)$',
    caseSensitive: false,
  ).firstMatch(label.trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _shootingOutRound(String label) {
  final match = RegExp(
    r'^UTS0*(\d+)$',
    caseSensitive: false,
  ).firstMatch(label.trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}

bool _isExcludedFromSplitAnalysis(SplitValue split, SplitOption? visible) {
  final kind = split.kind.trim().toLowerCase();
  final visibleKind = visible?.kind.trim().toLowerCase();
  return split.id == _biathlonSplitId ||
      split.id == relayLegFinishSplitId ||
      kind == 'analysis' ||
      kind == 'finish' ||
      visibleKind == 'analysis' ||
      visibleKind == 'finish';
}

Map<String, int> _ranksByTime(Map<String, int> times) {
  final entries = times.entries.toList()
    ..sort((left, right) {
      final byTime = left.value.compareTo(right.value);
      return byTime != 0 ? byTime : left.key.compareTo(right.key);
    });
  final ranks = <String, int>{};
  int? previousTime;
  var previousRank = 0;
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final rank = previousTime == entry.value ? previousRank : index + 1;
    ranks[entry.key] = rank;
    previousTime = entry.value;
    previousRank = rank;
  }
  return ranks;
}

double? _pearsonCorrelation(List<(int, int)> samples) {
  if (samples.length < 2) return null;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXX = 0.0;
  var sumYY = 0.0;
  var sumXY = 0.0;
  for (final sample in samples) {
    final x = sample.$1.toDouble();
    final y = sample.$2.toDouble();
    sumX += x;
    sumY += y;
    sumXX += x * x;
    sumYY += y * y;
    sumXY += x * y;
  }
  final count = samples.length.toDouble();
  final xVariance = count * sumXX - sumX * sumX;
  final yVariance = count * sumYY - sumY * sumY;
  if (xVariance <= 0 || yVariance <= 0) return null;
  final correlation =
      (count * sumXY - sumX * sumY) / math.sqrt(xVariance * yVariance);
  if (!correlation.isFinite) return null;
  return correlation.clamp(-1.0, 1.0).toDouble();
}

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
  const _CompareSelection({
    required this.classId,
    required this.resultId,
    this.relayLegNumber,
  });

  static _CompareSelection? tryParse({
    String? classId,
    String? resultId,
    int? relayLegNumber,
  }) {
    if (classId == null ||
        classId.trim().isEmpty ||
        resultId == null ||
        resultId.trim().isEmpty) {
      return null;
    }
    return _CompareSelection(
      classId: classId,
      resultId: resultId,
      relayLegNumber: relayLegNumber,
    );
  }

  final String classId;
  final String resultId;
  final int? relayLegNumber;
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
  const _ComparisonRows({
    required this.raceClass,
    required this.results,
    this.sourceClassId,
  });

  final ResultClass raceClass;
  final List<RaceResult> results;
  final String? sourceClassId;
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

ResultClass _relayLegClass(ResultClass source, int legNumber, int resultCount) {
  return ResultClass(
    id: '${source.id}::relay-leg-$legNumber',
    name: 'Etappe $legNumber',
    resultCount: resultCount,
    participantCount: resultCount,
    etappeUid: source.etappeUid,
    etappeName: source.etappeName,
    etappeKm: source.etappeKm,
    primaryStageId: source.primaryStageId,
  );
}

class _MobileClassMenu extends StatelessWidget {
  const _MobileClassMenu({
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
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('mobile-class-menu-button'),
      tooltip: 'Vis klasser',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 36),
      onPressed: () => _open(context),
      icon: const Icon(Icons.chevron_right),
    );
  }

  Future<void> _open(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Lukk klasser',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) {
        final width = MediaQuery.sizeOf(dialogContext).width * 0.7;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const Key('mobile-class-panel'),
            width: width,
            height: MediaQuery.sizeOf(dialogContext).height,
            child: SafeArea(
              child: Material(
                type: MaterialType.transparency,
                child: _ClassSidebar(
                  eventId: eventId,
                  classes: classes,
                  selectedClassId: selectedClassId,
                  activeSplitDefs: activeSplitDefs,
                  collapsed: false,
                  showCollapseToggle: false,
                  onCollapseChanged: (_) {},
                  onChanged: (value) {
                    Navigator.of(dialogContext).pop();
                    onChanged(value);
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    );
  }
}

class _ClassSidebar extends ConsumerWidget {
  const _ClassSidebar({
    required this.eventId,
    required this.classes,
    required this.selectedClassId,
    required this.activeSplitDefs,
    required this.collapsed,
    this.showCollapseToggle = true,
    this.fillAvailableHeight = true,
    required this.onCollapseChanged,
    required this.onChanged,
  });

  final String eventId;
  final List<ResultClass> classes;
  final String selectedClassId;
  final AsyncValue<List<SplitDef>> activeSplitDefs;
  final bool collapsed;
  final bool showCollapseToggle;
  final bool fillAvailableHeight;
  final ValueChanged<bool> onCollapseChanged;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final sortedClasses = sortResultClassesByDistance(classes);
    final disciplineLabel = combinedDisciplineLabel(sortedClasses);
    final comparisonClassIds = ref.watch(comparisonClassIdsProvider);
    final activeSplitDefData = activeSplitDefs.asData?.value;
    final activeSignature = activeSplitDefData == null
        ? null
        : _splitSignature(activeSplitDefData);
    final classList = ListView.separated(
      shrinkWrap: !fillAvailableHeight,
      physics: fillAvailableHeight
          ? null
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: sortedClasses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final raceClass = sortedClasses[index];
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
    );
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
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                if (!collapsed)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          disciplineLabel ?? l10n.classes,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (disciplineLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.classes,
                            style: TextStyle(
                              color: palette.mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (showCollapseToggle)
                  IconButton(
                    key: const Key('classes-collapse-toggle'),
                    constraints: BoxConstraints(
                      minWidth: collapsed ? 42 : 48,
                      minHeight: 48,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: collapsed ? 'Vis klasser' : 'Minimer klasser',
                    onPressed: () => onCollapseChanged(!collapsed),
                    icon: Icon(
                      collapsed ? Icons.chevron_right : Icons.chevron_left,
                    ),
                  ),
              ],
            ),
          ),
          if (!collapsed)
            if (fillAvailableHeight) Expanded(child: classList) else classList,
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
                '${raceClass.athleteCount}',
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

class _CompetitionStageSelector extends StatelessWidget {
  const _CompetitionStageSelector({
    required this.stages,
    required this.selectedStageId,
    required this.onChanged,
  });

  final List<CompetitionStage> stages;
  final String selectedStageId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedStageId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Konkurranseledd'),
      items: [
        for (final stage in stages)
          DropdownMenuItem(value: stage.id, child: Text(stage.name)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ResultTitle extends StatelessWidget {
  const _ResultTitle({
    required this.event,
    required this.raceClass,
    required this.stage,
    this.leading,
  });

  final ResultEvent? event;
  final ResultClass raceClass;
  final CompetitionStage stage;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final subtitle = [
      raceClass.name,
      stage.name,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, SizedBox(width: compact ? 2 : 6)],
        Expanded(
          child: Text(
            subtitle.isEmpty ? event?.name ?? raceClass.name : subtitle,
            key: const Key('result-body-heading'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 20 : 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _StickyResultClassHeader extends StatelessWidget {
  const _StickyResultClassHeader({
    required this.raceClass,
    required this.stage,
    required this.leading,
  });

  final ResultClass raceClass;
  final CompetitionStage stage;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final label = [
      raceClass.name,
      stage.name,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    return ColoredBox(
      color: context.palette.panel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Expanded(
              child: Text(
                label,
                key: const Key('sticky-result-class-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSearchField extends StatelessWidget {
  const _ResultSearchField({
    super.key,
    required this.initialQuery,
    required this.onChanged,
  });

  final String initialQuery;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('result-search-field'),
      initialValue: initialQuery,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).searchResults,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}

class _SplitAndInfoRow extends StatelessWidget {
  const _SplitAndInfoRow({
    required this.sticky,
    required this.splitOptions,
    required this.rangeSplitOptions,
    required this.selectedSplitId,
    required this.splitRange,
    required this.distributionData,
    required this.loadFullDistributionData,
    required this.onChooseFromResultsList,
    required this.searchField,
    required this.onSplitChanged,
    required this.onRangeToggle,
    required this.onRangeFromChanged,
    required this.onRangeToChanged,
    required this.onIndependentChanged,
    required this.onIncludedSplitsChanged,
  });

  final bool sticky;
  final List<SplitOption> splitOptions;
  final List<SplitOption> rangeSplitOptions;
  final String? selectedSplitId;
  final SplitRangeSelection? splitRange;
  final ResultDistributionData? distributionData;
  final Future<ResultDistributionData?> Function() loadFullDistributionData;
  final VoidCallback onChooseFromResultsList;
  final Widget searchField;
  final ValueChanged<String?> onSplitChanged;
  final VoidCallback onRangeToggle;
  final ValueChanged<String?> onRangeFromChanged;
  final ValueChanged<String?> onRangeToChanged;
  final ValueChanged<bool> onIndependentChanged;
  final ValueChanged<List<String>> onIncludedSplitsChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
          onIndependentChanged: onIndependentChanged,
          onIncludedSplitsChanged: onIncludedSplitsChanged,
        );
        final distributionButton = ResultDistributionButton(
          data: distributionData,
          loadData: loadFullDistributionData,
          loadingLabel: AppLocalizations.of(context).loadingResults,
          errorTitle: AppLocalizations.of(context).couldNotReadResults,
          onSplitSelected: (splitId) => onSplitChanged(splitId),
          onChooseFromResultsList: onChooseFromResultsList,
        );

        if (sticky) {
          return Row(
            key: const Key('sticky-split-controls'),
            children: [
              Expanded(child: splitSelector),
              const SizedBox(width: 10),
              distributionButton,
            ],
          );
        }

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
              searchField,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
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
                  searchField,
                ],
              ),
            ),
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
      key: const Key('results-info-card'),
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
