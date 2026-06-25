import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:results/l10n/app_localizations.dart';

import 'app_providers.dart';
import 'app_router.dart';
import 'app_theme.dart';

class ResultsApp extends ConsumerWidget {
  const ResultsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'EQ Results',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(settings.themeVariant),
      routerConfig: router,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale?.languageCode == 'no') return const Locale('nb');
        return supportedLocales.contains(locale) ? locale : const Locale('nb');
      },
    );
  }
}
