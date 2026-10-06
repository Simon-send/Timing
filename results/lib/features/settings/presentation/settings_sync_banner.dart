import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../app/app_providers.dart';

/// App-wide feedback also covers choices made outside the settings dialog.
class SettingsSyncBanner extends ConsumerWidget {
  const SettingsSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(settingsSyncStatusProvider) != SettingsSyncStatus.failed) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(l10n.settingsSyncFailed)),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () =>
                    ref.read(settingsControllerProvider.notifier).retry(),
                child: Text(l10n.settingsRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
