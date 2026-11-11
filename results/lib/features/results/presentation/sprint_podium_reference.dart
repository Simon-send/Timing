import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../app/app_providers.dart';
import '../../../core/formatting/time_formatters.dart';
import '../domain/split_def.dart';

class SprintPodiumReference extends ConsumerWidget {
  const SprintPodiumReference({
    super.key,
    required this.eventId,
    required this.stageId,
    required this.classId,
    required this.splits,
  });

  final String eventId;
  final String stageId;
  final String classId;
  final List<SplitOption> splits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podium = ref
        .watch(
          stageSprintPodiumProvider((
            eventId: eventId,
            stageId: stageId,
            classId: classId,
          )),
        )
        .asData
        ?.value;
    if (podium == null) return const SizedBox.shrink();

    final points = [
      for (final split in splits)
        if (podium.points[split.id] case final point?) (split.label, point),
    ];
    if (points.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sprintPodiumTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final (label, point) in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Text(label, style: theme.textTheme.labelLarge),
                      if (point.cumulative case final mean?)
                        Text(
                          l10n.sprintPodiumCumulative(
                            formatDurationMs(mean.meanMs),
                            mean.count,
                          ),
                        ),
                      if (point.leg case final mean?)
                        Text(
                          l10n.sprintPodiumLeg(
                            formatDurationMs(mean.meanMs),
                            mean.count,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
