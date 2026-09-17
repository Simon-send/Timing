import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/app_localizations.dart';
import 'me_page.dart' show AthleteConnectPanel;

class AthleteLinkOnboardingPage extends ConsumerStatefulWidget {
  const AthleteLinkOnboardingPage({super.key});

  @override
  ConsumerState<AthleteLinkOnboardingPage> createState() =>
      _AthleteLinkOnboardingPageState();
}

class _AthleteLinkOnboardingPageState
    extends ConsumerState<AthleteLinkOnboardingPage> {
  var _redirected = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) {
      _redirectTo('/login');
      return const _OnboardingLoading();
    }

    return ref
        .watch(athleteLinkStateProvider)
        .when(
          loading: () => const _OnboardingLoading(),
          error: (error, _) => _AthleteLinkOnboardingScaffold(
            child: Text(AppLocalizations.of(context).couldNotReadAthleteLink),
          ),
          data: (state) {
            if (!state.shouldShowOnboarding) {
              _redirectTo('/events');
              return const _OnboardingLoading();
            }
            return _AthleteLinkOnboardingScaffold(
              child: AthleteConnectPanel(
                uid: user.uid,
                initialName: user.displayName ?? '',
                allowSkip: true,
                onLinked: () => _redirectTo('/events'),
                onSkipped: () => _redirectTo('/events'),
              ),
            );
          },
        );
  }

  void _redirectTo(String location) {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(location);
    });
  }
}

class _AthleteLinkOnboardingScaffold extends StatelessWidget {
  const _AthleteLinkOnboardingScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.person_search_outlined,
                        size: 48,
                        color: palette.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.connectAthleteOnboardingTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.connectAthleteOnboardingDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.mutedText),
                      ),
                      const SizedBox(height: 24),
                      child,
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

class _OnboardingLoading extends StatelessWidget {
  const _OnboardingLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: LoadingState(label: 'Laster konto')),
    );
  }
}
