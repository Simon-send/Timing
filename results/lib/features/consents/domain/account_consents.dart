const accountConsentVersion = '2026-11-16';

class RegistrationChoices {
  const RegistrationChoices({
    this.privacy = false,
    this.cloudActivity = false,
    this.marketingEmail = false,
  });
  final bool privacy;
  final bool cloudActivity;
  final bool marketingEmail;
}

class AccountConsents {
  const AccountConsents({
    this.registrationPending = false,
    this.registrationComplete = false,
    this.privacyAcknowledged = false,
    this.cloudActivity = false,
    this.marketingEmail = false,
    this.revision = 0,
    this.activityCleanupPending = false,
  });
  factory AccountConsents.fromJson(Map<String, dynamic> value) =>
      AccountConsents(
        registrationPending: value['registrationPending'] == true,
        registrationComplete: value['registrationComplete'] == true,
        privacyAcknowledged: value['privacyAcknowledged'] == true,
        cloudActivity: value['cloudActivity'] == true,
        marketingEmail: value['marketingEmail'] == true,
        revision: (value['revision'] as num?)?.toInt() ?? 0,
        activityCleanupPending: value['activityCleanupPending'] == true,
      );
  final bool registrationPending;
  final bool registrationComplete;
  final bool privacyAcknowledged;
  final bool cloudActivity;
  final bool marketingEmail;
  final int revision;
  final bool activityCleanupPending;
}
