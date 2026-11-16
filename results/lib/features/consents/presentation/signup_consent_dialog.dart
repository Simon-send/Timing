import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../data/account_consent_repository.dart';
import '../data/signup_pending.dart';
import '../domain/account_consents.dart';
import 'consent_choices.dart';

Future<void> finishPendingSignup(
  BuildContext context,
  WidgetRef ref,
  String uid,
) async {
  final source = pendingSignupSource(uid);
  var pending = source != null;
  try {
    final status = await ref.read(accountConsentRepositoryProvider).status(uid);
    if (status.registrationComplete) {
      clearSignupPending(uid);
      return;
    }
    pending = pending || status.registrationPending;
  } on Object {
    // A local marker recovers interrupted creation. The dialog must confirm
    // server state before displaying editable choices.
  }
  if (!pending ||
      !context.mounted ||
      ref.read(authRepositoryProvider).currentUser?.uid != uid) {
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        SignupConsentDialog(uid: uid, source: source ?? 'results-google'),
  );
}

class SignupConsentDialog extends ConsumerStatefulWidget {
  const SignupConsentDialog({
    required this.uid,
    required this.source,
    super.key,
  });
  final String uid;
  final String source;
  @override
  ConsumerState<SignupConsentDialog> createState() =>
      _SignupConsentDialogState();
}

class _SignupConsentDialogState extends ConsumerState<SignupConsentDialog> {
  RegistrationChoices choices = const RegistrationChoices();
  bool busy = false;
  bool failed = false;
  bool ready = false;
  int? loadedRevision;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final status = await ref
          .read(accountConsentRepositoryProvider)
          .status(widget.uid);
      if (!mounted) return;
      if (status.registrationComplete) {
        clearSignupPending(widget.uid);
        Navigator.pop(context);
        return;
      }
      setState(() {
        ready = true;
        loadedRevision = status.revision;
        choices = const RegistrationChoices();
      });
    } on Object {
      if (mounted) {
        setState(() {
          failed = true;
          ready = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (busy || !ready || !choices.privacy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final repository = ref.read(accountConsentRepositoryProvider);
      final status = await repository.status(widget.uid);
      if (status.registrationComplete) {
        clearSignupPending(widget.uid);
        if (mounted) Navigator.pop(context);
        return;
      }
      if (!mounted) return;
      if (status.revision != loadedRevision) {
        setState(() {
          ready = false;
          failed = true;
          choices = const RegistrationChoices();
        });
        return;
      }
      await repository.register(
        widget.uid,
        choices,
        Localizations.localeOf(context).languageCode,
        widget.source,
        expectedRevision: loadedRevision!,
      );
      clearSignupPending(widget.uid);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() {
          failed = true;
          ready = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(AppLocalizations.of(context).finishSignup),
      scrollable: true,
      content: SizedBox(
        width: 410,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ready)
              ConsentChoices(
                value: choices,
                onChanged: busy ? null : (v) => setState(() => choices = v),
              ),
            if (!ready && busy) const CircularProgressIndicator(),
            if (!ready && failed)
              TextButton(
                onPressed: busy ? null : _load,
                child: Text(AppLocalizations.of(context).reloadConsentChoices),
              ),
            const AccountPrivacyNoticeLink(),
            if (failed)
              Text(
                AppLocalizations.of(context).consentSaveFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).accountPrivacyNoticeClose),
        ),
        FilledButton(
          onPressed: busy || !ready || !choices.privacy ? null : _save,
          child: Text(AppLocalizations.of(context).saveConsentChoices),
        ),
      ],
    ),
  );
}
