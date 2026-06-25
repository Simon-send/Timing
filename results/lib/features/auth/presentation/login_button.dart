import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_theme.dart';

class LoginButton extends ConsumerWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: () => _showLoginDialog(context, ref),
      icon: const Icon(Icons.login),
      label: Text(l10n.login),
    );
  }

  Future<void> _showLoginDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _LoginDialog(),
    );
  }
}

class _LoginDialog extends ConsumerStatefulWidget {
  const _LoginDialog();

  @override
  ConsumerState<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<_LoginDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.login),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.email),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.password),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: context.palette.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isBusy ? null : _signInWithGoogle,
          icon: const Icon(Icons.account_circle_outlined),
          label: Text(l10n.signInWithGoogle),
        ),
        TextButton(
          onPressed: _isBusy ? null : _createAccount,
          child: Text(l10n.createAccount),
        ),
        FilledButton(
          onPressed: _isBusy ? null : _signInWithEmail,
          child: Text(l10n.signInWithEmail),
        ),
      ],
    );
  }

  Future<void> _signInWithGoogle() {
    return _run(() => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  Future<void> _signInWithEmail() {
    return _run(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
    );
  }

  Future<void> _createAccount() {
    return _run(
      () => ref
          .read(authRepositoryProvider)
          .createUserWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}
