import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/events/data/events_repository.dart';
import '../features/events/domain/result_event.dart';
import '../features/results/data/results_repository.dart';
import '../features/results/domain/race_result.dart';
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

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

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

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return AppSettingsRepository(
    preferences: ref.watch(sharedPreferencesProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, UserSettings>((ref) {
      return SettingsController(ref.watch(settingsRepositoryProvider));
    });

final eventsProvider = StreamProvider<List<ResultEvent>>((ref) {
  return ref.watch(eventsRepositoryProvider).watchEvents();
});

final classesProvider = StreamProvider.family<List<ResultClass>, String>((
  ref,
  eventId,
) {
  return ref.watch(resultsRepositoryProvider).watchClasses(eventId);
});

final splitDefsProvider =
    StreamProvider.family<List<SplitDef>, ({String eventId, String classId})>((
      ref,
      args,
    ) {
      return ref
          .watch(resultsRepositoryProvider)
          .watchSplitDefs(args.eventId, args.classId);
    });

const raceResultsPageSize = resultsPageSize;

final raceResultsLimitProvider =
    StateProvider.family<int, ({String eventId, String classId})>((ref, args) {
      return initialResultsLimit;
    });

final raceResultsProvider =
    StreamProvider.family<List<RaceResult>, ({String eventId, String classId})>(
      (ref, args) {
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
      return ref
          .watch(resultsRepositoryProvider)
          .watchResult(args.eventId, args.classId, args.resultId);
    });

final resultSortModeProvider = StateProvider<ResultSortMode>((ref) {
  return ResultSortMode.cumulative;
});

enum ResultViewMode { table, graph }

final resultViewModeProvider = StateProvider<ResultViewMode>((ref) {
  return ResultViewMode.table;
});

final comparisonClassIdsProvider = StateProvider<List<String>>((ref) {
  return <String>[];
});

final biathlonSortKeyProvider = StateProvider<String>((ref) {
  return 'ski';
});

final splitRangeSelectionProvider = StateProvider<SplitRangeSelection?>((ref) {
  return null;
});

class SettingsController extends StateNotifier<UserSettings> {
  SettingsController(this._repository) : super(UserSettings.defaults()) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> setLocale(String localeCode) async {
    await _save(state.copyWith(localeCode: localeCode));
  }

  Future<void> setDefaultEvent(String? eventId) async {
    await _save(
      state.copyWith(
        defaultEventId: eventId,
        clearDefaultEventId: eventId == null,
        clearDefaultClassId: true,
      ),
    );
  }

  Future<void> setDefaultClass(String? classId) async {
    await _save(
      state.copyWith(
        defaultClassId: classId,
        clearDefaultClassId: classId == null,
      ),
    );
  }

  Future<void> setPreferredSplit(String? splitId) async {
    await _save(
      state.copyWith(
        preferredSplitId: splitId,
        clearPreferredSplitId: splitId == null,
      ),
    );
  }

  Future<void> setTableDensity(TableDensity density) async {
    await _save(state.copyWith(tableDensity: density));
  }

  Future<void> setThemeVariant(AppThemeVariant themeVariant) async {
    await _save(state.copyWith(themeVariant: themeVariant));
  }

  Future<void> _load() async {
    state = await _repository.load();
  }

  Future<void> _save(UserSettings settings) async {
    state = settings;
    await _repository.save(settings);
  }
}
