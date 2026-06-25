import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_theme.dart';
import '../domain/user_settings.dart';
import 'language_selector.dart';

class SettingsMenu extends ConsumerWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton.outlined(
      tooltip: l10n.settings,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => const _SettingsDialog(),
      ),
      icon: const Icon(Icons.tune),
    );
  }
}

class _SettingsDialog extends ConsumerWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    return AlertDialog(
      title: Text(l10n.settings),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LanguageSelector(),
            const SizedBox(height: 16),
            DropdownButtonFormField<AppThemeVariant>(
              initialValue: settings.themeVariant,
              decoration: const InputDecoration(
                labelText: 'Design',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
              items: [
                for (final variant in AppThemeVariant.values)
                  DropdownMenuItem(value: variant, child: Text(variant.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(settingsControllerProvider.notifier)
                    .setThemeVariant(value);
              },
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tableDensity,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TableDensity>(
              segments: [
                ButtonSegment(
                  value: TableDensity.comfortable,
                  label: Text(l10n.comfortable),
                  icon: const Icon(Icons.view_stream_outlined),
                ),
                ButtonSegment(
                  value: TableDensity.compact,
                  label: Text(l10n.compact),
                  icon: const Icon(Icons.table_rows_outlined),
                ),
              ],
              selected: {settings.tableDensity},
              onSelectionChanged: (selection) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setTableDensity(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
