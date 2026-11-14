import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_providers.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/auth/data/auth_repository.dart';
import 'package:results/features/auth/presentation/auth_pages.dart';
import 'package:results/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'registration requires acknowledgement, including keyboard submit',
    (tester) async {
      final repository = _Auth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: buildAppTheme(AppThemeVariant.nordicDark),
            locale: const Locale('nb'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RegisterPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
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
      expect(repository.creations, 0);
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Personvern for kontoen'),
      );
      await tester.tap(
        find.widgetWithText(TextButton, 'Personvern for kontoen'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('938426074'), findsOneWidget);
      expect(
        find.textContaining('Registrering gir ikke samtykke'),
        findsOneWidget,
      );
      await tester.tap(find.text('Lukk'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(repository.creations, 1);
      expect(find.text('Gå til innlogging'), findsOneWidget);
    },
  );
}

class _Auth extends AuthRepository {
  int creations = 0;
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authStateChanges() => Stream.value(null);
  @override
  Future<void> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    creations++;
  }

  @override
  Future<User?> completeGoogleRedirect() async => null;
  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async =>
      GoogleSignInOutcome.signedIn;
  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
  @override
  Future<void> signOut() async {}
}
