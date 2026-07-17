import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/formatting/time_formatters.dart';
import '../../../core/widgets/app_shell.dart';
import '../../results/domain/race_result.dart';

class RelayTeamPanel extends StatelessWidget {
  const RelayTeamPanel({
    super.key,
    required this.result,
    this.classResults = const [],
    this.onSplitSelected,
  });

  final RaceResult result;
  final List<RaceResult> classResults;
  final ValueChanged<String>? onSplitSelected;

  @override
  Widget build(BuildContext context) {
    final legs = effectiveRelayLegs(result);
    final palette = context.palette;
    return ShellPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lagoppstilling og etappetider',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Etappetidene beregnes fra lagets registrerte vekslinger.',
            style: TextStyle(color: palette.mutedText),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < legs.length; index++) ...[
            _RelayLegTile(
              leg: legs[index],
              totalRank: _totalRank(legs[index]),
              legRank: _legRank(legs[index]),
              onTap: legs[index].splitId == null || onSplitSelected == null
                  ? null
                  : () => onSplitSelected!(legs[index].splitId!),
            ),
            if (index < legs.length - 1)
              Divider(height: 1, color: palette.border),
          ],
        ],
      ),
    );
  }

  int? _totalRank(RelayLegResult leg) {
    final storedRank = leg.totalRank;
    if (storedRank != null && storedRank > 0) return storedRank;
    final splitId = leg.splitId;
    final targetMs = leg.cumulativeMs;
    if (splitId == null || targetMs == null) return null;
    return _rankOf(
      targetMs,
      classResults
          .map((candidate) => candidate.splitValues[splitId]?.cumMs)
          .whereType<int>(),
    );
  }

  int? _legRank(RelayLegResult leg) {
    final targetMs = leg.timeMs;
    if (targetMs == null) return null;
    return _rankOf(
      targetMs,
      classResults.map((candidate) {
        return effectiveRelayLegs(candidate)
            .where((candidateLeg) => candidateLeg.legNumber == leg.legNumber)
            .firstOrNull
            ?.timeMs;
      }).whereType<int>(),
    );
  }
}

class _RelayLegTile extends StatelessWidget {
  const _RelayLegTile({
    required this.leg,
    required this.totalRank,
    required this.legRank,
    required this.onTap,
  });

  final RelayLegResult leg;
  final int? totalRank;
  final int? legRank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = formatDurationMs(leg.timeMs);
    final cumulative = formatDurationMs(leg.cumulativeMs);
    final palette = context.palette;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 18, child: Text('${leg.legNumber}')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leg.member?.name ?? 'Ukjent utøver',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (leg.checkpointLabel.isNotEmpty)
                  Text(
                    leg.checkpointLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RelayTimeRow(label: 'Totalt', time: cumulative, rank: totalRank),
              const SizedBox(height: 6),
              _RelayTimeRow(label: 'Etappe', time: time, rank: legRank),
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 20, color: palette.mutedText),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      link: true,
      button: true,
      label: 'Åpne ${leg.checkpointLabel}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class _RelayTimeRow extends StatelessWidget {
  const _RelayTimeRow({
    required this.label,
    required this.time,
    required this.rank,
  });

  final String label;
  final String time;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time.isEmpty ? '-' : time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                rank == null || rank! <= 0 ? 'Rank -' : 'Rank $rank',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

int? _rankOf(int targetMs, Iterable<int> values) {
  if (targetMs <= 0) return null;
  final rankedValues = values.where((value) => value > 0).toList();
  if (rankedValues.isEmpty) return null;
  return 1 + rankedValues.where((value) => value < targetMs).length;
}
