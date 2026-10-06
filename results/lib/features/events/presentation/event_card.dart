import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../app/app_theme.dart';
import '../domain/result_event.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.participated = false,
  });

  final ResultEvent event;
  final VoidCallback onTap;
  final bool participated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final participatedColor = Color.alphaBlend(
      palette.primary.withValues(
        alpha: palette.brightness == Brightness.dark ? 0.18 : 0.12,
      ),
      palette.panel,
    );
    return Card(
      key: ValueKey('event-card-${event.id}'),
      margin: EdgeInsets.zero,
      color: participated ? participatedColor : palette.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: participated
              ? palette.primary.withValues(alpha: 0.7)
              : palette.border,
          width: participated ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _FactLine(icon: Icons.calendar_today, text: event.dateLabel),
              const SizedBox(height: 8),
              _FactLine(icon: Icons.flag_outlined, text: event.sportName),
              if (event.place.isNotEmpty) ...[
                const SizedBox(height: 8),
                _FactLine(icon: Icons.place_outlined, text: event.place),
              ],
              const Spacer(),
              Text(
                '${l10n.eventId}: ${event.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: null,
                  fontWeight: FontWeight.w700,
                ).copyWith(color: palette.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.palette.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.isEmpty ? '-' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
