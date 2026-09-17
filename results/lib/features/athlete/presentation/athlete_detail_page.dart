import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/presentation/account_menu.dart';
import '../../results/domain/race_result.dart';
import '../../results/domain/split_def.dart';
import '../../results/presentation/result_locations.dart';
import '../../settings/presentation/settings_menu.dart';
import 'athlete_head_to_head_panel.dart';
import 'athlete_splits_panel.dart';
import 'athlete_stage_results_panel.dart';
import 'athlete_summary_panel.dart';
import 'result_detail_extensions.dart';

typedef _RelayRankResultsRequest = ({
  String eventId,
  String classId,
  String? stageId,
});

final _relayRankResultsProvider = FutureProvider.autoDispose
    .family<List<RaceResult>, _RelayRankResultsRequest>((ref, request) {
      ref.watch(appDataRefreshProvider);
      final repository = ref.watch(resultsRepositoryProvider);
      final stageId = request.stageId;
      if (stageId == null) {
        return repository.fetchResults(request.eventId, request.classId);
      }
      return repository.fetchStageResults(
        request.eventId,
        stageId,
        request.classId,
      );
    });

class AthleteDetailPage extends ConsumerStatefulWidget {
  const AthleteDetailPage({
    super.key,
    required this.eventId,
    required this.classId,
    required this.resultId,
    this.stageId,
    this.selectedSplitId,
    this.selectedSplitRange,
    this.relayLegNumber,
    this.compareWithResultId,
    this.compareWithRelayLegNumber,
  });

  final String eventId;
  final String classId;
  final String resultId;
  final String? stageId;
  final String? selectedSplitId;
  final SplitRangeSelection? selectedSplitRange;
  final int? relayLegNumber;
  final String? compareWithResultId;
  final int? compareWithRelayLegNumber;

  @override
  ConsumerState<AthleteDetailPage> createState() => _AthleteDetailPageState();
}

class _AthleteDetailPageState extends ConsumerState<AthleteDetailPage> {
  HeadToHeadDisplayMode _comparisonMode = HeadToHeadDisplayMode.time;
  bool _isUpdatingFavorite = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = widget.stageId == null
        ? ref.watch(
            raceResultProvider((
              eventId: widget.eventId,
              classId: widget.classId,
              resultId: widget.resultId,
            )),
          )
        : ref.watch(
            stageResultProvider((
              eventId: widget.eventId,
              stageId: widget.stageId!,
              classId: widget.classId,
              resultId: widget.resultId,
            )),
          );
    final classResults = widget.stageId == null
        ? ref.watch(
            raceResultsProvider((
              eventId: widget.eventId,
              classId: widget.classId,
            )),
          )
        : ref.watch(
            stageResultsProvider((
              eventId: widget.eventId,
              stageId: widget.stageId!,
              classId: widget.classId,
            )),
          );
    final splitDefs = widget.stageId == null
        ? ref.watch(
            splitDefsProvider((
              eventId: widget.eventId,
              classId: widget.classId,
            )),
          )
        : ref.watch(
            stageSplitDefsProvider((
              eventId: widget.eventId,
              stageId: widget.stageId!,
              classId: widget.classId,
            )),
          );

