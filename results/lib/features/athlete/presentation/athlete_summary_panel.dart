import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../results/domain/race_result.dart';

class AthleteSummaryPanel extends StatelessWidget {
  const AthleteSummaryPanel({
    super.key,
    required this.result,
    this.placementLabel,
    this.isComparing = false,
    this.onComparePressed,
  });

  final RaceResult result;
  final String? placementLabel;
  final bool isComparing;
  final VoidCallback? onComparePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return ShellPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  result.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onComparePressed != null) ...[
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Sammenlign utover',
                  onPressed: onComparePressed,
                  color: isComparing ? palette.primary : null,
                  icon: const Icon(Icons.compare_arrows),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.club.isEmpty ? '-' : result.club,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                label: l10n.place,
                value: placementLabel ?? result.placementLabel,
              ),
              _InfoChip(
                label: l10n.bib,
                value: result.bib.isEmpty ? '-' : result.bib,
              ),
              _InfoChip(
                label: l10n.time,
                value: result.totalText.isEmpty ? '-' : result.totalText,
              ),
              _InfoChip(
                label: l10n.shooting,
                value: result.shooting.isEmpty ? '-' : result.shooting,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
