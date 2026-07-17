import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../domain/athlete_stage_result.dart';
import '../../results/domain/race_result.dart';

class AthleteStageResultsSection extends StatelessWidget {
  const AthleteStageResultsSection({
    super.key,
    required this.athleteName,
    required this.stageResults,
    required this.onRetry,
    required this.onStageSelected,
  });

  final String athleteName;
  final AsyncValue<List<AthleteStageResult>> stageResults;
  final VoidCallback onRetry;
  final ValueChanged<AthleteStageResult> onStageSelected;

  @override
  Widget build(BuildContext context) {
    return stageResults.when(
      skipLoadingOnReload: true,
      data: (results) {
        if (results.length < 2) return const SizedBox.shrink();
        return AthleteStageResultsPanel(
          athleteName: athleteName,
          stageResults: results,
          onStageSelected: onStageSelected,
        );
      },
      loading: () => const ShellPanel(
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Laster tider fra prolog og heat …')),
          ],
        ),
      ),
      error: (error, _) => ShellPanel(
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Kunne ikke hente tider fra de andre heatene.'),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onRetry, child: const Text('Prøv igjen')),
          ],
        ),
      ),
    );
  }
}

class AthleteStageResultsPanel extends StatelessWidget {
  const AthleteStageResultsPanel({
    super.key,
    required this.athleteName,
    required this.stageResults,
    required this.onStageSelected,
  });

  final String athleteName;
  final List<AthleteStageResult> stageResults;
  final ValueChanged<AthleteStageResult> onStageSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ShellPanel(
      child: Column(
        key: const Key('athlete-stage-results-panel'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Alle tider',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              OutlinedButton.icon(
                key: const Key('show-athlete-stage-result-lists'),
                onPressed: () => _showResultLists(context),
                icon: const Icon(Icons.table_rows_outlined),
                label: const Text('Vis alle resultatlister'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Prolog og alle heat der $athleteName har et registrert resultat.',
            style: TextStyle(color: palette.mutedText),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < stageResults.length; index++) ...[
            _StageTimeRow(
              stageResult: stageResults[index],
              onTap: () => onStageSelected(stageResults[index]),
            ),
            if (index < stageResults.length - 1)
              Divider(height: 1, color: palette.border),
          ],
        ],
      ),
    );
  }

  Future<void> _showResultLists(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => _AthleteStageResultListsDialog(
        athleteName: athleteName,
        stageResults: stageResults,
      ),
    );
  }
}

class _StageTimeRow extends StatelessWidget {
  const _StageTimeRow({required this.stageResult, required this.onTap});

  final AthleteStageResult stageResult;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final result = stageResult.athleteResult;
    final time = _resultTime(result);
    final placement = _placementFor(stageResult, result);
    final relayLeg = stageResult.relayLegNumber;
    return InkWell(
      key: Key('athlete-stage-${stageResult.stage.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(
              stageResult.stage.isQualification
                  ? Icons.timer_outlined
                  : Icons.flag_outlined,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stageResult.stage.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    [
                      if (relayLeg != null) 'Etappe $relayLeg',
                      if (placement.isNotEmpty) 'Plass $placement',
                      if (result.bib.isNotEmpty) 'Startnr. ${result.bib}',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              time,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AthleteStageResultListsDialog extends StatelessWidget {
  const _AthleteStageResultListsDialog({
    required this.athleteName,
    required this.stageResults,
  });

  final String athleteName;
  final List<AthleteStageResult> stageResults;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog.fullscreen(
      key: const Key('athlete-stage-result-lists-dialog'),
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          title: Text('Resultatlister · $athleteName'),
          leading: IconButton(
            tooltip: 'Lukk',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: stageResults.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _StageResultList(stageResult: stageResults[index]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageResultList extends StatelessWidget {
  const _StageResultList({required this.stageResult});

  final AthleteStageResult stageResult;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final relayLeg = stageResult.relayLegNumber;
    return ShellPanel(
      child: Column(
        key: Key('athlete-stage-result-list-${stageResult.stage.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stageResult.stage.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (relayLeg != null) ...[
            const SizedBox(height: 2),
            Text(
              'Resultatliste for etappe $relayLeg',
              style: TextStyle(color: palette.mutedText),
            ),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 42,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 54,
              horizontalMargin: 12,
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('PLASS')),
                DataColumn(label: Text('STARTNR.')),
                DataColumn(label: Text('UTØVER')),
                DataColumn(label: Text('KLUBB/LAG')),
                DataColumn(label: Text('TID'), numeric: true),
              ],
              rows: [
                for (final result in stageResult.results)
                  DataRow(
                    color: _isSelectedResult(stageResult, result)
                        ? WidgetStatePropertyAll(
                            palette.primary.withValues(alpha: 0.2),
                          )
                        : null,
                    cells: [
                      DataCell(Text(_placementFor(stageResult, result))),
                      DataCell(Text(result.bib.isEmpty ? '-' : result.bib)),
                      DataCell(
                        Text(
                          result.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text(_affiliation(result))),
                      DataCell(Text(_resultTime(result))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSelectedResult(AthleteStageResult stageResult, RaceResult result) {
  return result.id == stageResult.athleteResult.id;
}

String _placementFor(AthleteStageResult stageResult, RaceResult result) {
  if (!result.isFinished) {
    final status = result.status.trim();
    return status.isEmpty ? 'DNF' : status;
  }
  final official = result.finishRank ?? result.rank;
  if (official != null && official > 0) return '$official';

  int? previousTime;
  var previousRank = 0;
  for (var index = 0; index < stageResult.results.length; index++) {
    final candidate = stageResult.results[index];
    if (!candidate.isFinished || candidate.totalMs == null) continue;
    final rank = candidate.totalMs == previousTime ? previousRank : index + 1;
    if (candidate.id == result.id) return '$rank';
    previousTime = candidate.totalMs;
    previousRank = rank;
  }
  return '-';
}

String _resultTime(RaceResult result) {
  final text = result.totalText.trim();
  if (text.isNotEmpty) return text;
  final formatted = formatDurationMs(result.totalMs);
  if (formatted.isNotEmpty) return formatted;
  final status = result.status.trim();
  return status.isEmpty ? '-' : status;
}

String _affiliation(RaceResult result) {
  final club = result.club.trim();
  final team = result.team.trim();
  if (club.isNotEmpty && team.isNotEmpty && club != team) {
    return '$club · $team';
  }
  if (team.isNotEmpty) return team;
  return club.isEmpty ? '-' : club;
}