    return AppShell(
      title: l10n.athleteDetails,
      subtitle: widget.resultId,
      leading: IconButton.outlined(
        tooltip: l10n.backToResults,
        onPressed: () => context.go(
          resultsLocation(
            eventId: widget.eventId,
            classId: widget.classId,
            stageId: widget.stageId,
            relayLegNumber: widget.relayLegNumber,
            splitId: widget.selectedSplitId,
            splitRange: widget.selectedSplitRange,
          ),
        ),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: const [AccountMenu(), SettingsMenu()],
      child: result.when(
        loading: () =>
            ShellPanel(child: LoadingState(label: l10n.loadingResults)),
        error: (error, _) => ShellPanel(
          child: ErrorState(
            title: l10n.couldNotReadResults,
            error: error,
            onRetry: () => refreshAppData(ref),
          ),
        ),
        data: (rawResult) {
          if (rawResult == null) {
            return ShellPanel(
              child: EmptyState(
                title: l10n.noResultsTitle,
                message: l10n.noResultsMessage,
              ),
            );
          }
          if (splitDefs.isLoading && splitDefs.asData?.value == null) {
            return ShellPanel(child: LoadingState(label: l10n.loadingResults));
          }
          if (splitDefs.hasError && splitDefs.asData?.value == null) {
            return ShellPanel(
              child: ErrorState(
                title: l10n.couldNotReadResults,
                error: splitDefs.error!,
                onRetry: () => refreshAppData(ref),
              ),
            );
          }
          final rawClassResults = classResults.asData?.value;
          final result = widget.relayLegNumber == null
              ? rawResult
              : relayLegRaceResult(rawResult, widget.relayLegNumber!);
          if (result == null) {
            return const ShellPanel(
              child: EmptyState(
                title: 'Etappen mangler',
                message:
                    'Fant ingen passeringer eller utøver for denne etappen.',
              ),
            );
          }
          final displayedClassResults =
              widget.relayLegNumber == null || rawClassResults == null
              ? rawClassResults
              : relayLegRaceResults(rawClassResults, widget.relayLegNumber!);
          final isRelayTeamDetail =
              widget.relayLegNumber == null &&
              (rawResult.entrant?.kind == ResultEntrantKind.team ||
                  rawResult.relayMembers.isNotEmpty);
          final relayRankResults = isRelayTeamDetail
              ? ref
                    .watch(
                      _relayRankResultsProvider((
                        eventId: widget.eventId,
                        classId: widget.classId,
                        stageId: widget.stageId,
                      )),
                    )
                    .asData
                    ?.value
              : null;
          final extensionClassResults = isRelayTeamDetail
              ? relayRankResults ?? const <RaceResult>[]
              : displayedClassResults ?? const <RaceResult>[];
          final detailSplitDefs = widget.relayLegNumber == null
              ? splitDefs.asData?.value ?? const <SplitDef>[]
              : relayLegSplitDefs(
                  splitDefs.asData?.value ?? const <SplitDef>[],
                  widget.relayLegNumber!,
                  displayedClassResults ?? [result],
                );
          final placementLabel = _placementLabel(result, displayedClassResults);
          final publicSplitIds = _publicSplitIds(detailSplitDefs, result);
          final stageResultsRequest = (
            eventId: widget.eventId,
            classId: widget.classId,
            athleteId: result.athleteId,
            athleteName: result.name,
          );
          final canShowStageResults =
              result.relayLegNumber != null ||
              result.entrant?.kind != ResultEntrantKind.team;
          final athleteStageResults = canShowStageResults
              ? ref.watch(athleteStageResultsProvider(stageResultsRequest))
              : null;
          final user = ref.watch(authStateProvider).asData?.value;
          final favoriteAthleteIds =
              ref.watch(favoriteAthleteIdsProvider).asData?.value ??
              const <String>{};
          final athleteId = result.athleteId?.trim();
          final isFavorite =
              athleteId != null &&
              athleteId.isNotEmpty &&
              favoriteAthleteIds.contains(athleteId);
          return LayoutBuilder(
            builder: (context, constraints) {
              final summary = AthleteSummaryPanel(
                result: result,
                placementLabel: placementLabel,
                isComparing: widget.compareWithResultId != null,
                onComparePressed: _chooseComparisonOpponent,
                isFavorite: isFavorite,
                isFavoriteUpdating: _isUpdatingFavorite,
                onFavoritePressed:
                    user != null && athleteId != null && athleteId.isNotEmpty
                    ? () => _setFavorite(
                        uid: user.uid,
                        athleteId: athleteId,
                        athleteName: result.name,
                        isFavorite: !isFavorite,
                      )
                    : null,
              );
              if (widget.compareWithResultId != null) {
                final headToHead = _headToHeadPanel(
                  result: result,
                  classResults: classResults,
                  displayedClassResults: displayedClassResults,
                  publicSplitIds: publicSplitIds,
                );
                final details = result.relayLegNumber == null
                    ? headToHead
                    : Column(
                        children: [
                          ResultDetailExtensions(
                            result: result,
                            classResults: extensionClassResults,
                            onSplitSelected: _openResultsSplit,
                          ),
                          Expanded(child: headToHead),
                        ],
                      );
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      summary,
                      const SizedBox(height: 12),
                      Expanded(child: details),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 380, child: summary),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                );
              }

              final splits = AthleteSplitsPanel(
                result: result,
                classResults: displayedClassResults ?? const <RaceResult>[],
                publicSplitIds: publicSplitIds,
                splitDefs: detailSplitDefs,
                onSplitSelected: _openResultsSplit,
              );
              final details = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ResultDetailExtensions(
                    result: result,
                    classResults: extensionClassResults,
                    onSplitSelected: _openResultsSplit,
                  ),
                  if (athleteStageResults != null) ...[
                    AthleteStageResultsSection(
                      athleteName: result.name,
                      stageResults: athleteStageResults,
                      onStageSelected: (stageResult) {
                        context.go(
                          athleteLocation(
                            eventId: widget.eventId,
                            classId: widget.classId,
                            resultId: stageResult.athleteResult.detailResultId,
                            stageId: stageResult.stage.id,
                            relayLegNumber: stageResult.relayLegNumber,
                          ),
                        );
                      },
                      onRetry: () => ref.invalidate(
                        athleteStageResultsProvider(stageResultsRequest),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  splits,
                ],
              );
              final content = constraints.maxWidth < 760
                  ? Column(
                      children: [summary, const SizedBox(height: 12), details],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 380, child: summary),
                        const SizedBox(width: 12),
                        Expanded(child: details),
                      ],
                    );

              return SingleChildScrollView(primary: false, child: content);
            },
          );
        },
      ),
    );
  }

  Future<void> _setFavorite({
    required String uid,
    required String athleteId,
    required String athleteName,
    required bool isFavorite,
  }) async {
    if (_isUpdatingFavorite) return;
    setState(() => _isUpdatingFavorite = true);
    try {
      await ref
          .read(favoriteAthletesRepositoryProvider)
          .setFavorite(
            uid: uid,
            athleteId: athleteId,
            athleteName: athleteName,
            isFavorite: isFavorite,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunne ikke oppdatere stjernemerkingen: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingFavorite = false);
    }
  }

  Widget _headToHeadPanel({
    required RaceResult result,
    required AsyncValue<List<RaceResult>> classResults,
    required List<RaceResult>? displayedClassResults,
    required Set<String> publicSplitIds,
  }) {
    if (classResults.isLoading && classResults.asData?.value == null) {
      return const ShellPanel(child: LoadingState(label: 'Laster utovere'));
    }
    if (classResults.hasError && classResults.asData?.value == null) {
      return ShellPanel(
        child: ErrorState(
          title: 'Kunne ikke lese utovere',
          error: classResults.error!,
          onRetry: () => refreshAppData(ref),
        ),
      );
    }
    final baseResults = displayedClassResults ?? const <RaceResult>[];
    final rawResults = classResults.asData?.value ?? const <RaceResult>[];
    final opponentLegNumber = widget.compareWithRelayLegNumber;
    final results =
        opponentLegNumber == null || opponentLegNumber == widget.relayLegNumber
        ? baseResults
        : _mergeResults(
            baseResults,
            relayLegRaceResults(rawResults, opponentLegNumber),
          );
    final selectedResultId = widget.compareWithResultId == null
        ? null
        : opponentLegNumber == null
        ? widget.compareWithResultId
        : relayLegViewResultId(widget.compareWithResultId!, opponentLegNumber);
    final comparisonSplitIds =
        opponentLegNumber != null && opponentLegNumber != widget.relayLegNumber
        ? <String>{relayLegFinishSplitId}
        : publicSplitIds;

    return AthleteHeadToHeadPanel(
      baseResult: result,
      results: results,
      publicSplitIds: comparisonSplitIds,
      selectedResultId: selectedResultId,
      opponentPlacementLabel: _opponentPlacementLabel(
        selectedResultId,
        results,
      ),
      title: 'Head to head',
      showCloseButton: true,
      displayMode: _comparisonMode,
      onDisplayModeChanged: (value) {
        setState(() {
          _comparisonMode = value;
        });
      },
      onChangeOpponent: _chooseComparisonOpponent,
      onClose: _closeComparison,
      onSplitSelected: _openResultsSplit,
    );
  }

  void _chooseComparisonOpponent() {
    ref
        .read(settingsControllerProvider.notifier)
        .setDefaultClass(widget.classId);
    context.go(
      resultsLocation(
        eventId: widget.eventId,
        classId: widget.classId,
        stageId: widget.stageId,
        relayLegNumber: widget.relayLegNumber,
        splitId: widget.selectedSplitId,
        splitRange: widget.selectedSplitRange,
        compareBaseClassId: widget.classId,
        compareBaseResultId: widget.resultId,
        compareBaseRelayLegNumber: widget.relayLegNumber,
      ),
    );
  }

  void _closeComparison() {
    context.go(
      athleteLocation(
        eventId: widget.eventId,
        classId: widget.classId,
        resultId: widget.resultId,
        stageId: widget.stageId,
        relayLegNumber: widget.relayLegNumber,
        splitId: widget.selectedSplitId,
        splitRange: widget.selectedSplitRange,
      ),
    );
  }

  void _openResultsSplit(String splitId) {
    ref
        .read(settingsControllerProvider.notifier)
        .setDefaultClass(widget.classId);
    ref.read(settingsControllerProvider.notifier).setPreferredSplit(splitId);
    context.go(
      resultsLocation(
        eventId: widget.eventId,
        classId: widget.classId,
        stageId: widget.stageId,
        relayLegNumber: widget.relayLegNumber,
        splitId: splitId,
      ),
    );
  }
}

