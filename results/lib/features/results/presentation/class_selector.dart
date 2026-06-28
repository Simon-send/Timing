import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';

import '../domain/result_class.dart';

class ClassSelector extends StatelessWidget {
  const ClassSelector({
    super.key,
    required this.classes,
    required this.selectedClassId,
    required this.onChanged,
  });

  final List<ResultClass> classes;
  final String? selectedClassId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sortedClasses = sortResultClassesByDistance(classes);
    final disciplineLabel = combinedDisciplineLabel(sortedClasses);
    return DropdownButtonFormField<String>(
      initialValue: selectedClassId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: disciplineLabel ?? l10n.classes,
        helperText: disciplineLabel == null ? null : l10n.classes,
      ),
      items: [
        for (final raceClass in sortedClasses)
          DropdownMenuItem(
            value: raceClass.id,
            child: Text(
              '${raceClass.name} (${raceClass.resultCount})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: classes.isEmpty ? null : onChanged,
    );
  }
}
