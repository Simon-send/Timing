import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/athlete/presentation/athlete_detail_page.dart';
import '../features/auth/presentation/auth_pages.dart';
import '../features/events/presentation/events_page.dart';
import '../features/profile/presentation/athlete_link_onboarding_page.dart';
import '../features/profile/presentation/me_page.dart';
import '../features/results/presentation/result_locations.dart';
import '../features/results/presentation/results_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/events',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/events'),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordPage(
          initialEmail: state.extra is String ? state.extra! as String : '',
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/connect-athlete',
        builder: (context, state) => const AthleteLinkOnboardingPage(),
      ),
      GoRoute(path: '/me', builder: (context, state) => const MePage()),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsPage(),
        routes: [
          GoRoute(
            path: ':eventId/results',
            builder: (context, state) {
              return ResultsPage(
                eventId: state.pathParameters['eventId']!,
                selectedStageId:
                    state.uri.queryParameters[resultStageQueryParameter],
                selectedClassId:
                    state.uri.queryParameters[resultClassQueryParameter],
                selectedSplitId: resultSplitQueryValue(
                  state.uri.queryParameters,
                ),
                selectedSplitRange: resultSplitRangeQueryValue(
                  state.uri.queryParameters,
                ),
                selectedRelayLegNumber: int.tryParse(
                  state.uri.queryParameters[relayLegQueryParameter] ?? '',
                ),
                compareBaseClassId:
                    state.uri.queryParameters[compareBaseClassQueryParameter],
                compareBaseResultId:
                    state.uri.queryParameters[compareBaseResultQueryParameter],
                compareBaseRelayLegNumber: int.tryParse(
                  state
                          .uri
                          .queryParameters[compareBaseRelayLegQueryParameter] ??
                      '',
                ),
              );
            },
            routes: [
              GoRoute(
                path: ':classId/athletes/:resultId',
                builder: (context, state) {
                  return AthleteDetailPage(
                    eventId: state.pathParameters['eventId']!,
                    classId: state.pathParameters['classId']!,
                    resultId: state.pathParameters['resultId']!,
                    stageId:
                        state.uri.queryParameters[resultStageQueryParameter],
                    selectedSplitId: resultSplitQueryValue(
                      state.uri.queryParameters,
                    ),
                    selectedSplitRange: resultSplitRangeQueryValue(
                      state.uri.queryParameters,
                    ),
                    relayLegNumber: int.tryParse(
                      state.uri.queryParameters[relayLegQueryParameter] ?? '',
                    ),
                    compareWithResultId: state
                        .uri
                        .queryParameters[compareWithResultQueryParameter],
                    compareWithRelayLegNumber: int.tryParse(
                      state
                              .uri
                              .queryParameters[compareWithRelayLegQueryParameter] ??
                          '',
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
