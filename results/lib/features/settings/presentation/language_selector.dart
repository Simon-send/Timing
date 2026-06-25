import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const languages = [
    ('en', 'English'),
    ('nb', 'Norsk'),
    ('sv', 'Svenska'),
    ('fi', 'Suomi'),
    ('fr', 'Francais'),
    ('de', 'Deutsch'),
    ('ru', 'Russian'),
    ('it', 'Italiano'),
    ('es', 'Espanol'),
    ('et', 'Eesti'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    return DropdownButtonFormField<String>(
      initialValue: settings.localeCode,
      decoration: InputDecoration(labelText: l10n.language),
      items: [
        for (final (code, label) in languages)
          DropdownMenuItem(value: code, child: Text(label)),
      ],
      onChanged: (value) {
        if (value != null) {
          ref.read(settingsControllerProvider.notifier).setLocale(value);
        }
      },
    );
  }
}
