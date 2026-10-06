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
    required this.onIndependentChanged,
    required this.onIncludedSplitsChanged,
  });

  final List<SplitOption> splitOptions;
  final String? selectedSplitId;
  final ValueChanged<String?> onChanged;
  final SplitRangeSelection? rangeSelection;
  final bool canUseRange;
  final VoidCallback onRangeToggle;
  final ValueChanged<String?> onRangeFromChanged;
  final ValueChanged<String?> onRangeToChanged;
  final ValueChanged<bool> onIndependentChanged;
  final ValueChanged<List<String>> onIncludedSplitsChanged;

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
        onIndependentChanged: onIndependentChanged,
        onIncludedSplitsChanged: onIncludedSplitsChanged,
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
    required this.onIndependentChanged,
    required this.onIncludedSplitsChanged,
  });

  final List<SplitOption> splitOptions;
  final SplitRangeSelection rangeSelection;
  final VoidCallback onToggle;
  final ValueChanged<String?> onFromChanged;
  final ValueChanged<String?> onToChanged;
  final ValueChanged<bool> onIndependentChanged;
  final ValueChanged<List<String>> onIncludedSplitsChanged;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
              child: Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  key: const Key('independent-splits-checkbox'),
                  value: rangeSelection.isIndependent,
                  onChanged: (value) => onIndependentChanged(value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text('Uavhengige splitter'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rangeSelection.isIndependent)
          _IndependentSplitPicker(
            splitOptions: splitOptions,
            selectedSplitIds: rangeSelection.includedSplitIds,
            onChanged: onIncludedSplitsChanged,
          )
        else
          _ChronologicalRangeFields(
            splitOptions: splitOptions,
            rangeSelection: rangeSelection,
            onFromChanged: onFromChanged,
            onToChanged: onToChanged,
          ),
      ],
    );
  }
}

class _ChronologicalRangeFields extends StatelessWidget {
  const _ChronologicalRangeFields({
    required this.splitOptions,
    required this.rangeSelection,
    required this.onFromChanged,
    required this.onToChanged,
  });

  final List<SplitOption> splitOptions;
  final SplitRangeSelection rangeSelection;
  final ValueChanged<String?> onFromChanged;
  final ValueChanged<String?> onToChanged;

  @override
  Widget build(BuildContext context) {
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

class _IndependentSplitPicker extends StatelessWidget {
  const _IndependentSplitPicker({
    required this.splitOptions,
    required this.selectedSplitIds,
    required this.onChanged,
  });

  final List<SplitOption> splitOptions;
  final List<String> selectedSplitIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedSplitIds.toSet();
    final selectedLabels = splitOptions
        .where((split) => selected.contains(split.id))
        .map((split) => split.label)
        .toList();
    final valueText = selectedLabels.isEmpty
        ? 'Ingen splitter valgt'
        : selectedLabels.join(', ');

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        key: const Key('independent-splits-picker'),
        onPressed: () => _showPicker(context),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          children: [
            const Icon(Icons.checklist, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(valueText, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text('${selectedLabels.length}/${splitOptions.length}'),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = selectedSplitIds.toSet();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Velg uavhengige splitter'),
              content: SizedBox(
                width: 420,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final split in splitOptions)
                      CheckboxListTile(
                        key: Key('independent-split-${split.id}'),
                        value: selected.contains(split.id),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked ?? false) {
                              selected.add(split.id);
                            } else {
                              selected.remove(split.id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(split.label),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Avbryt'),
                ),
                FilledButton(
                  onPressed: () {
                    final sortedIds = splitOptions
                        .where((split) => selected.contains(split.id))
                        .map((split) => split.id)
                        .toList();
                    Navigator.of(context).pop(sortedIds);
                  },
                  child: const Text('Bruk'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) onChanged(result);
  }
}
