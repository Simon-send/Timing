import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:results/app/app_providers.dart';
import 'package:results/app/app_router.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/app/results_app.dart';
import 'package:results/features/settings/data/settings_repository.dart';
import 'package:results/features/settings/domain/user_settings.dart';
import 'package:results/l10n/app_localizations.dart';

class _User implements User {
  _User(this.uid, {this.emailVerified = true});
  @override
  final String uid;
  @override
  final bool emailVerified;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  User? user;
  final ready = Completer<void>();
  late final StreamController<User?> changes =
      StreamController<User?>.broadcast(
        onListen: () {
          if (!ready.isCompleted) ready.complete();
        },
      );
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() async* {
    yield user;
    yield* changes.stream;
  }

  void change(User? next) {
    user = next;
    changes.add(next);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Independent entry/completion boundaries; errors happen after release.
class _Control {
  _Control({bool held = false, this.error, this.result = true}) {
    if (!held) release();
  }
  final gate = Completer<void>();
  final finished = Completer<void>();
  final Object? error;
  final bool result;
  void release() {
    if (!gate.isCompleted) gate.complete();
  }

  Future<bool> run() async {
    try {
      await gate.future;
      if (error != null) throw error!;
      return result;
    } finally {
      finished.complete();
    }
  }
}

class _Calls<T> {
  final values = <T>[];
  final _waiting = <int, Completer<T>>{};
  void add(T value) {
    final index = values.length;
    values.add(value);
    _waiting.remove(index)?.complete(value);
  }

  Future<T> at(int index) => index < values.length
      ? Future.value(values[index])
      : (_waiting[index] ??= Completer<T>()).future;
}

class _LocalWrite {
  _LocalWrite(this.key, this.value, this.control);
  final String key;
  final String? value;
  final _Control control;
}

class _Preferences implements SharedPreferences {
  final values = <String, String>{};
  final controls = <_Control>[];
  final calls = _Calls<_LocalWrite>();
  @override
  String? getString(String key) => values[key];
  Future<bool> _write(String key, String? value) async {
    final index = calls.values.length;
    final control = index < controls.length ? controls[index] : _Control();
    // SharedPreferences updates its cache before the platform future resolves.
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    calls.add(_LocalWrite(key, value, control));
    return control.run();
  }

  @override
  Future<bool> setString(String key, String value) => _write(key, value);
  @override
  Future<bool> remove(String key) => _write(key, null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Read {
  _Read(this.path, this.snapshot, this.control);
  final String path;
  final Map<String, dynamic>? snapshot;
  final _Control control;
}

class _Write {
  _Write(this.path, this.patch, this.control);
  final String path;
  final Map<String, dynamic> patch;
  final _Control control;
  bool committed = false;
}

class _Firestore implements FirebaseFirestore {
  final data = <String, Map<String, dynamic>>{};
  final readControls = <_Control>[];
  final writeControls = <_Control>[];
  final reads = _Calls<_Read>();
  final writes = _Calls<_Write>();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only controlled boundary for the plugin API.
// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(db, '${this.path}/$path');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only controlled boundary for the plugin API.
// ignore: subtype_of_sealed_class
class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(db, '${this.path}/$path');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final index = db.reads.values.length;
    final control = index < db.readControls.length
        ? db.readControls[index]
        : _Control();
    // A stale request returns its own snapshot, never the replacement's data.
    final source = db.data[path];
    final request = _Read(
      path,
      source == null ? null : Map.of(source),
      control,
    );
    db.reads.add(request);
    await control.run();
    return _Snapshot(request.snapshot);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    expect(options?.merge, true);
    final index = db.writes.values.length;
    final control = index < db.writeControls.length
        ? db.writeControls[index]
        : _Control();
    final request = _Write(path, Map.unmodifiable(data), control);
    db.writes.add(request);
    await control.run();
    db.data[path] = {...?db.data[path], ...request.patch};
    request.committed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only controlled boundary for the plugin API.
// ignore: subtype_of_sealed_class
class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _a = 'users/A/settings/app';
const _b = 'users/B/settings/app';

class _Fixture {
  _Fixture({User? user, void Function(_Fixture)? configure, bool app = false}) {
    auth.user = user;
    db.data[_a] = UserSettings.defaults()
        .copyWith(
          localeCode: 'de',
          defaultEventId: '99',
          defaultClassId: '7',
          preferredSplitId: 'finish',
          themeVariant: AppThemeVariant.graphite,
        )
        .toMap();
    db.data[_b] = UserSettings.defaults()
        .copyWith(localeCode: 'sv', defaultEventId: '55', defaultClassId: '8')
        .toMap();
    preferences.values['eq_results.localeCode'] = 'nb';
    configure?.call(
      this,
    ); // All initial gates/failures precede provider startup.
    if (app) {
      router = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(path: '/test', builder: (_, _) => const _SettingsView()),
        ],
      );
    }
    container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firebaseFirestoreProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(preferences),
        if (app) appRouterProvider.overrideWithValue(router!),
        if (app) googleRedirectProvider.overrideWith((ref) async => null),
      ],
    );
    subscription = container.listen(settingsControllerProvider, (_, _) {});
    // Register before any readiness waits or assertions can fail.
    addTearDown(close);
  }
  final auth = _Auth();
  final db = _Firestore();
  final preferences = _Preferences();
  final pending = <Future<void>>[];
  late final ProviderContainer container;
  late final ProviderSubscription<UserSettings> subscription;
  GoRouter? router;
  bool _disposed = false;
  bool _closed = false;
  SettingsController get controller =>
      container.read(settingsControllerProvider.notifier);
  UserSettings get settings => container.read(settingsControllerProvider);
  Future<void> track(Future<void> operation) {
    pending.add(operation);
    return operation;
  }

  Future<void> start({
    SettingsSyncStatus? status = SettingsSyncStatus.ready,
  }) async {
    await auth.ready.future;
    await container.read(authStateProvider.future);
    await container
        .pump(); // Flush scheduled Riverpod rebuilds, not elapsed time.
    if (status != null) await _status(controller, status);
  }

  Future<void> change(
    User? user, {
    SettingsSyncStatus? status = SettingsSyncStatus.ready,
  }) async {
    final delivered = Completer<void>();
    final observed = container.listen(authStateProvider, (_, next) {
      if (next.hasError && !delivered.isCompleted) {
        delivered.completeError(next.error!, next.stackTrace);
      } else if (next.asData != null &&
          identical(next.asData!.value, user) &&
          !delivered.isCompleted) {
        delivered.complete();
      }
    });
    try {
      auth.change(user);
      await delivered.future;
      await container.pump();
      expect(container.read(authStateProvider).asData?.value, same(user));
    } finally {
      observed.close();
    }
    if (status != null) await _status(controller, status);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    subscription.close();
    container.dispose();
    router?.dispose();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    dispose();
    for (final control in [
      ...db.readControls,
      ...db.writeControls,
      ...preferences.controls,
    ]) {
      control.release();
    }
    await Future.wait(pending);
    await Future.wait([
      for (final call in db.reads.values) call.control.finished.future,
      for (final call in db.writes.values) call.control.finished.future,
      for (final call in preferences.calls.values) call.control.finished.future,
    ]);
    await auth.changes.close();
  }
}

Future<void> _status(
  SettingsController controller,
  SettingsSyncStatus wanted,
) async {
  if (controller.syncStatus.value == wanted) return;
  final done = Completer<void>();
  void changed() {
    if (controller.syncStatus.value == wanted && !done.isCompleted) {
      done.complete();
    }
  }

  controller.syncStatus.addListener(changed);
  try {
    await done.future;
  } finally {
    controller.syncStatus.removeListener(changed);
  }
}

class _SettingsView extends ConsumerWidget {
  const _SettingsView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      body: Text(
        'locale:${settings.localeCode};density:${settings.tableDensity.name}',
      ),
    );
  }
}

