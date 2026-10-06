import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/athlete/domain/athlete_stage_result.dart';
import '../features/events/data/events_repository.dart';
import '../features/events/domain/result_event.dart';
import '../features/favorites/data/favorite_athletes_repository.dart';
import '../features/profile/data/athlete_profile_repository.dart';
import '../features/profile/domain/athlete_link_state.dart';
import '../features/profile/domain/athlete_profile.dart';
import '../features/results/data/results_repository.dart';
import '../features/results/domain/race_result.dart';
import '../features/results/domain/competition_stage.dart';
import '../features/results/domain/result_class.dart';
import '../features/results/domain/result_sort_mode.dart';
import '../features/results/domain/split_def.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/user_settings.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be provided by ResultsApp.');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(auth: ref.watch(firebaseAuthProvider));
});

final settingsSessionTrackerProvider = Provider<SettingsSessionTracker>((ref) {
  final tracker = SettingsSessionTracker(
    ref.watch(authRepositoryProvider).currentUser,
  );
  ref.onDispose(tracker.dispose);
  return tracker;
});

final StreamProvider<User?> authStateProvider = StreamProvider<User?>((ref) {
  final tracker = ref.watch(settingsSessionTrackerProvider);
  return ref.watch(authRepositoryProvider).authStateChanges().map((user) {
    // Invalidate at stream delivery, before Riverpod can coalesce refreshes.
    tracker.update(user);
    return user;
  });
});

/// One redirect completion per application scope, independent of the route.
final googleRedirectProvider = FutureProvider<User?>(retry: (_, _) => null, (
  ref,
) async {
  final repository = ref.read(authRepositoryProvider);
  final preferences = ref.read(sharedPreferencesProvider);
  const key = 'google_sign_in_redirect_pending';
  final pending = preferences.getBool(key) == true;
  try {
    final user = await repository.completeGoogleRedirect();
    if (pending && user == null && repository.currentUser == null) {
      throw FirebaseAuthException(code: 'redirect-cancelled-by-user');
    }
    return user ?? (pending ? repository.currentUser : null);
  } finally {
    if (pending) await preferences.remove(key);
  }
});

/// Changes when the browser returns to the foreground or the user retries a
/// failed load, recreating Firestore subscriptions without reloading the page.
final appDataRefreshProvider = StateProvider<int>((ref) => 0);

