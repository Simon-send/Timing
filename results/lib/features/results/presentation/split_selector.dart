import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

import '../domain/split_def.dart';

const _rangeStartId = '__range_start__';

class SplitSelector extends StatelessWidget {
  const SplitSelector({
    super.key,
    required this.splitOptions,
    required this.selectedSplitId,
    required this.onChanged,
    required this.rangeSelection,
    required this.canUseRange,
    required this.onRangeToggle,
    required this.onRangeFromChanged,
    required this.onRangeToChanged,
  });

  final List<SplitOption> splitOptions;
  final String? selectedSplitId;
  final ValueChanged<String?> onChanged;
  final SplitRangeSelection? rangeSelection;
  final bool canUseRange;
  final VoidCallback onRangeToggle;
  final ValueChanged<String?> onRangeFromChanged;
  final ValueChanged<String?> onRangeToChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedIndex = splitOptions.indexWhere(
      (split) => split.id == selectedSplitId,
    );
    final range = rangeSelection;
    if (range != null) {
      return _RangeSelector(
        splitOptions: splitOptions,
        rangeSelection: range,
        onToggle: onRangeToggle,
        onFromChanged: onRangeFromChanged,
        onToChanged: onRangeToChanged,
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton.outlined(
            tooltip: 'Previous split',
            onPressed: selectedIndex > 0
                ? () => onChanged(splitOptions[selectedIndex - 1].id)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton.outlined(
            tooltip: 'Next split',
            onPressed:
                selectedIndex >= 0 && selectedIndex < splitOptions.length - 1
                ? () => onChanged(splitOptions[selectedIndex + 1].id)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton.outlined(
            tooltip: 'Velg intervall',
            onPressed: selectedIndex >= 0 && canUseRange ? onRangeToggle : null,
            icon: const Icon(Icons.swap_horiz),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedSplitId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.split),
            items: [
              for (final split in splitOptions)
                DropdownMenuItem(
                  value: split.id,
                  child: Text(split.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: splitOptions.isEmpty ? null : onChanged,
          ),
        ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.splitOptions,
    required this.rangeSelection,
    required this.onToggle,
    required this.onFromChanged,
    required this.onToChanged,
  });

  final List<SplitOption> splitOptions;
  final SplitRangeSelection rangeSelection;
  final VoidCallback onToggle;
  final ValueChanged<String?> onFromChanged;
  final ValueChanged<String?> onToChanged;

  @override
  Widget build(BuildContext context) {
    if (splitOptions.isEmpty) {
      return Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: IconButton.outlined(
              tooltip: 'Vanlige splitter',
              onPressed: onToggle,
              icon: const Icon(Icons.close),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Ingen splitter', overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }
    final toIndex = splitOptions.indexWhere(
      (split) => split.id == rangeSelection.toSplitId,
    );
    final fromIndex = rangeSelection.fromSplitId == null
        ? -1
        : splitOptions.indexWhere(
            (split) => split.id == rangeSelection.fromSplitId,
          );
    final normalizedToIndex = toIndex < 0 ? 0 : toIndex;
    final normalizedFromIndex = fromIndex >= normalizedToIndex
        ? normalizedToIndex - 1
        : fromIndex;
    final fromOptions = splitOptions.take(normalizedToIndex).toList();
    final toOptions = splitOptions.skip(normalizedFromIndex + 1).toList();

    return Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton.outlined(
            tooltip: 'Vanlige splitter',
            onPressed: onToggle,
            icon: const Icon(Icons.close),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: normalizedFromIndex < 0
                ? _rangeStartId
                : splitOptions[normalizedFromIndex].id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Fra'),
            items: [
              const DropdownMenuItem(
                value: _rangeStartId,
                child: Text('Start', overflow: TextOverflow.ellipsis),
              ),
              for (final split in fromOptions)
                DropdownMenuItem(
                  value: split.id,
                  child: Text(split.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              onFromChanged(value == _rangeStartId ? null : value);
            },
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_forward, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: splitOptions[normalizedToIndex].id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Til'),
            items: [
              for (final split in toOptions)
                DropdownMenuItem(
                  value: split.id,
                  child: Text(split.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onToChanged,
          ),
        ),
      ],
    );
  }
}
