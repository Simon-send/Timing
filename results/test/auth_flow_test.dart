import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/app/app_providers.dart';
import 'package:results/app/app_theme.dart';
import 'package:results/features/auth/data/auth_repository.dart';
import 'package:results/features/auth/presentation/auth_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuth implements AuthRepository {
  int redirects = 0;
  int logins = 0;
  User? redirectUser;
  final login = Completer<void>();
  @override
  User? get currentUser => null;
  @override
  Future<User?> completeGoogleRedirect() async {
    redirects++;
    return redirectUser;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    logins++;
    return login.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('login fits $width px with keyboard', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuth()),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(
            theme: buildAppTheme(AppThemeVariant.nordicDark),
            home: const LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  }
  test(
    'redirect is consumed once per scope and pending flag is cleared',
    () async {
      SharedPreferences.setMockInitialValues({
        'google_sign_in_redirect_pending': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final auth = FakeAuth()..redirectUser = FakeUser();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(googleRedirectProvider.future),
        same(auth.redirectUser),
      );
      await container.read(googleRedirectProvider.future);
      expect(auth.redirects, 1);
      expect(preferences.containsKey('google_sign_in_redirect_pending'), false);
    },
  );
  test(
    'cancelled redirect reports cancellation and removes pending flag',
    () async {
      SharedPreferences.setMockInitialValues({
        'google_sign_in_redirect_pending': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuth()),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(googleRedirectProvider.future),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(preferences.containsKey('google_sign_in_redirect_pending'), false);
    },
  );
  testWidgets('Enter cannot submit a second login while the first is pending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final auth = FakeAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeVariant.nordicDark),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'test@example.test');
    await tester.enterText(fields.last, 'test-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(auth.logins, 1);
    await tester.pumpWidget(const SizedBox());
    auth.login.complete();
    await tester.pump();
  });
}