void refreshAppData(WidgetRef ref) {
  ref.read(appDataRefreshProvider.notifier).state++;
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return FirestoreEventsRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

final resultsRepositoryProvider = Provider<ResultsRepository>((ref) {
  return FirestoreResultsRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

final favoriteAthletesRepositoryProvider = Provider<FavoriteAthletesRepository>(
  (ref) => FirestoreFavoriteAthletesRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
  ),
);

final favoriteAthleteIdsProvider = StreamProvider<Set<String>>((ref) {
  ref.watch(appDataRefreshProvider);
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(const <String>{});
  return ref
      .watch(favoriteAthletesRepositoryProvider)
      .watchFavoriteAthleteIds(user.uid);
});

final Provider<SettingsSession> settingsSessionProvider =
    Provider<SettingsSession>((ref) {
      final tracker = ref.watch(settingsSessionTrackerProvider);
      void changed() => ref.invalidateSelf();
      tracker.addListener(changed);
      ref.onDispose(() => tracker.removeListener(changed));
      return tracker.current;
    });

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  // Keep auth delivery active without rebuilding for every AsyncData emission.
  // A read alone can pause Riverpod's stream when its last listener closes.
  ref.listen(authStateProvider, (_, _) {});
  final session = ref.watch(settingsSessionProvider);
  final repository = AppSettingsRepository(
    preferences: ref.watch(sharedPreferencesProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    userId: session.uid,
    emailVerified: session.verified,
    session: session,
  );
  ref.onDispose(repository.cancelPendingOperations);
  return repository;
});

final athleteProfileRepositoryProvider = Provider<AthleteProfileRepository>((
  ref,
) {
  return FirestoreAthleteProfileRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, UserSettings>((ref) {
      return SettingsController(ref.watch(settingsRepositoryProvider));
    });

final settingsSyncStatusProvider = Provider<SettingsSyncStatus>((ref) {
  final controller = ref.watch(settingsControllerProvider.notifier);
  void changed() => ref.invalidateSelf();
  controller.syncStatus.addListener(changed);
  ref.onDispose(() => controller.syncStatus.removeListener(changed));
  return controller.syncStatus.value;
});

final eventsProvider = StreamProvider<List<ResultEvent>>((ref) {
  ref.watch(appDataRefreshProvider);
  return ref.watch(eventsRepositoryProvider).watchEvents();
});

final linkedAthleteIdProvider = StreamProvider<String?>((ref) {
  ref.watch(appDataRefreshProvider);
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref
      .watch(athleteProfileRepositoryProvider)
      .watchLinkedAthleteId(user.uid);
});

final athleteLinkStateProvider = StreamProvider<AthleteLinkState>((ref) {
  ref.watch(appDataRefreshProvider);
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) {
    return Stream.value(
      const AthleteLinkState(athleteId: null, onboardingCompleted: true),
    );
  }
  return ref
      .watch(athleteProfileRepositoryProvider)
      .watchAthleteLinkState(user.uid);
});

final athleteProfileProvider = StreamProvider.family<AthleteProfile?, String>((
  ref,
  athleteId,
) {
  ref.watch(appDataRefreshProvider);
  return ref.watch(athleteProfileRepositoryProvider).watchAthlete(athleteId);
});

final athleteRacesProvider = StreamProvider.family<List<AthleteRace>, String>((
  ref,
  athleteId,
) {
  ref.watch(appDataRefreshProvider);
  return ref
      .watch(athleteProfileRepositoryProvider)
      .watchAthleteRaces(athleteId);
});

final linkedAthleteEventProvider = Provider.family<AthleteEvent?, String>((
  ref,
  eventId,
) {
  final athleteId = ref.watch(linkedAthleteIdProvider).asData?.value;
  if (athleteId == null) return null;

  final profile = ref.watch(athleteProfileProvider(athleteId)).asData?.value;
  if (profile == null) return null;

  for (final event in profile.events) {
    if (event.eventId == eventId && event.classId.isNotEmpty) return event;
  }
  return null;
});

final participatedEventIdsProvider = Provider<Set<String>>((ref) {
  final athleteId = ref.watch(linkedAthleteIdProvider).asData?.value;
  if (athleteId == null) return const <String>{};

  final profile = ref.watch(athleteProfileProvider(athleteId)).asData?.value;
  if (profile == null) return const <String>{};

  return {
    for (final event in profile.events)
      if (event.eventId.isNotEmpty && event.classId.isNotEmpty) event.eventId,
  };
});

final athleteAffiliationsProvider =
    FutureProvider.family<
      AthleteAffiliations,
      ({String? clubId, String? teamId})
    >((ref, args) {
      ref.watch(appDataRefreshProvider);
      return ref
          .watch(athleteProfileRepositoryProvider)
          .fetchAffiliations(clubId: args.clubId, teamId: args.teamId);
    });

final classesProvider = StreamProvider.family<List<ResultClass>, String>((
  ref,
  eventId,
) {
  ref.watch(appDataRefreshProvider);
  return ref.watch(resultsRepositoryProvider).watchClasses(eventId);
});

final competitionStagesProvider =
    StreamProvider.family<List<CompetitionStage>, String>((ref, eventId) {
      ref.watch(appDataRefreshProvider);
      return ref.watch(resultsRepositoryProvider).watchStages(eventId);
    });

final stageSplitDefsProvider =
    StreamProvider.family<
      List<SplitDef>,
      ({String eventId, String stageId, String classId})
    >((ref, args) {
      ref.watch(appDataRefreshProvider);
      return ref
          .watch(resultsRepositoryProvider)
          .watchStageSplitDefs(args.eventId, args.stageId, args.classId);
    });

final stageResultsProvider =
    StreamProvider.family<
      List<RaceResult>,
      ({String eventId, String stageId, String classId})
    >((ref, args) {
      ref.watch(appDataRefreshProvider);
      final limit = ref.watch(stageResultsLimitProvider(args));
      return ref
          .watch(resultsRepositoryProvider)
          .watchStageResults(
            args.eventId,
            args.stageId,
            args.classId,
            limit: limit,
          );
    });

final stageResultsLimitProvider =
    StateProvider.family<
      int,
      ({String eventId, String stageId, String classId})
    >((ref, args) {
      final athleteEvent = ref.watch(linkedAthleteEventProvider(args.eventId));
      if (athleteEvent?.classId != args.classId) return initialResultsLimit;
      final rank = athleteEvent!.rank;
      if (rank == null || rank <= initialResultsLimit) {
        return initialResultsLimit;
      }
      return rank;
    });

final stageResultProvider =
    StreamProvider.family<
      RaceResult?,
      ({String eventId, String stageId, String classId, String resultId})
    >((ref, args) {
      ref.watch(appDataRefreshProvider);
      return ref
          .watch(resultsRepositoryProvider)
          .watchStageResult(
            args.eventId,
            args.stageId,
            args.classId,
            args.resultId,
          );
    });

typedef AthleteStageResultsRequest = ({
  String eventId,
  String classId,
  String? athleteId,
  String athleteName,
});

final athleteStageResultsProvider = FutureProvider.autoDispose
    .family<List<AthleteStageResult>, AthleteStageResultsRequest>((
      ref,
      args,
    ) async {
      ref.watch(appDataRefreshProvider);
      final stages = await ref.watch(
        competitionStagesProvider(args.eventId).future,
      );
      final classStages = stages
          .where((stage) => stage.supportsClass(args.classId))
          .toList(growable: false);
      if (classStages.length < 2) return const <AthleteStageResult>[];

      final repository = ref.watch(resultsRepositoryProvider);
      final reads = await Future.wait(
        classStages.map((stage) async {
          final results = await repository.fetchStageResults(
            args.eventId,
            stage.id,
            args.classId,
          );
          return MapEntry(stage.id, results);
        }),
      );

      return buildAthleteStageResults(
        stages: classStages,
        resultsByStageId: Map.fromEntries(reads),
        athleteId: args.athleteId,
        athleteName: args.athleteName,
      );
    });

final splitDefsProvider =
    StreamProvider.family<List<SplitDef>, ({String eventId, String classId})>((
      ref,
      args,
    ) {
      ref.watch(appDataRefreshProvider);
      return ref
          .watch(resultsRepositoryProvider)
          .watchSplitDefs(args.eventId, args.classId);
    });

const raceResultsPageSize = resultsPageSize;

final raceResultsLimitProvider =
    StateProvider.family<int, ({String eventId, String classId})>((ref, args) {
      final athleteEvent = ref.watch(linkedAthleteEventProvider(args.eventId));
      if (athleteEvent?.classId != args.classId) return initialResultsLimit;

      final rank = athleteEvent!.rank;
      if (rank == null || rank <= initialResultsLimit) {
        return initialResultsLimit;
      }
      return rank;
    });

final raceResultsProvider =
    StreamProvider.family<List<RaceResult>, ({String eventId, String classId})>(
      (ref, args) {
        ref.watch(appDataRefreshProvider);
        final limit = ref.watch(raceResultsLimitProvider(args));
        return ref
            .watch(resultsRepositoryProvider)
            .watchResults(args.eventId, args.classId, limit: limit);
      },
    );

final raceResultProvider =
    StreamProvider.family<
      RaceResult?,
      ({String eventId, String classId, String resultId})
    >((ref, args) {
      ref.watch(appDataRefreshProvider);
      return ref
          .watch(resultsRepositoryProvider)
          .watchResult(args.eventId, args.classId, args.resultId);
    });

final resultSortModeProvider = StateProvider.family<ResultSortMode, String>((
  ref,
  eventId,
) {
  return ResultSortMode.cumulative;
});

enum ResultViewMode { table, graph }

final resultViewModeProvider = StateProvider<ResultViewMode>((ref) {
  return ResultViewMode.table;
});

final comparisonClassIdsProvider = StateProvider<List<String>>((ref) {
  return <String>[];
});

final relayComparisonLegNumbersProvider =
    StateProvider.family<
      List<int>,
      ({String eventId, String stageId, String classId})
    >((ref, args) => <int>[]);

final biathlonSortKeyProvider = StateProvider<String>((ref) {
  return 'ski';
});

final resultAffiliationViewProvider = StateProvider<ResultAffiliationView>((
  ref,
) {
  return ResultAffiliationView.club;
});

final resultSearchQueryProvider = StateProvider.autoDispose
    .family<String, ({String eventId, String stageId, String classId})>((
      ref,
      args,
    ) {
      return '';
    });

enum SettingsSyncStatus { loading, ready, saving, failed }

class SettingsController extends StateNotifier<UserSettings> {
  SettingsController(this._repository) : super(UserSettings.defaults()) {
    _loading = _load();
  }

  final SettingsRepository _repository;
  final syncStatus = ValueNotifier(SettingsSyncStatus.loading);
  late final Future<void> _loading;
  Future<void> _pending = Future.value();
  Future<void>? _retrying;
  final _pendingFields = <String, dynamic>{};
  bool _loaded = false;
  bool _failed = false;

  bool get _active =>
      mounted &&
      (_repository is! SessionSettingsRepository ||
          (_repository as SessionSettingsRepository).isCurrentSession);

  Future<void> setLocale(String localeCode) =>
      _change({'localeCode': localeCode});

  Future<void> setDefaultEvent(String? eventId) =>
      _change({'defaultEventId': eventId, 'defaultClassId': null});

  Future<void> setDefaultClass(String? classId) =>
      _change({'defaultClassId': classId});

  Future<void> setPreferredSplit(String? splitId) =>
      _change({'preferredSplitId': splitId});

  Future<void> setTableDensity(TableDensity density) =>
      _change({'tableDensity': density.name});

  Future<void> setThemeVariant(AppThemeVariant themeVariant) =>
      _change({'themeVariant': themeVariant.name});

  void _setStatus(SettingsSyncStatus status) {
    if (_active) syncStatus.value = status;
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.load();
      if (!_active) return;
      state = settings;
      _loaded = true;
      _setStatus(SettingsSyncStatus.ready);
    } catch (_) {
      if (!_active) return;
      if (_repository is SessionSettingsRepository) {
        try {
          state = (_repository as SessionSettingsRepository).loadLocal();
        } catch (_) {
          // Retain the current choice if device storage is also unavailable.
        }
      }
      _failed = true;
      _setStatus(SettingsSyncStatus.failed);
    }
  }

  /// Every edit and retry joins this queue. A rejected persistence operation
  /// cannot poison it or allow a later edit to overtake an earlier save.
  Future<void> _enqueue(Future<void> Function() operation) {
    _pending = _pending.then((_) async {
      try {
        await _loading;
        if (!_active) return;
        await operation();
      } catch (_) {
        if (!_active) return;
        _failed = true;
        _setStatus(SettingsSyncStatus.failed);
      }
    });
    return _pending;
  }

  Future<void> _change(Map<String, dynamic> patch) => _enqueue(() async {
    state = UserSettings.fromMap({...state.toMap(), ...patch});
    final normalized = state.toMap();
    _pendingFields.addAll({for (final key in patch.keys) key: normalized[key]});
    if (_failed || !_loaded) {
      // Keep the choice on this device without retrying cloud access or
      // assuming the values of fields we could not read from the server.
      if (_repository is SessionSettingsRepository) {
        await (_repository as SessionSettingsRepository).saveLocal(state);
      }
      _setStatus(SettingsSyncStatus.failed);
      return;
    }
    await _savePending();
  });

  Future<void> _savePending() async {
    _setStatus(SettingsSyncStatus.saving);
    final patch = Map<String, dynamic>.from(_pendingFields);
    if (_repository is SessionSettingsRepository) {
      await (_repository as SessionSettingsRepository).savePatch(state, patch);
    } else {
      await _repository.save(state);
    }
    if (!_active) return;
    _pendingFields.clear();
    _failed = false;
    _setStatus(SettingsSyncStatus.ready);
  }

  /// Explicit retries reread the account, then apply only this session's
  /// unsaved fields. Multiple taps share the same queued operation.
  Future<void> retry() {
    if (!_active) return Future.value();
    if (_retrying != null) return _retrying!;
    final operation = _enqueue(() async {
      if (!_failed) return;
      _setStatus(SettingsSyncStatus.saving);
      final settings = await _repository.load();
      if (!_active) return;
      _loaded = true;
      state = UserSettings.fromMap({...settings.toMap(), ..._pendingFields});
      if (_pendingFields.isEmpty) {
        _failed = false;
        _setStatus(SettingsSyncStatus.ready);
        return;
      }
      await _savePending();
    });
    _retrying = operation;
    operation.whenComplete(() => _retrying = null);
    return operation;
  }

  @override
  void dispose() {
    if (_repository is SessionSettingsRepository) {
      (_repository as SessionSettingsRepository).cancelPendingOperations();
    }
    syncStatus.dispose();
    super.dispose();
  }
}
