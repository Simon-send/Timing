import 'package:flutter_test/flutter_test.dart';
import 'package:results/features/profile/domain/athlete_link_state.dart';

void main() {
  test('unlinked legacy profile requires athlete-link onboarding', () {
    final state = AthleteLinkState.fromMap(null);

    expect(state.athleteId, isNull);
    expect(state.shouldShowOnboarding, isTrue);
  });

  test('linked legacy profile skips athlete-link onboarding', () {
    final state = AthleteLinkState.fromMap({'athleteId': 'athlete-1'});

    expect(state.athleteId, 'athlete-1');
    expect(state.onboardingCompleted, isTrue);
    expect(state.shouldShowOnboarding, isFalse);
  });

  test('saved not-now choice skips athlete-link onboarding', () {
    final state = AthleteLinkState.fromMap({
      'athleteLinkOnboardingCompleted': true,
    });

    expect(state.athleteId, isNull);
    expect(state.shouldShowOnboarding, isFalse);
  });
}
