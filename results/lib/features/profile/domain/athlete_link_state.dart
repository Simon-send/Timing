import '../../../core/firebase/firestore_mappers.dart';

class AthleteLinkState {
  const AthleteLinkState({
    required this.athleteId,
    required this.onboardingCompleted,
  });

  factory AthleteLinkState.fromMap(Map<String, dynamic>? data) {
    final athleteId = asNonEmptyString(data?['athleteId']);
    return AthleteLinkState(
      athleteId: athleteId,
      onboardingCompleted:
          athleteId != null || data?['athleteLinkOnboardingCompleted'] == true,
    );
  }

  final String? athleteId;
  final bool onboardingCompleted;

  bool get shouldShowOnboarding => athleteId == null && !onboardingCompleted;
}
