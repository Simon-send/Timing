import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/athlete/presentation/athlete_detail_page.dart';
import '../features/auth/presentation/auth_pages.dart';
import '../features/events/presentation/events_page.dart';
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
          initialEmail: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
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
                selectedClassId:
                    state.uri.queryParameters[resultClassQueryParameter],
                selectedSplitId: resultSplitQueryValue(
                  state.uri.queryParameters,
                ),
                compareBaseClassId:
                    state.uri.queryParameters[compareBaseClassQueryParameter],
                compareBaseResultId:
                    state.uri.queryParameters[compareBaseResultQueryParameter],
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
                    selectedSplitId: resultSplitQueryValue(
                      state.uri.queryParameters,
                    ),
                    compareWithResultId: state
                        .uri
                        .queryParameters[compareWithResultQueryParameter],
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
