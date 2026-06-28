import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_theme.dart';
import '../data/auth_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscurePassword = true;
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
    return _AuthScaffold(
      title: 'Logg inn',
      subtitle: 'Logg inn med e-post og passord.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EmailField(controller: _emailController),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _signInWithEmail(),
              decoration: InputDecoration(
                labelText: 'Passord',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Vis passord' : 'Skjul passord',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Skriv inn passordet ditt.'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isBusy ? null : _openForgotPassword,
                child: const Text('Glemt passord?'),
              ),
            ),
            if (_error != null) ...[
              _AuthNotice(text: _error!, danger: true),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _isBusy ? null : _signInWithEmail,
              icon: _isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Logg inn'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _signInWithGoogle,
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Fortsett med Google'),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Har du ikke konto?'),
                TextButton(
                  onPressed: _isBusy ? null : () => context.go('/register'),
                  child: const Text('Opprett konto'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openForgotPassword() {
    final uri = Uri(
      path: '/forgot-password',
      queryParameters: {'email': _emailController.text.trim()},
    );
    context.go(uri.toString());
  }

  Future<void> _signInWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
    );
  }

  Future<void> _signInWithGoogle() {
    return _run(() => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) context.go('/events');
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  var _isBusy = false;
  var _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Glemt passord',
      subtitle: 'Vi sender deg en sikker lenke for å velge et nytt passord.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sent) ...[
              const _AuthNotice(
                text:
                    'Hvis e-postadressen er registrert, har vi sendt en lenke for å tilbakestille passordet. Sjekk også søppelpost.',
              ),
              const SizedBox(height: 16),
            ],
            _EmailField(
              controller: _emailController,
              onSubmitted: (_) => _sendResetEmail(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _AuthNotice(text: _error!, danger: true),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isBusy ? null : _sendResetEmail,
              icon: _isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_read_outlined),
              label: const Text('Send tilbakestillingslenke'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _isBusy ? null : () => context.go('/login'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Tilbake til innlogging'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendResetEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isBusy = true;
      _error = null;
      _sent = false;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  var _isBusy = false;
  var _created = false;
  var _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Opprett konto',
      subtitle: 'E-postadressen må bekreftes før du kan logge inn.',
      child: _created ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthNotice(
          text:
              'Vi har sendt en bekreftelseslenke til ${_emailController.text.trim()}. Åpne lenken før du logger inn.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login),
          label: const Text('Gå til innlogging'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EmailField(controller: _emailController),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Passord',
              helperText: 'Bruk minst 6 tegn.',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Vis passord' : 'Skjul passord',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => value == null || value.length < 6
                ? 'Passordet må ha minst 6 tegn.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _createAccount(),
            decoration: const InputDecoration(
              labelText: 'Gjenta passord',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            validator: (value) => value != _passwordController.text
                ? 'Passordene er ikke like.'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthNotice(text: _error!, danger: true),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isBusy ? null : _createAccount,
            icon: _isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_outlined),
            label: const Text('Opprett konto'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isBusy ? null : () => context.go('/login'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Tilbake til innlogging'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .createUserWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) setState(() => _created = true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: onSubmitted,
      autocorrect: false,
      decoration: const InputDecoration(
        labelText: 'E-post',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty || !email.contains('@')) {
          return 'Skriv inn en gyldig e-postadresse.';
        }
        return null;
      },
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              child: IconButton.outlined(
                tooltip: 'Tilbake til resultater',
                onPressed: () => context.go('/events'),
                icon: const Icon(Icons.close),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: palette.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: palette.logoForeground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
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
          ],
        ),
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice({required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = danger ? palette.danger : palette.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            danger ? Icons.error_outline : Icons.mark_email_read_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String authErrorMessage(Object error) {
  if (error is EmailNotVerifiedException) {
    return 'E-postadressen er ikke bekreftet. Åpne bekreftelseslenken vi sendte før du logger inn.';
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'E-postadressen er ugyldig.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Feil e-postadresse eller passord.',
      'email-already-in-use' =>
        'Det finnes allerede en konto med denne e-posten.',
      'weak-password' => 'Passordet er for svakt.',
      'too-many-requests' => 'For mange forsøk. Vent litt før du prøver igjen.',
      'network-request-failed' =>
        'Kunne ikke koble til. Kontroller internettforbindelsen.',
      'operation-not-allowed' =>
        'E-postinnlogging er ikke aktivert i Firebase ennå.',
      _ => 'Noe gikk galt. Prøv igjen.',
    };
  }
  if (error is UnsupportedError) {
    return 'Denne innloggingsmetoden er ikke tilgjengelig på denne enheten.';
  }
  return 'Noe gikk galt. Prøv igjen.';
}
