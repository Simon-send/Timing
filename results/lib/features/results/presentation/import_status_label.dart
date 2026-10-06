import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class ImportStatusLabel extends StatelessWidget {
  const ImportStatusLabel({super.key, required this.state});

  final String? state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (state) {
      'waiting' => l10n.importWaiting,
      'importing' => l10n.importInProgress,
      'partial' => l10n.importPartial,
      'updated' => l10n.importUpdated,
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: state == 'partial'
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
      ),
    );
  }
}
