import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (MediaQuery.sizeOf(context).width < 480) {
      return IconButton.filled(
        tooltip: l10n.login,
        onPressed: () => context.go('/login'),
        icon: const Icon(Icons.login),
      );
    }
    return FilledButton.icon(
      onPressed: () => context.go('/login'),
      icon: const Icon(Icons.login),
      label: Text(l10n.login),
    );
  }
}
