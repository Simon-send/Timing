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
import 'athlete_summary_panel.dart';

class AthleteDetailPage extends ConsumerStatefulWidget {
  const AthleteDetailPage({
    super.key,
    required this.eventId,
    required this.classId,
    required this.resultId,
    this.selectedSplitId,
    this.compareWithResultId,
  });

  final String eventId;
  final String classId;
  final String resultId;
  final String? selectedSplitId;
  final String? compareWithResultId;

  @override
  ConsumerState<AthleteDetailPage> createState() => _AthleteDetailPageState();
}

class _AthleteDetailPageState extends ConsumerState<AthleteDetailPage> {
  HeadToHeadDisplayMode _comparisonMode = HeadToHeadDisplayMode.time;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(
      raceResultProvider((
        eventId: widget.eventId,
        classId: widget.classId,
        resultId: widget.resultId,
      )),
    );
    final classResults = ref.watch(
      raceResultsProvider((eventId: widget.eventId, classId: widget.classId)),
    );
    final splitDefs = ref.watch(
      splitDefsProvider((eventId: widget.eventId, classId: widget.classId)),
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
            splitId: widget.selectedSplitId,
          ),
        ),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: const [AccountMenu(), SettingsMenu()],
      child: result.when(
        loading: () =>
            ShellPanel(child: LoadingState(label: l10n.loadingResults)),
        error: (error, _) => ShellPanel(
          child: ErrorState(title: l10n.couldNotReadResults, error: error),
        ),
        data: (result) {
          if (result == null) {
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
              ),
            );
          }
          final placementLabel = _placementLabel(
            result,
            classResults.asData?.value,
          );
          final publicSplitIds = _publicSplitIds(
            splitDefs.asData?.value,
            result,
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final summary = AthleteSummaryPanel(
                result: result,
                placementLabel: placementLabel,
                isComparing: widget.compareWithResultId != null,
                onComparePressed: _chooseComparisonOpponent,
              );
              if (widget.compareWithResultId != null) {
                final details = _headToHeadPanel(
                  result: result,
                  classResults: classResults,
                  publicSplitIds: publicSplitIds,
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

              final details = AthleteSplitsPanel(
                result: result,
                classResults:
                    classResults.asData?.value ?? const <RaceResult>[],
                publicSplitIds: publicSplitIds,
                splitDefs: splitDefs.asData?.value ?? const <SplitDef>[],
                onSplitSelected: _openResultsSplit,
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

  Widget _headToHeadPanel({
    required RaceResult result,
    required AsyncValue<List<RaceResult>> classResults,
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
        ),
      );
    }
    final results = classResults.asData?.value ?? const <RaceResult>[];
    final selectedResultId = widget.compareWithResultId;

    return AthleteHeadToHeadPanel(
      baseResult: result,
      results: results,
      publicSplitIds: publicSplitIds,
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
        splitId: widget.selectedSplitId,
        compareBaseClassId: widget.classId,
        compareBaseResultId: widget.resultId,
      ),
    );
  }

  void _closeComparison() {
    context.go(
      athleteLocation(
        eventId: widget.eventId,
        classId: widget.classId,
        resultId: widget.resultId,
        splitId: widget.selectedSplitId,
      ),
    );
  }

  void _openResultsSplit(String splitId) {
    ref.read(splitRangeSelectionProvider.notifier).state = null;
    ref
        .read(settingsControllerProvider.notifier)
        .setDefaultClass(widget.classId);
    ref.read(settingsControllerProvider.notifier).setPreferredSplit(splitId);
    context.go(
      resultsLocation(
        eventId: widget.eventId,
        classId: widget.classId,
        splitId: splitId,
      ),
    );
  }
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
    return status.isEmpty ? 'DNF' : status;
  }
  if (result.finishRank != null && result.finishRank! > 0) {
    return result.finishRank.toString();
  }

  final results = classResults;
  if (results == null || result.totalMs == null) {
    return result.placementLabel;
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
    if (current.id == result.id) return '$rank';
    previousTime = time;
    previousRank = rank;
  }

  return result.placementLabel;
}
