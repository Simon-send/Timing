import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_providers.dart';
import '../../../l10n/app_localizations.dart';
import 'signup_consent_dialog.dart';

class SignupConsentPage extends ConsumerStatefulWidget {
  const SignupConsentPage({super.key});
  @override
  ConsumerState<SignupConsentPage> createState() => _SignupConsentPageState();
}

class _SignupConsentPageState extends ConsumerState<SignupConsentPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid != null) await finishPendingSignup(context, ref, uid);
      if (mounted) context.go('/events');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text(AppLocalizations.of(context).finishSignup)),
  );
}
