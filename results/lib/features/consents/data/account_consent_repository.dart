import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_consents.dart';

final accountConsentRepositoryProvider = Provider(
  (ref) => AccountConsentRepository(),
);

class AccountConsentRepository {
  Future<Map<String, dynamic>> _call(
    String name,
    String expectedUid, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (FirebaseAuth.instance.currentUser?.uid != expectedUid) {
      throw const FormatException('Kontoen er endret. Prøv igjen.');
    }
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
        )
        .call<dynamic>({...data, 'expectedUid': expectedUid});
    if (FirebaseAuth.instance.currentUser?.uid != expectedUid) {
      throw const FormatException('Kontoen er endret. Prøv igjen.');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<AccountConsents> status(String uid) async =>
      AccountConsents.fromJson(await _call('getPlottingAccountConsents', uid));
  Future<void> begin(String uid, String source) async {
    await _call('beginPlottingRegistration', uid, {'source': source});
  }

  Future<AccountConsents> register(
    String uid,
    RegistrationChoices choices,
    String locale,
    String source, {
    int expectedRevision = 0,
  }) async => AccountConsents.fromJson(
    await _call('recordPlottingRegistrationConsents', uid, {
      'expectedRevision': expectedRevision,
      'privacy': choices.privacy,
      'cloudActivity': choices.cloudActivity,
      'marketingEmail': choices.marketingEmail,
      'version': accountConsentVersion,
      'locale': locale,
      'source': source,
    }),
  );
  Future<void> resumeWithdrawal(String uid) async {
    await _call('resumePlottingActivityWithdrawal', uid);
  }

  Future<AccountConsents> update(
    String uid, {
    required int expectedRevision,
    required String locale,
    bool? cloudActivity,
    bool? marketingEmail,
  }) async => AccountConsents.fromJson(
    await _call('updatePlottingAccountConsents', uid, {
      'version': accountConsentVersion,
      'locale': locale,
      'expectedRevision': expectedRevision,
      'cloudActivity': ?cloudActivity,
      'marketingEmail': ?marketingEmail,
    }),
  );
}
