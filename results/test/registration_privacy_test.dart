import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:results/app/app_providers.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/auth/data/auth_repository.dart';
import 'package:results/features/auth/presentation/auth_pages.dart';
import 'package:results/features/consents/data/account_consent_repository.dart';
import 'package:results/features/consents/data/signup_pending.dart';
import 'package:results/features/consents/domain/account_consents.dart';
import 'package:results/features/consents/presentation/consent_settings_dialog.dart';
import 'package:results/features/consents/presentation/signup_consent_dialog.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:results/features/profile/presentation/me_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => clearSignupPending('signup-user'));

  Future<void> open(
    WidgetTester tester,
    Widget home,
    _Auth auth,
    _Consent consents,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(path: '/test', builder: (_, _) => home),
        GoRoute(
          path: '/events',
          builder: (_, _) => const Scaffold(body: Text('Events')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          accountConsentRepositoryProvider.overrideWithValue(consents),
          googleRedirectProvider.overrideWith((ref) async => null),
          sharedPreferencesProvider.overrideWithValue(preferences),
          linkedAthleteIdProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildAppTheme(AppThemeVariant.nordicDark),
          locale: const Locale('nb'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('privacy choices are available under My page on a narrow phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    final auth = _Auth()..signedIn = true;
    final consents = _Consent();
    await open(tester, const MePage(), auth, consents);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Personvern og e-post'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'registration requires privacy but cloud and advertising remain optional',
    (tester) async {
      final auth = _Auth();
      final consents = _Consent();
      await open(tester, const RegisterPage(), auth, consents);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'runner@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      final create = find.widgetWithText(FilledButton, 'Opprett konto');
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(auth.creations, 0);
      final boxes = find.byType(CheckboxListTile);
      expect(boxes, findsNWidgets(3));
      for (final box in tester.widgetList<CheckboxListTile>(boxes)) {
        expect(box.value, isFalse);
      }
      await tester.ensureVisible(boxes.first);
      await tester.tap(boxes.first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(auth.creations, 1);
      expect(consents.registers, 1);
      expect(consents.choice!.privacy, isTrue);
      expect(consents.choice!.cloudActivity, isFalse);
      expect(consents.choice!.marketingEmail, isFalse);
      expect(consents.lastUid, 'signup-user');
      expect(find.text('Gå til innlogging'), findsOneWidget);
    },
  );

  testWidgets('existing Google login has no boxes and does not subscribe', (
    tester,
  ) async {
    final auth = _Auth();
    final consents = _Consent();
    await open(tester, const LoginPage(), auth, consents);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.ensureVisible(find.text('Fortsett med Google'));
    await tester.tap(find.text('Fortsett med Google'));
    await tester.pumpAndSettle();
    expect(find.text('Events'), findsOneWidget);
    expect(consents.registers, 0);
  });

  testWidgets(
    'new Google signup gets separate unchecked choices after authentication',
    (tester) async {
      final auth = _Auth()..newGoogle = true;
      final consents = _Consent();
      await open(tester, const LoginPage(), auth, consents);
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.ensureVisible(find.text('Fortsett med Google'));
      await tester.tap(find.text('Fortsett med Google'));
      for (
        var i = 0;
        i < 20 && find.byType(CheckboxListTile).evaluate().length != 3;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Fullfør registrering'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      for (final box in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      )) {
        expect(box.value, isFalse);
      }
      await tester.ensureVisible(find.byType(CheckboxListTile).first);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      await tester.tap(find.text('Lagre valg'));
      await tester.pumpAndSettle();
      expect(consents.registers, 1);
      expect(consents.choice!.marketingEmail, isFalse);
      expect(pendingSignupSource('signup-user'), isNull);
      expect(find.text('Events'), findsOneWidget);
    },
  );

  testWidgets(
    'completed signup clears stale marker without showing blank choices',
    (tester) async {
      final auth = _Auth();
      final consents = _Consent()
        ..state = const AccountConsents(
          registrationComplete: true,
          privacyAcknowledged: true,
          marketingEmail: true,
        );
      markSignupPending('signup-user', 'results-google');
      await open(tester, const LoginPage(), auth, consents);
      await tester.ensureVisible(find.text('Fortsett med Google'));
      await tester.tap(find.text('Fortsett med Google'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(consents.registers, 0);
      expect(consents.state.marketingEmail, isTrue);
      expect(pendingSignupSource('signup-user'), isNull);
    },
  );

  testWidgets('lost signup response requires reload before editable choices', (
    tester,
  ) async {
    final auth = _Auth()..signedIn = true;
    final consents = _Consent()..loseResponse = true;
    markSignupPending('signup-user', 'results-google');
    await open(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SignupConsentDialog(
                uid: 'signup-user',
                source: 'results-google',
              ),
            ),
            child: const Text('Open choices'),
          ),
        ),
      ),
      auth,
      consents,
    );
    await tester.tap(find.text('Open choices'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lagre valg'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(consents.state.registrationComplete, isTrue);
    await tester.tap(find.text('Oppdater valg'));
    await tester.pumpAndSettle();
    expect(find.text('Fullfør registrering'), findsNothing);
    expect(consents.registers, 1);
    expect(consents.state.marketingEmail, isFalse);
    expect(pendingSignupSource('signup-user'), isNull);
  });

  testWidgets('stale signup choices cannot overwrite a later withdrawal', (
    tester,
  ) async {
    final auth = _Auth()..signedIn = true;
    final consents = _Consent()
      ..state = const AccountConsents(registrationPending: true, revision: 3);
    await open(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SignupConsentDialog(
                uid: 'signup-user',
                source: 'results-google',
              ),
            ),
            child: const Text('Open choices'),
          ),
        ),
      ),
      auth,
      consents,
    );
    await tester.tap(find.text('Open choices'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    consents.state = const AccountConsents(
      registrationPending: true,
      revision: 4,
    );
    await tester.tap(find.text('Lagre valg'));
    await tester.pumpAndSettle();
    expect(consents.registers, 0);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(find.text('Oppdater valg'));
    await tester.pumpAndSettle();
    for (final box in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(box.value, isFalse);
    }
  });

  testWidgets(
    'email withdrawal changes only marketing and cloud withdrawal can be cancelled',
    (tester) async {
      final auth = _Auth()..signedIn = true;
      final consents = _Consent()
        ..state = const AccountConsents(
          cloudActivity: true,
          marketingEmail: true,
          revision: 3,
        );
      await open(
        tester,
        const ConsentSettingsDialog(uid: 'signup-user'),
        auth,
        consents,
      );
      final boxes = find.byType(CheckboxListTile);
      expect(boxes, findsNWidgets(2));
      await tester.ensureVisible(boxes.last);
      await tester.tap(boxes.last);
      await tester.pumpAndSettle();
      expect(consents.lastCloud, isNull);
      expect(consents.lastMarketing, isFalse);
      expect(consents.lastRevision, 3);
      expect(consents.state.cloudActivity, isTrue);
      await tester.ensureVisible(boxes.first);
      await tester.tap(boxes.first);
      await tester.pumpAndSettle();
      expect(find.text('Trekke tilbake skylagring?'), findsOneWidget);
      await tester.tap(find.text('Lukk').last);
      await tester.pumpAndSettle();
      expect(consents.updates, 1);
    },
  );

  testWidgets('pending cloud cleanup is visible and retry keeps account', (
    tester,
  ) async {
    final auth = _Auth()..signedIn = true;
    final consents = _Consent()
      ..state = const AccountConsents(activityCleanupPending: true);
    await open(
      tester,
      const ConsentSettingsDialog(uid: 'signup-user'),
      auth,
      consents,
    );
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
          .onChanged,
      isNull,
    );
    await tester.ensureVisible(find.text('Fortsett sletting'));
    await tester.tap(find.text('Fortsett sletting'));
    await tester.pumpAndSettle();
    expect(consents.resumes, 1);
    expect(auth.currentUser, isNotNull);
  });
}

class _User implements User {
  @override
  String get uid => 'signup-user';
  @override
  String? get email => 'runner@example.test';
  @override
  String? get displayName => 'Runner';
  @override
  bool get emailVerified => true;
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthRepository {
  int creations = 0;
  bool newGoogle = false;
  bool signedIn = false;
  @override
  User? get currentUser => signedIn ? _User() : null;
  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
  @override
  Future<void> createUserWithEmail({
    required String email,
    required String password,
    Future<void> Function(String uid)? onCreated,
  }) async {
    creations++;
    await onCreated?.call('signup-user');
  }

  @override
  Future<User?> completeGoogleRedirect() async => null;
  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    signedIn = true;
    if (newGoogle) markSignupPending('signup-user', 'results-google');
    return GoogleSignInOutcome.signedIn;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signedIn = true;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
  @override
  Future<void> signOut() async {
    signedIn = false;
  }
}

class _Consent extends AccountConsentRepository {
  AccountConsents state = const AccountConsents();
  bool loseResponse = false;
  RegistrationChoices? choice;
  String? lastUid;
  int registers = 0;
  int updates = 0;
  int resumes = 0;
  bool? lastCloud;
  bool? lastMarketing;
  int? lastRevision;
  @override
  Future<AccountConsents> status(String uid) async => state;
  @override
  Future<void> begin(String uid, String source) async {}
  @override
  Future<AccountConsents> register(
    String uid,
    RegistrationChoices choices,
    String locale,
    String source, {
    int expectedRevision = 0,
  }) async {
    lastUid = uid;
    choice = choices;
    registers++;
    state = AccountConsents(
      registrationComplete: true,
      privacyAcknowledged: choices.privacy,
      cloudActivity: choices.cloudActivity,
      marketingEmail: choices.marketingEmail,
    );
    if (loseResponse) throw Exception("Response lost after commit");
    return state;
  }

  @override
  Future<AccountConsents> update(
    String uid, {
    required int expectedRevision,
    required String locale,
    bool? cloudActivity,
    bool? marketingEmail,
  }) async {
    updates++;
    lastUid = uid;
    lastCloud = cloudActivity;
    lastMarketing = marketingEmail;
    lastRevision = expectedRevision;
    return state = AccountConsents(
      cloudActivity: cloudActivity ?? state.cloudActivity,
      marketingEmail: marketingEmail ?? state.marketingEmail,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<void> resumeWithdrawal(String uid) async {
    resumes++;
    state = AccountConsents(marketingEmail: state.marketingEmail);
  }
}
