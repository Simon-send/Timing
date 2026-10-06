import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import 'login_button.dart';

class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    return user.when(
      data: (user) {
        if (user == null) return const LoginButton();
        final l10n = AppLocalizations.of(context);
        final compact = MediaQuery.sizeOf(context).width < 480;
        return PopupMenuButton<String>(
          tooltip: l10n.account,
          onSelected: (value) {
            if (value == 'me') context.go('/me');
            if (value == 'logout') ref.read(authRepositoryProvider).signOut();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'me', child: Text('Min side')),
            PopupMenuItem(value: 'logout', child: Text(l10n.logout)),
          ],
          child: compact
              ? IconButton.outlined(
                  tooltip: l10n.account,
                  onPressed: null,
                  icon: const Icon(Icons.person_outline),
                )
              : OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.person_outline),
                  label: Text(l10n.account),
                ),
        );
      },
      loading: () => const SizedBox(
        width: 38,
        height: 38,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stackTrace) => const LoginButton(),
    );
  }
}