List<RaceResult> _mergeResults(
  Iterable<RaceResult> first,
  Iterable<RaceResult> second,
) {
  final byId = <String, RaceResult>{};
  for (final result in [...first, ...second]) {
    byId[result.id] = result;
  }
  return byId.values.toList(growable: false);
}

String? _opponentPlacementLabel(String? opponentId, List<RaceResult>? results) {
  if (opponentId == null || results == null) return null;
  for (final result in results) {
    if (result.id == opponentId) return _placementLabel(result, results);
  }
  return null;
}

Set<String> _publicSplitIds(List<SplitDef>? splitDefs, RaceResult result) {
  if (splitDefs == null) return const {};
  if (splitDefs.isEmpty) return result.splitValues.keys.toSet();
  return {
    for (final splitDef in splitDefs)
      if (splitDef.isPublic) splitDef.id,
  };
}

String _placementLabel(RaceResult result, List<RaceResult>? classResults) {
  if (!result.isFinished) {
    final status = result.status.trim();
    final placement = status.isEmpty ? 'DNF' : status;
    return _withRelayOverallRank(result, placement);
  }
  if (result.finishRank != null && result.finishRank! > 0) {
    return result.finishRank.toString();
  }

  final results = classResults;
  if (results == null || result.totalMs == null) {
    return _withRelayOverallRank(result, result.placementLabel);
  }

  final finished =
      results.where((item) => item.isFinished && item.totalMs != null).toList()
        ..sort((a, b) {
          final timeCompare = a.totalMs!.compareTo(b.totalMs!);
          if (timeCompare != 0) return timeCompare;
          final nameCompare = a.name.compareTo(b.name);
          if (nameCompare != 0) return nameCompare;
          return a.id.compareTo(b.id);
        });

  int? previousTime;
  int? previousRank;
  for (var i = 0; i < finished.length; i++) {
    final current = finished[i];
    final time = current.totalMs!;
    final rank = previousTime != null && time == previousTime
        ? previousRank!
        : i + 1;
    if (current.id == result.id) {
      return _withRelayOverallRank(result, '$rank');
    }
    previousTime = time;
    previousRank = rank;
  }

  return _withRelayOverallRank(result, result.placementLabel);
}

String _withRelayOverallRank(RaceResult result, String placement) {
  final overallRank = result.relayOverallRank;
  if (overallRank == null || overallRank <= 0) return placement;
  return '$placement($overallRank)';
}
