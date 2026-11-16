import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../data/account_consent_repository.dart';
import '../data/signup_pending.dart';
import '../domain/account_consents.dart';
import 'consent_choices.dart';
import 'signup_consent_dialog.dart';

Future<void> showConsentSettings(BuildContext context, String uid) =>
    showDialog<void>(
      context: context,
      builder: (_) => ConsentSettingsDialog(uid: uid),
    );

class ConsentSettingsDialog extends ConsumerStatefulWidget {
  const ConsentSettingsDialog({required this.uid, super.key});
  final String uid;
  @override
  ConsumerState<ConsentSettingsDialog> createState() =>
      _ConsentSettingsDialogState();
}

class _ConsentSettingsDialogState extends ConsumerState<ConsentSettingsDialog> {
  AccountConsents? state;
  bool busy = true;
  bool failed = false;
  bool saved = false;
  bool get sameAccount =>
      ref.read(authRepositoryProvider).currentUser?.uid == widget.uid;

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
      if (!sameAccount) throw const FormatException('Account changed');
      final value = await ref
          .read(accountConsentRepositoryProvider)
          .status(widget.uid);
      if (mounted && sameAccount) setState(() => state = value);
    } on Object {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _change({bool? cloud, bool? marketing}) async {
    if (busy || state == null || !sameAccount) return;
    if (cloud == false) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(AppLocalizations.of(context).consentWithdrawTitle),
          content: SizedBox(
            width: 440,
            child: Text(AppLocalizations.of(context).consentWithdrawBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                AppLocalizations.of(context).accountPrivacyNoticeClose,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context).consentWithdrawConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || !sameAccount) return;
    }
    setState(() {
      busy = true;
      failed = false;
      saved = false;
    });
    try {
      final value = await ref
          .read(accountConsentRepositoryProvider)
          .update(
            widget.uid,
            expectedRevision: state!.revision,
            locale: Localizations.localeOf(context).languageCode,
            cloudActivity: cloud,
            marketingEmail: marketing,
          );
      if (mounted && sameAccount) {
        setState(() {
          state = value;
          saved = true;
        });
      }
    } on Object {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (failed) await _loadAfterFailure();
      }
    }
  }

  Future<void> _loadAfterFailure() async {
    try {
      final value = await ref
          .read(accountConsentRepositoryProvider)
          .status(widget.uid);
      if (mounted && sameAccount) setState(() => state = value);
    } on Object {
      /* Preserve the error and offer an explicit refresh. */
    }
  }

  Future<void> _resume() async {
    if (busy || !sameAccount) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await ref
          .read(accountConsentRepositoryProvider)
          .resumeWithdrawal(widget.uid);
      await _load();
    } on Object {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final unfinished =
        state?.registrationPending == true &&
        state?.registrationComplete != true;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(strings.consentSettingsTitle),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) const LinearProgressIndicator(),
              if (state != null) ...[
                CheckboxListTile(
                  value: state!.cloudActivity,
                  onChanged:
                      busy ||
                          (unfinished && !state!.cloudActivity) ||
                          state!.activityCleanupPending
                      ? null
                      : (v) => _change(cloud: v == true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    strings.signupCloud,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                CheckboxListTile(
                  value: state!.marketingEmail,
                  onChanged: busy || (unfinished && !state!.marketingEmail)
                      ? null
                      : (v) => _change(marketing: v == true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    strings.signupMarketing,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (unfinished)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await showDialog<void>(
                              context: context,
                              builder: (_) => SignupConsentDialog(
                                uid: widget.uid,
                                source:
                                    pendingSignupSource(widget.uid) ??
                                    'results-google',
                              ),
                            );
                            if (mounted) await _load();
                          },
                    child: Text(strings.finishSignup),
                  ),
                if (state!.activityCleanupPending) ...[
                  Text(strings.consentCleanupPending),
                  TextButton(
                    onPressed: busy ? null : _resume,
                    child: Text(strings.consentResumeCleanup),
                  ),
                ],
              ],
              const AccountPrivacyNoticeLink(),
              if (failed)
                Text(
                  strings.consentSaveFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (saved) Text(strings.consentSaved),
              TextButton(
                onPressed: busy ? null : _load,
                child: Text(strings.reloadConsentChoices),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(strings.accountPrivacyNoticeClose),
          ),
        ],
      ),
    );
  }
}
