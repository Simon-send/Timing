import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../results/domain/race_result.dart';
import 'biathlon_result_panel.dart';
import 'relay_team_panel.dart';

/// The shared detail page stays sport-neutral. Capability-specific sections
/// are registered here and rendered above the ordinary split details.
class ResultDetailExtensions extends StatelessWidget {
  const ResultDetailExtensions({
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
    final sections = <Widget>[
      if (result.relayLegNumber != null) _RelayLegContext(result: result),
      if (result.biathlon?.hasData ?? false)
        BiathlonResultPanel(
          analysis: result.biathlon!,
          result: result,
          classResults: classResults,
          onSplitSelected: onSplitSelected,
        ),
      if (result.entrant?.kind == ResultEntrantKind.team ||
          result.relayMembers.isNotEmpty)
        RelayTeamPanel(
          result: result,
          classResults: classResults,
          onSplitSelected: onSplitSelected,
        ),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in sections) ...[
          section,
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RelayLegContext extends StatelessWidget {
  const _RelayLegContext({required this.result});

  final RaceResult result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ShellPanel(
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Etappe ${result.relayLegNumber}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.relayTeamName.isEmpty
                      ? 'Sammenlignes med denne etappen, inkludert splitter.'
                      : '${result.relayTeamName} · sammenlignes med denne etappen, inkludert splitter.',
                  style: TextStyle(color: palette.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
