import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class RelayLegSelector extends StatelessWidget {
  const RelayLegSelector({
    super.key,
    required this.legNumbers,
    required this.activeLegNumber,
    required this.comparisonLegNumbers,
    required this.onPrimaryChanged,
    required this.onComparisonChanged,
  });

  final List<int> legNumbers;
  final int? activeLegNumber;
  final List<int> comparisonLegNumbers;
  final ValueChanged<int?> onPrimaryChanged;
  final void Function(int legNumber, bool selected) onComparisonChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('relay-leg-selector'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Stafettetapper',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    comparisonLegNumbers.isEmpty
                        ? 'Velg flere for å sammenligne'
                        : 'Sammenligner på Etappetid',
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: Row(
              children: [
                _RelayLegTile(
                  label: 'Lagresultat',
                  selected: activeLegNumber == null,
                  checked: activeLegNumber == null,
                  color: null,
                  onTap: () => onPrimaryChanged(null),
                ),
                for (final legNumber in legNumbers) ...[
                  const SizedBox(width: 8),
                  _RelayLegTile(
                    key: Key('relay-leg-$legNumber'),
                    label: 'Etappe $legNumber',
                    selected: activeLegNumber == legNumber,
                    checked:
                        activeLegNumber == legNumber ||
                        comparisonLegNumbers.contains(legNumber),
                    color: _legColor(
                      legNumber,
                      activeLegNumber,
                      comparisonLegNumbers,
                    ),
                    onTap: () => onPrimaryChanged(legNumber),
                    onChecked: activeLegNumber == legNumber
                        ? null
                        : (value) => onComparisonChanged(legNumber, value),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color? _legColor(
    int legNumber,
    int? activeLegNumber,
    List<int> comparisonLegNumbers,
  ) {
    if (legNumber == activeLegNumber) return relayLegColor(0);
    final comparisonIndex = comparisonLegNumbers.indexOf(legNumber);
    if (comparisonIndex >= 0) return relayLegColor(comparisonIndex + 1);
    return null;
  }
}

class _RelayLegTile extends StatelessWidget {
  const _RelayLegTile({
    super.key,
    required this.label,
    required this.selected,
    required this.checked,
    required this.onTap,
    this.color,
    this.onChecked,
  });

  final String label;
  final bool selected;
  final bool checked;
  final Color? color;
  final VoidCallback onTap;
  final ValueChanged<bool>? onChecked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.primary.withValues(alpha: 0.16) : palette.panel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 176,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
                onChanged: onChecked == null
                    ? null
                    : (value) => onChecked!(value ?? false),
                activeColor: color ?? palette.primary,
                visualDensity: VisualDensity.compact,
              ),
              Container(
                width: 5,
                height: 30,
                decoration: BoxDecoration(
                  color: color ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color relayLegColor(int index) {
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
