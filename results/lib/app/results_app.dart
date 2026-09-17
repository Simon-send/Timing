import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:results/l10n/app_localizations.dart';

import 'app_providers.dart';
import 'app_router.dart';
import 'app_theme.dart';

class ResultsApp extends ConsumerStatefulWidget {
  const ResultsApp({super.key});

  @override
  ConsumerState<ResultsApp> createState() => _ResultsAppState();
}

class _ResultsAppState extends ConsumerState<ResultsApp>
    with WidgetsBindingObserver {
  var _refreshWhenResumed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _refreshWhenResumed = true;
        break;
      case AppLifecycleState.resumed:
        if (_refreshWhenResumed) {
          _refreshWhenResumed = false;
          refreshAppData(ref);
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(appRouterProvider);
    ref.listen(googleRedirectProvider, (previous, next) {
      if (next.asData?.value != null) router.go('/events');
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
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
