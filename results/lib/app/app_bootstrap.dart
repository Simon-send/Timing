import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_providers.dart';
import 'app_theme.dart';
import 'results_app.dart';
import '../core/firebase/firebase_options.dart';

const _bootstrapTimeout = Duration(seconds: 20);

class AppStartupException implements Exception {
  const AppStartupException(this.message);
  final String message;
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.initialize, this.appBuilder});

  final Future<AppDependencies> Function()? initialize;
  final Widget Function(AppDependencies dependencies)? appBuilder;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<AppDependencies> _initialization;
  Future<AppDependencies>? _inFlight;
  String _startupStep = 'oppstart';
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _initialization = _start();
  }

  Future<AppDependencies> _start() {
    _timedOut = false;
    final running = _inFlight ??= Future.sync(
      widget.initialize ??
          () =>
              initializeAppDependencies(onStep: (step) => _startupStep = step),
    ).whenComplete(() => _inFlight = null);
    // A timeout only stops waiting; successful late initialization still counts.
    unawaited(
      running.then<void>((dependencies) {
        if (mounted && _timedOut) {
          _timedOut = false;
          setState(() {
            _initialization = Future.value(dependencies);
          });
        }
      }, onError: (Object error, StackTrace stack) {}),
    );
    return running.timeout(
      _bootstrapTimeout,
      onTimeout: () {
        _timedOut = true;
        throw AppStartupException(
          'Venter fortsatt på $_startupStep. Du kan prøve igjen. '
          'Appen åpnes automatisk hvis tilkoblingen fullfører.',
        );
      },
    );
  }

  void _retry() {
    final initialization = _start();
    setState(() {
      _initialization = initialization;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDependencies>(
      future: _initialization,
      builder: (context, snapshot) {
        final dependencies = snapshot.data;
        if (dependencies != null) {
          return (widget.appBuilder ?? _buildResultsApp)(dependencies);
        }
        return _BootstrapScreen(
          isLoading: snapshot.connectionState != ConnectionState.done,
          error: snapshot.error,
          onRetry: _retry,
        );
      },
    );
  }

  Widget _buildResultsApp(AppDependencies dependencies) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(dependencies.preferences),
      ],
      child: const ResultsApp(),
    );
  }
}

class AppDependencies {
  const AppDependencies({required this.preferences});

  final SharedPreferences preferences;
}

Future<AppDependencies> initializeAppDependencies({
  void Function(String step)? onStep,
}) async {
  onStep?.call('Firebase og innlogging');
  try {
    // Do not read Firebase.apps before the web SDK has loaded. Its undefined
    // error fallback depends on browser-specific wording and fails in Safari.
    // initializeApp reuses the default app when its configuration matches.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    throw const AppStartupException(
      'Firebase og innlogging kunne ikke starte. Prøv igjen.',
    );
  }
  if (kIsWeb) {
    onStep?.call('lagring av innloggingsøkten');
    await _initializeOptionalWebService(
      'lokal innloggingsøkt',
      () => FirebaseAuth.instance.setPersistence(Persistence.LOCAL),
    );
    const appCheckSiteKey = String.fromEnvironment(
      'FIREBASE_APP_CHECK_SITE_KEY',
    );
    if (kReleaseMode && appCheckSiteKey.isEmpty) {
      throw const AppStartupException(
        'Sikkerhetskontrollen er ikke konfigurert. Kontakt brukerstøtte.',
      );
    }
    if (appCheckSiteKey.isNotEmpty) {
      onStep?.call('sikkerhetskontrollen');
      try {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(appCheckSiteKey),
        );
        final token = await FirebaseAppCheck.instance.getToken(true);
        if (token == null || token.isEmpty) throw StateError('Missing token');
      } catch (error) {
        debugPrint(
          'bootstrap/app-check: ${error is FirebaseException ? error.code : 'unavailable'}',
        );
        throw const AppStartupException(
          'Sikkerhetskontrollen kunne ikke fullføres. Prøv igjen.',
        );
      }
    }
  }
  onStep?.call('lokale innstillinger');
  try {
    return AppDependencies(preferences: await SharedPreferences.getInstance());
  } catch (error) {
    throw const AppStartupException(
      'Lokale innstillinger kunne ikke lastes. Kontroller at nettleseren tillater nettsteddata.',
    );
  }
}

Future<void> _initializeOptionalWebService(
  String name,
  Future<void> Function() initialize,
) async {
  try {
    await initialize();
  } catch (error, stackTrace) {
    debugPrint(
      'bootstrap/$name: ${error is FirebaseException ? error.code : 'unavailable'}',
    );
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen({
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(AppThemeVariant.nordicDark),
      home: Scaffold(
        body: ColoredBox(
          color: AppPalette.forVariant(AppThemeVariant.nordicDark).background,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 48),
                      const SizedBox(height: 18),
                      Text(
                        isLoading ? 'Starter Resultater' : 'Kunne ikke starte',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isLoading
                            ? 'Kobler til tjenestene dine.'
                            : error is AppStartupException
                            ? (error as AppStartupException).message
                            : 'Kontroller nettforbindelsen og prøv igjen.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (isLoading)
                        const CircularProgressIndicator()
                      else
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Prøv igjen'),
                        ),
                      if (error != null && kDebugMode) ...[
                        const SizedBox(height: 18),
                        SelectableText(
                          error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