void main() {
  test(
    'anonymous login loads A and first edit preserves account fields (S01,S02)',
    () async {
      final f = _Fixture();
      await f.start();
      expect(f.settings.localeCode, 'nb');
      expect(f.db.reads.values, isEmpty);
      await f.change(_User('A'));
      final original = f.controller;
      final session = f.container.read(settingsSessionProvider);
      expect(f.settings.toMap(), f.db.data[_a]);
      await f.track(f.controller.setLocale('en'));
      expect(f.db.writes.values.single.patch, {'localeCode': 'en'});
      expect(f.db.data[_a], {
        ...UserSettings.defaults()
            .copyWith(
              localeCode: 'de',
              defaultEventId: '99',
              defaultClassId: '7',
              preferredSplitId: 'finish',
              themeVariant: AppThemeVariant.graphite,
            )
            .toMap(),
        'localeCode': 'en',
      });
      await f.change(_User('A'));
      expect(f.controller, same(original));
      expect(f.container.read(settingsSessionProvider), same(session));
      expect(f.db.reads.values.map((r) => r.path), [_a]);
    },
  );

  test('edits wait for load and serialize behind pending save (S09)', () async {
    final load = _Control(held: true);
    final save = _Control(held: true);
    final f = _Fixture(
      user: _User('A'),
      configure: (f) {
        f.db.readControls.add(load);
        f.db.writeControls.add(save);
      },
    );
    await f.start(status: null);
    await f.db.reads.at(0);
    final first = f.track(f.controller.setLocale('en'));
    final second = f.track(f.controller.setTableDensity(TableDensity.compact));
    expect(f.db.writes.values, isEmpty);
    expect(f.preferences.calls.values, isEmpty);
    load.release();
    final write = await f.db.writes.at(0);
    expect(write.patch, {'localeCode': 'en'});
    expect(write.committed, false);
    expect(f.db.writes.values, hasLength(1));
    expect(f.settings.localeCode, 'en');
    expect(f.settings.tableDensity, TableDensity.comfortable);
    save.release();
    await Future.wait([first, second]);
    expect(f.db.writes.values.map((r) => r.patch), [
      {'localeCode': 'en'},
      {'tableDensity': 'compact'},
    ]);
    expect(f.db.data[_a]!['defaultEventId'], '99');
    expect(f.db.data[_a]!['preferredSplitId'], 'finish');
    expect(f.db.data[_a]!['tableDensity'], 'compact');
    expect(write.patch, {'localeCode': 'en'});
  });

  for (final failLate in [false, true]) {
    test(
      'late A load/queued edit cannot affect B, lateFailure=$failLate (S05)',
      () async {
        final load = _Control(
          held: true,
          error: failLate ? StateError('late load') : null,
        );
        final f = _Fixture(
          user: _User('A'),
          configure: (f) => f.db.readControls.add(load),
        );
        await f.start(status: null);
        await f.db.reads.at(0);
        final old = f.controller;
        final edit = f.track(old.setLocale('en'));
        await f.change(_User('B'));
        expect(f.settings.localeCode, 'sv');
        load.release();
        await edit;
        expect(f.settings.toMap(), f.db.data[_b]);
        expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
        expect(f.db.writes.values, isEmpty);
        await f.track(f.controller.setTableDensity(TableDensity.compact));
        expect(f.db.writes.values.single.path, _b);
        expect(f.db.data[_b]!['defaultEventId'], '55');
        expect(f.db.data[_a]!['localeCode'], 'de');
        await f.change(_User('A'));
        expect(f.settings.localeCode, 'de');
        expect(f.db.reads.values.map((r) => r.path), [_a, _b, _a]);
      },
    );
  }

  for (final coalesced in [false, true]) {
    test(
      'A logout A invalidates held load even with identical User, coalesced=$coalesced (S03)',
      () async {
        final user = _User('A');
        final load = _Control(held: true);
        final f = _Fixture(
          user: user,
          configure: (f) => f.db.readControls.add(load),
        );
        await f.start(status: null);
        await f.db.reads.at(0);
        final old = f.controller;
        final lifetime = f.container.read(settingsSessionProvider);
        final edit = f.track(old.setLocale('en'));
        if (coalesced) {
          f.auth.change(null);
          f.auth.change(user);
          await f.db.reads.at(1);
          await f.container.pump();
          await _status(f.controller, SettingsSyncStatus.ready);
        } else {
          await f.change(null);
          await f.change(user);
        }
        expect(f.container.read(authStateProvider).asData?.value, same(user));
        expect(f.container.read(authStateProvider).hasError, false);
        expect(lifetime.isActive, false);
        expect(f.controller, isNot(same(old)));
        expect(f.db.reads.values.map((r) => r.path), [_a, _a]);
        load.release();
        await edit;
        expect(f.settings.localeCode, 'de');
        expect(f.db.writes.values, isEmpty);
        expect(f.preferences.calls.values, isEmpty);
      },
    );
  }

  for (final next in ['B', 'A']) {
    test(
      'repository cannot resume A local save after transition to $next (S04,S06)',
      () async {
        final local = _Control(held: true);
        final user = _User('A');
        final f = _Fixture(
          user: user,
          configure: (f) => f.preferences.controls.add(local),
        );
        await f.start();
        final old = f.controller;
        final save = f.track(old.setLocale('en'));
        await f.preferences.calls.at(0);
        expect(f.preferences.calls.values, hasLength(1));
        if (next == 'A') {
          // No intervening provider flush: tracker must remember the logout.
          f.auth.change(null);
          f.auth.change(user);
          await f.db.reads.at(1);
          await f.container.pump();
          await _status(f.controller, SettingsSyncStatus.ready);
        } else {
          await f.change(_User('B'));
        }
        expect(f.container.read(authStateProvider).hasError, false);
        expect(f.container.read(authStateProvider).asData?.value?.uid, next);
        final current = f.controller;
        final expected = next == 'A' ? 'de' : 'sv';
        expect(f.settings.localeCode, expected);
        local.release();
        await save;
        await f.track(old.retry());
        expect(f.controller, same(current));
        expect(f.settings.localeCode, expected);
        expect(f.preferences.calls.values, hasLength(1));
        expect(f.db.writes.values, isEmpty);
        expect(f.db.data[_a]!['localeCode'], 'de');
        expect(f.db.data[_b]!['localeCode'], 'sv');
      },
    );
  }

  test(
    'anonymous/unverified edits stay local and verification creates session (S11)',
    () async {
      final f = _Fixture();
      await f.start();
      await f.track(f.controller.setLocale('en'));
      await f.change(_User('U', emailVerified: false));
      expect(f.settings.localeCode, 'en');
      await f.track(f.controller.setTableDensity(TableDensity.compact));
      expect(f.db.reads.values, isEmpty);
      expect(f.db.writes.values, isEmpty);
      expect(f.preferences.values['eq_results.tableDensity'], 'compact');
      await f.change(_User('A'));
      expect(f.settings.localeCode, 'de');
      await f.change(_User('A', emailVerified: false));
      final reads = f.db.reads.values.length;
      await f.track(f.controller.setLocale('fi'));
      expect(f.db.reads.values, hasLength(reads));
      expect(f.db.writes.values, isEmpty);
      expect(f.preferences.values['eq_results.localeCode'], 'fi');
      await f.change(_User('A'));
      expect(f.settings.localeCode, 'de');
      expect(f.db.reads.values.map((r) => r.path), [_a, _a]);
    },
  );

  test(
    'failed load retains choices without implicit retry; explicit retry rereads (S12,S13)',
    () async {
      final f = _Fixture(
        user: _User('A'),
        configure: (f) {
          f.db.readControls.add(_Control(error: StateError('unavailable')));
        },
      );
      await f.start(status: SettingsSyncStatus.failed);
      await f.track(f.controller.setLocale('en'));
      await f.track(f.controller.setTableDensity(TableDensity.compact));
      expect(f.settings.localeCode, 'en');
      expect(f.preferences.values['eq_results.localeCode'], 'en');
      expect(f.preferences.values['eq_results.tableDensity'], 'compact');
      expect(f.db.reads.values, hasLength(1));
      expect(f.db.writes.values, isEmpty);
      expect(f.db.data[_a]!['defaultEventId'], '99');
      f.db.data[_a]!.addAll({
        'defaultEventId': 'new-event',
        'defaultClassId': 'new-class',
        'preferredSplitId': 'new-split',
        'themeVariant': 'stadium',
      });
      await f.track(f.controller.retry());
      expect(f.db.reads.values, hasLength(2));
      expect(f.db.writes.values.single.patch, {
        'localeCode': 'en',
        'tableDensity': 'compact',
      });
      expect(f.settings.defaultEventId, 'new-event');
      expect(f.settings.defaultClassId, 'new-class');
      expect(f.settings.preferredSplitId, 'new-split');
      expect(f.settings.themeVariant, AppThemeVariant.stadium);
      expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
      final writes = f.db.writes.values.length;
      await f.track(f.controller.retry());
      expect(f.db.reads.values, hasLength(2));
      expect(f.db.writes.values, hasLength(writes));
    },
  );

  test(
    'failed load with no edits recovers by explicit read without write (S13)',
    () async {
      final f = _Fixture(
        user: _User('A'),
        configure: (f) {
          f.db.readControls.add(_Control(error: StateError('read')));
        },
      );
      await f.start(status: SettingsSyncStatus.failed);
      await f.track(f.controller.retry());
      expect(f.settings.localeCode, 'de');
      expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
      expect(f.db.writes.values, isEmpty);
    },
  );

  test(
    'cloud failure keeps local edits; later edits do not retry automatically (S14,S15,S02)',
    () async {
      final retryLoad = _Control(held: true);
      final f = _Fixture(
        user: _User('A'),
        configure: (f) {
          f.db.writeControls.add(_Control(error: StateError('save')));
          f.db.readControls.addAll([_Control(), retryLoad]);
        },
      );
      await f.start();
      final original = f.controller;
      await f.track(original.setLocale('en'));
      expect(original.syncStatus.value, SettingsSyncStatus.failed);
      expect(f.preferences.values['eq_results.localeCode'], 'en');
      expect(f.db.data[_a]!['localeCode'], 'de');
      await f.change(_User('A'), status: SettingsSyncStatus.failed);
      expect(f.controller, same(original));
      expect(f.controller.syncStatus.value, SettingsSyncStatus.failed);
      await f.track(original.setTableDensity(TableDensity.compact));
      expect(f.db.writes.values, hasLength(1));
      expect(f.db.reads.values, hasLength(1));
      f.db.data[_a]!.addAll({
        'defaultEventId': 'server-new',
        'themeVariant': 'stadium',
      });
      final retry = f.track(original.retry());
      final duplicate = original.retry();
      expect(duplicate, same(retry));
      await f.db.reads.at(1);
      final edit = f.track(original.setPreferredSplit('lap2'));
      expect(f.db.writes.values, hasLength(1));
      retryLoad.release();
      await Future.wait([retry, duplicate, edit]);
      expect(f.db.writes.values.map((r) => r.patch), [
        {'localeCode': 'en'},
        {'localeCode': 'en', 'tableDensity': 'compact'},
        {'preferredSplitId': 'lap2'},
      ]);
      expect(f.db.data[_a]!['defaultEventId'], 'server-new');
      expect(f.settings.themeVariant, AppThemeVariant.stadium);
      expect(f.settings.preferredSplitId, 'lap2');
      expect(original.syncStatus.value, SettingsSyncStatus.ready);
    },
  );

  test(
    'failed explicit retry retains patch and does not poison queue (S15)',
    () async {
      final f = _Fixture(
        user: _User('A'),
        configure: (f) {
          f.db.readControls.addAll([
            _Control(error: StateError('initial')),
            _Control(error: StateError('retry')),
          ]);
        },
      );
      await f.start(status: SettingsSyncStatus.failed);
      await f.track(f.controller.setLocale('en'));
      await f.track(f.controller.retry());
      expect(f.controller.syncStatus.value, SettingsSyncStatus.failed);
      expect(f.settings.localeCode, 'en');
      await f.track(f.controller.setPreferredSplit('lap'));
      expect(f.db.reads.values, hasLength(2));
      expect(f.db.writes.values, isEmpty);
      await f.track(f.controller.retry());
      expect(f.db.writes.values.single.patch, {
        'localeCode': 'en',
        'preferredSplitId': 'lap',
      });
      expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
    },
  );

  test('explicit null clears survive failure and reread (S10)', () async {
    final f = _Fixture(
      user: _User('A'),
      configure: (f) {
        f.db.writeControls.add(_Control(error: StateError('clear')));
      },
    );
    await f.start();
    await f.track(f.controller.setDefaultEvent(null));
    await f.track(f.controller.setDefaultClass(null));
    await f.track(f.controller.setPreferredSplit(null));
    expect(f.db.writes.values, hasLength(1));
    expect(f.settings.defaultEventId, isNull);
    expect(f.settings.defaultClassId, isNull);
    expect(f.settings.preferredSplitId, isNull);
    expect(
      f.preferences.values.containsKey('eq_results.defaultEventId'),
      false,
    );
    f.db.data[_a]!.addAll({
      'defaultEventId': 'server-event',
      'defaultClassId': 'server-class',
      'preferredSplitId': 'server-split',
      'themeVariant': 'stadium',
    });
    await f.track(f.controller.retry());
    expect(f.db.writes.values.last.patch, {
      'defaultEventId': null,
      'defaultClassId': null,
      'preferredSplitId': null,
    });
    expect(f.db.data[_a]!['defaultEventId'], isNull);
    expect(f.db.data[_a]!['defaultClassId'], isNull);
    expect(f.db.data[_a]!['preferredSplitId'], isNull);
    expect(f.settings.themeVariant, AppThemeVariant.stadium);
    expect(f.settings.localeCode, 'de');
  });

  for (final remove in [false, true]) {
    for (final throws in [false, true]) {
      test(
        'local ${remove ? 'remove' : 'setString'} ${throws ? 'throws' : 'returns false'} surfaces error/recovery (S16)',
        () async {
          final f = _Fixture(
            user: _User('A'),
            configure: (f) {
              if (remove) f.preferences.controls.add(_Control());
              f.preferences.controls.add(
                _Control(
                  result: throws,
                  error: throws ? StateError('device storage') : null,
                ),
              );
            },
          );
          await f.start();
          await f.track(
            remove
                ? f.controller.setDefaultEvent(null)
                : f.controller.setLocale('en'),
          );
          expect(f.controller.syncStatus.value, SettingsSyncStatus.failed);
          expect(f.db.writes.values, isEmpty);
          if (remove) {
            expect(f.settings.defaultEventId, isNull);
            expect(
              f.preferences.calls.values.last.key,
              'eq_results.defaultEventId',
            );
          } else {
            expect(f.settings.localeCode, 'en');
            expect(f.preferences.values['eq_results.localeCode'], 'en');
          }
          await f.track(f.controller.setTableDensity(TableDensity.compact));
          expect(f.db.writes.values, isEmpty);
          expect(f.db.reads.values, hasLength(1));
          await f.track(f.controller.retry());
          expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
          expect(f.preferences.values['eq_results.tableDensity'], 'compact');
          expect(
            f.db.writes.values.single.patch,
            remove
                ? {
                    'defaultEventId': null,
                    'defaultClassId': null,
                    'tableDensity': 'compact',
                  }
                : {'localeCode': 'en', 'tableDensity': 'compact'},
          );
        },
      );
    }
  }

  test(
    'new verified document first save initializes all required settings only after read',
    () async {
      final f = _Fixture(
        user: _User('A'),
        configure: (f) => f.db.data.remove(_a),
      );
      await f.start();
      expect(f.db.reads.values.single.snapshot, isNull);
      await f.track(f.controller.setLocale('en'));
      expect(
        f.db.writes.values.single.patch,
        UserSettings.defaults().copyWith(localeCode: 'en').toMap(),
      );
      await f.track(f.controller.setTableDensity(TableDensity.compact));
      expect(f.db.writes.values.last.patch, {'tableDensity': 'compact'});
      expect(f.db.data[_a]!['themeVariant'], 'nordicDark');
    },
  );

  test(
    'failed missing-document read cannot create defaults before explicit retry',
    () async {
      final f = _Fixture(
        user: _User('A'),
        configure: (f) {
          f.db.data.remove(_a);
          f.db.readControls.add(_Control(error: StateError('unknown base')));
        },
      );
      await f.start(status: SettingsSyncStatus.failed);
      await f.track(f.controller.setLocale('en'));
      expect(f.db.reads.values, hasLength(1));
      expect(f.db.writes.values, isEmpty);
      expect(f.db.data.containsKey(_a), false);
      expect(f.preferences.values['eq_results.localeCode'], 'en');
      await f.track(f.controller.retry());
      expect(f.db.reads.values, hasLength(2));
      expect(
        f.db.writes.values.single.patch,
        UserSettings.defaults().copyWith(localeCode: 'en').toMap(),
      );
      expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
    },
  );

  test(
    'held retry and queued edit cannot affect replacement account (S17)',
    () async {
      final held = _Control(held: true);
      final f = _Fixture(
        user: _User('A'),
        configure: (f) => f.db.readControls.addAll([
          _Control(error: StateError('initial')),
          held,
        ]),
      );
      await f.start(status: SettingsSyncStatus.failed);
      final old = f.controller;
      await f.track(old.setLocale('en'));
      final retry = f.track(old.retry());
      await f.db.reads.at(1);
      final queued = f.track(old.setTableDensity(TableDensity.compact));
      await f.change(_User('B'));
      final current = f.controller;
      final localCount = f.preferences.calls.values.length;
      held.release();
      await Future.wait([retry, queued]);
      await f.track(old.retry());
      expect(f.controller, same(current));
      expect(f.settings.toMap(), f.db.data[_b]);
      expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
      expect(f.preferences.calls.values, hasLength(localCount));
      expect(f.db.writes.values, isEmpty);
      expect(f.db.reads.values.map((r) => r.path), [_a, _a, _b]);
    },
  );

  for (final next in ['B', 'A']) {
    for (final failure in [false, true]) {
      test(
        'already issued A cloud write cannot affect $next session, failure=$failure (S07,S08)',
        () async {
          final cloud = _Control(
            held: true,
            error: failure ? StateError('late save') : null,
          );
          final user = _User('A');
          final f = _Fixture(
            user: user,
            configure: (f) => f.db.writeControls.add(cloud),
          );
          await f.start();
          final old = f.controller;
          final first = f.track(old.setLocale('en'));
          final queued = f.track(old.setTableDensity(TableDensity.compact));
          final request = await f.db.writes.at(0);
          expect(request.path, _a);
          expect(request.committed, false);
          if (next == 'A') {
            f.auth.change(null);
            f.auth.change(user);
            await f.db.reads.at(1);
            await f.container.pump();
            await _status(f.controller, SettingsSyncStatus.ready);
          } else {
            await f.change(_User('B'));
          }
          final current = f.controller;
          final before = f.settings.toMap();
          cloud.release();
          await Future.wait([first, queued]);
          await f.track(old.retry());
          expect(f.controller, same(current));
          expect(f.settings.toMap(), before);
          expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
          expect(f.db.writes.values, hasLength(1));
          expect(request.path, _a);
          expect(request.committed, !failure);
          expect(f.db.data[_b]!['localeCode'], 'sv');
          await f.track(current.setPreferredSplit('current'));
          expect(f.db.writes.values.last.path, next == 'A' ? _a : _b);
          expect(f.db.writes.values.last.patch, {
            'preferredSplitId': 'current',
          });
        },
      );
    }
  }

  test(
    'failed controller retry after account switch has no side effects (S17)',
    () async {
      final f = _Fixture(
        user: _User('A'),
        configure: (f) {
          f.db.writeControls.add(_Control(error: StateError('save')));
        },
      );
      await f.start();
      final old = f.controller;
      await f.track(old.setLocale('en'));
      expect(old.syncStatus.value, SettingsSyncStatus.failed);
      await f.change(_User('B'));
      final localCount = f.preferences.calls.values.length;
      final readCount = f.db.reads.values.length;
      await f.track(old.retry());
      expect(f.preferences.calls.values, hasLength(localCount));
      expect(f.db.reads.values, hasLength(readCount));
      expect(f.db.writes.values, hasLength(1));
      expect(f.settings.localeCode, 'sv');
      expect(f.controller.syncStatus.value, SettingsSyncStatus.ready);
    },
  );

  for (final boundary in ['load', 'local', 'cloud', 'retry']) {
    for (final failure in [false, true]) {
      test(
        'disposal during $boundary, failure=$failure cancels queued effects (S18)',
        () async {
          final held = _Control(
            held: true,
            error: failure ? StateError('late $boundary') : null,
          );
          final f = _Fixture(
            user: _User('A'),
            configure: (f) {
              if (boundary == 'load') f.db.readControls.add(held);
              if (boundary == 'local') f.preferences.controls.add(held);
              if (boundary == 'cloud') f.db.writeControls.add(held);
              if (boundary == 'retry') {
                f.db.readControls.addAll([
                  _Control(error: StateError('initial')),
                  held,
                ]);
              }
            },
          );
          await f.start(
            status: boundary == 'load'
                ? null
                : boundary == 'retry'
                ? SettingsSyncStatus.failed
                : SettingsSyncStatus.ready,
          );
          final old = f.controller;
          Future<void> operation;
          if (boundary == 'retry') {
            await f.track(old.setLocale('en'));
            operation = f.track(old.retry());
            await f.db.reads.at(1);
          } else {
            operation = f.track(old.setLocale('en'));
            if (boundary == 'load') await f.db.reads.at(0);
            if (boundary == 'local') await f.preferences.calls.at(0);
            if (boundary == 'cloud') await f.db.writes.at(0);
          }
          final queued = f.track(old.setTableDensity(TableDensity.compact));
          final localCount = f.preferences.calls.values.length;
          final cloudCount = f.db.writes.values.length;
          f.dispose();
          held.release();
          await Future.wait([operation, queued]);
          await f.track(old.retry());
          expect(f.preferences.calls.values, hasLength(localCount));
          expect(f.db.writes.values, hasLength(cloudCount));
          expect(f.db.data[_b]!['localeCode'], 'sv');
        },
      );
    }
  }

  test(
    'settings-only consumer retains auth delivery without an auth listener',
    () async {
      final user = _User('A');
      final f = _Fixture(user: user);
      // Reading/listening to authState here would hide a paused subscription.
      await f.auth.ready.future;
      await _status(f.controller, SettingsSyncStatus.ready);
      expect(f.settings.localeCode, 'de');
      f.auth.change(_User('B'));
      await f.db.reads.at(1);
      await f.container.pump();
      await _status(f.controller, SettingsSyncStatus.ready);
      expect(f.settings.localeCode, 'sv');
      f.auth.change(null);
      f.auth.change(user);
      await f.db.reads.at(2);
      await f.container.pump();
      await _status(f.controller, SettingsSyncStatus.ready);
      expect(f.settings.localeCode, 'de');
      expect(f.db.reads.values.map((r) => r.path), [_a, _b, _a]);
      expect(f.container.read(authStateProvider).asData?.value, same(user));
      expect(f.container.read(authStateProvider).hasError, false);
    },
  );

  test(
    'stale repository skips all local/cloud side effects, even matching UID (S19)',
    () async {
      final user = _User('A');
      final f = _Fixture(user: user);
      await f.start();
      final repository =
          f.container.read(settingsRepositoryProvider) as AppSettingsRepository;
      await f.change(null);
      await f.change(user);
      expect(repository.isCurrentSession, false);
      final readCount = f.db.reads.values.length;
      await repository.save(UserSettings.defaults());
      await repository.saveLocal(UserSettings.defaults());
      await repository.savePatch(UserSettings.defaults(), {'localeCode': 'en'});
      expect(f.preferences.calls.values, isEmpty);
      expect(f.db.writes.values, isEmpty);
      await repository.load();
      expect(f.db.reads.values, hasLength(readCount));
    },
  );

  for (final locale in ['nb', 'en']) {
    testWidgets(
      'actual app $locale failure banner retains choice and retries current session (S20)',
      (tester) async {
        late final _Fixture f;
        await tester.runAsync(() async {
          // Create async repositories in the real event loop used for readiness.
          f = _Fixture(
            user: _User('A'),
            app: true,
            configure: (f) {
              f.db.readControls.add(_Control(error: StateError('read')));
              f.preferences.values['eq_results.localeCode'] = locale;
            },
          );
          await f.start(status: SettingsSyncStatus.failed);
          await f.track(f.controller.setLocale(locale));
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: f.container,
            child: const ResultsApp(),
          ),
        );
        final context = tester.element(find.byType(_SettingsView));
        final l10n = AppLocalizations.of(context);
        final message = l10n.settingsSyncFailed;
        final action = l10n.settingsRetry;
        expect(action, locale == 'nb' ? 'Prøv igjen' : 'Try again');
        expect(find.text(message), findsOneWidget);
        expect(find.widgetWithText(TextButton, action), findsOneWidget);
        expect(find.text('locale:$locale;density:comfortable'), findsOneWidget);
        final current = f.controller;
        await tester.runAsync(() async {
          final recovered = _status(current, SettingsSyncStatus.ready);
          await tester.tap(find.widgetWithText(TextButton, action));
          await recovered;
        });
        // Render the already-observed successful state and locale.
        await tester.pump();
        expect(find.text(message), findsNothing);
        expect(find.widgetWithText(TextButton, action), findsNothing);
        expect(find.text('locale:$locale;density:comfortable'), findsOneWidget);
        expect(f.db.writes.values.single.patch, {'localeCode': locale});
        expect(f.db.data[_a]!['defaultEventId'], '99');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
