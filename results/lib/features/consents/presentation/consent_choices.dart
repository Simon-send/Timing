import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/account_consents.dart';

class ConsentChoices extends StatelessWidget {
  const ConsentChoices({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final RegistrationChoices value;
  final ValueChanged<RegistrationChoices>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _choice(
        context,
        value.privacy,
        AppLocalizations.of(context).signupPrivacy,
        (v) => RegistrationChoices(
          privacy: v,
          cloudActivity: value.cloudActivity,
          marketingEmail: value.marketingEmail,
        ),
      ),
      _choice(
        context,
        value.cloudActivity,
        AppLocalizations.of(context).signupCloud,
        (v) => RegistrationChoices(
          privacy: value.privacy,
          cloudActivity: v,
          marketingEmail: value.marketingEmail,
        ),
      ),
      _choice(
        context,
        value.marketingEmail,
        AppLocalizations.of(context).signupMarketing,
        (v) => RegistrationChoices(
          privacy: value.privacy,
          cloudActivity: value.cloudActivity,
          marketingEmail: v,
        ),
      ),
    ],
  );
  Widget _choice(
    BuildContext context,
    bool selected,
    String text,
    RegistrationChoices Function(bool) change,
  ) => CheckboxListTile(
    value: selected,
    onChanged: onChanged == null ? null : (v) => onChanged!(change(v == true)),
    title: Text(text, style: const TextStyle(fontSize: 12, height: 1.25)),
    dense: true,
    contentPadding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    controlAffinity: ListTileControlAffinity.leading,
  );
}

class AccountPrivacyNoticeLink extends StatelessWidget {
  const AccountPrivacyNoticeLink({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(AppLocalizations.of(context).accountPrivacyNoticeTitle),
        content: SizedBox(
          width: 480,
          child: SelectableText(
            AppLocalizations.of(context).accountPrivacyNoticeBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).accountPrivacyNoticeClose),
          ),
        ],
      ),
    ),
    child: Text(AppLocalizations.of(context).accountPrivacyNoticeTitle),
  );
}
