import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_settings.dart';

abstract class SettingsRepository {
  Future<UserSettings> load();

  Future<void> save(UserSettings settings);
}

class AppSettingsRepository implements SettingsRepository {
  AppSettingsRepository({
    required SharedPreferences preferences,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _preferences = preferences,
       _firestore = firestore,
       _auth = auth;

  static const _prefix = 'eq_results.';

  final SharedPreferences _preferences;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<UserSettings> load() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _settingsDoc(user.uid).get();
      final data = snapshot.data();
      if (data != null) return UserSettings.fromMap(data);
    }
    return _loadLocal();
  }

  @override
  Future<void> save(UserSettings settings) async {
    await _saveLocal(settings);
    final user = _auth.currentUser;
    if (user == null) return;
    await _settingsDoc(user.uid).set(settings.toMap(), SetOptions(merge: true));
  }

  UserSettings _loadLocal() {
    return UserSettings.fromMap({
      'localeCode': _preferences.getString('${_prefix}localeCode'),
      'defaultEventId': _preferences.getString('${_prefix}defaultEventId'),
      'defaultClassId': _preferences.getString('${_prefix}defaultClassId'),
      'preferredSplitId': _preferences.getString('${_prefix}preferredSplitId'),
      'tableDensity': _preferences.getString('${_prefix}tableDensity'),
      'themeVariant': _preferences.getString('${_prefix}themeVariant'),
    });
  }

  Future<void> _saveLocal(UserSettings settings) async {
    await _preferences.setString('${_prefix}localeCode', settings.localeCode);
    await _setNullableString(
      '${_prefix}defaultEventId',
      settings.defaultEventId,
    );
    await _setNullableString(
      '${_prefix}defaultClassId',
      settings.defaultClassId,
    );
    await _setNullableString(
      '${_prefix}preferredSplitId',
      settings.preferredSplitId,
    );
    await _preferences.setString(
      '${_prefix}tableDensity',
      settings.tableDensity.name,
    );
    await _preferences.setString(
      '${_prefix}themeVariant',
      settings.themeVariant.name,
    );
  }

  Future<void> _setNullableString(String key, String? value) {
    if (value == null || value.isEmpty) {
      return _preferences.remove(key);
    }
    return _preferences.setString(key, value);
  }

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('app');
  }
}
