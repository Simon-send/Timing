import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_settings.dart';

abstract class SettingsRepository {
  Future<UserSettings> load();
  Future<void> save(UserSettings settings);
}

/// A lifetime, rather than a UID: returning to the same account is a new session.
class SettingsSession {
  SettingsSession({required this.uid, required this.verified});

  final String? uid;
  final bool verified;
  bool _active = true;
  bool get isActive => _active;
  void invalidate() => _active = false;
}

class SettingsSessionTracker extends ValueNotifier<SettingsSession> {
  SettingsSessionTracker(User? user)
    : super(
        SettingsSession(uid: user?.uid, verified: user?.emailVerified == true),
      );

  SettingsSession get current => value;

  bool update(User? user) {
    final verified = user?.emailVerified == true;
    if (current.uid == user?.uid && current.verified == verified) return false;
    current.invalidate();
    value = SettingsSession(uid: user?.uid, verified: verified);
    return true;
  }

  @override
  void dispose() {
    current.invalidate();
    super.dispose();
  }
}

/// Extra persistence controls used by the session-aware controller. The basic
/// repository interface remains usable by existing clients and test doubles.
abstract interface class SessionSettingsRepository {
  bool get isCurrentSession;
  UserSettings loadLocal();
  Future<void> saveLocal(UserSettings settings);
  Future<void> savePatch(UserSettings settings, Map<String, dynamic> patch);
  void cancelPendingOperations();
}

class AppSettingsRepository
    implements SettingsRepository, SessionSettingsRepository {
  AppSettingsRepository({
    required SharedPreferences preferences,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required String? userId,
    required bool emailVerified,
    SettingsSession? session,
  }) : _preferences = preferences,
       _firestore = firestore,
       _auth = auth,
       _userId = userId,
       _emailVerified = emailVerified,
       _session =
           session ?? SettingsSession(uid: userId, verified: emailVerified) {
    // Provider-created repositories share the tracker. Standalone repositories
    // also invalidate their own lifetime on auth transitions.
    if (session == null) {
      _sessionSubscription = auth.authStateChanges().listen((user) {
        if (user?.uid != _userId ||
            (user?.emailVerified == true) != _emailVerified) {
          _session.invalidate();
        }
      });
    }
  }

  static const _prefix = 'eq_results.';
  final SharedPreferences _preferences;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String? _userId;
  final bool _emailVerified;
  final SettingsSession _session;
  StreamSubscription<User?>? _sessionSubscription;
  bool _cancelled = false;
  bool? _serverDocumentExists;

  @override
  bool get isCurrentSession {
    final user = _auth.currentUser;
    return !_cancelled &&
        _session.isActive &&
        user?.uid == _userId &&
        (user?.emailVerified == true) == _emailVerified;
  }

  @override
  void cancelPendingOperations() {
    _cancelled = true;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
  }

  @override
  Future<UserSettings> load() async {
    if (!isCurrentSession) return loadLocal();
    if (_userId != null && _emailVerified) {
      final snapshot = await _settingsDoc(_userId).get();
      if (!isCurrentSession) return loadLocal();
      final data = snapshot.data();
      _serverDocumentExists = data != null;
      if (data != null) return UserSettings.fromMap(data);
    }
    return loadLocal();
  }

  @override
  Future<void> save(UserSettings settings) =>
      savePatch(settings, settings.toMap());

  @override
  Future<void> savePatch(
    UserSettings settings,
    Map<String, dynamic> patch,
  ) async {
    if (!isCurrentSession) return;
    // Creation must include the required schema fields. Only a successful
    // read proving absence permits initialization from the loaded settings.
    final values = _serverDocumentExists == false
        ? settings.toMap()
        : Map<String, dynamic>.from(patch);
    await saveLocal(settings);
    if (_userId == null || !_emailVerified || !isCurrentSession) return;
    if (_serverDocumentExists == null) {
      throw StateError('Account settings have not been read.');
    }
    await _settingsDoc(_userId).set(values, SetOptions(merge: true));
    if (isCurrentSession) _serverDocumentExists = true;
  }

  @override
  UserSettings loadLocal() {
    return UserSettings.fromMap({
      'localeCode': _preferences.getString('${_prefix}localeCode'),
      'defaultEventId': _preferences.getString('${_prefix}defaultEventId'),
      'defaultClassId': _preferences.getString('${_prefix}defaultClassId'),
      'preferredSplitId': _preferences.getString('${_prefix}preferredSplitId'),
      'tableDensity': _preferences.getString('${_prefix}tableDensity'),
      'themeVariant': _preferences.getString('${_prefix}themeVariant'),
    });
  }

  @override
  Future<void> saveLocal(UserSettings settings) async {
    for (final entry in settings.toMap().entries) {
      if (!isCurrentSession) return;
      final value = entry.value as String?;
      final key = '$_prefix${entry.key}';
      final saved = value == null || value.isEmpty
          ? await _preferences.remove(key)
          : await _preferences.setString(key, value);
      if (!isCurrentSession) return;
      if (!saved) throw StateError('Settings could not be saved locally.');
    }
  }

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('app');
  }
}
