import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/screens/home_page.dart';
import 'package:morro_do_peo/screens/operator_selection_page.dart';
import 'package:morro_do_peo/screens/api/api_checklists_page.dart';
import 'package:morro_do_peo/screens/api/api_home_page.dart';
import 'package:morro_do_peo/screens/api/api_execution_detail_page.dart';
import 'package:morro_do_peo/screens/api/api_occurrence_detail_page.dart';
import 'package:morro_do_peo/screens/api/api_create_occurrence_page.dart';
import 'package:morro_do_peo/state/app_session.dart';

class AppRouter {
  static GoRouter create(AppSession session) => GoRouter(
        initialLocation: AppRoutes.home,
        refreshListenable: session,
        redirect: (context, state) {
          final loc = state.matchedLocation;

          if (loc.startsWith('/api') && session.selectedOperator == null) {
            return AppRoutes.collaborators;
          }
          return null;
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: AppRoutes.collaborators,
            name: 'collaborators',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const OperatorSelectionPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),

          // --- API v1 flow (backend-driven) --------------------------------
          GoRoute(
            path: AppRoutes.apiHome,
            name: 'apiHome',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ApiHomePage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.apiAssignmentDetail,
            name: 'apiAssignmentDetail',
            pageBuilder: (context, state) {
              final id = state.pathParameters['assignmentId'] ?? '';
              return CustomTransitionPage(child: ApiAssignmentDetailPage(assignmentId: id), transitionsBuilder: _slideTransition);
            },
          ),
          GoRoute(
            path: AppRoutes.apiExecutionDetail,
            name: 'apiExecutionDetail',
            pageBuilder: (context, state) {
              final id = state.pathParameters['executionId'] ?? '';
              return CustomTransitionPage(child: ApiExecutionDetailPage(executionId: id), transitionsBuilder: _slideTransition);
            },
          ),
          GoRoute(
            path: AppRoutes.apiOccurrenceDetail,
            name: 'apiOccurrenceDetail',
            pageBuilder: (context, state) {
              final id = state.pathParameters['occurrenceId'] ?? '';
              return CustomTransitionPage(child: ApiOccurrenceDetailPage(occurrenceId: id), transitionsBuilder: _slideTransition);
            },
          ),
          GoRoute(
            path: AppRoutes.apiOccurrenceNew,
            name: 'apiOccurrenceNew',
            pageBuilder: (context, state) => CustomTransitionPage(child: const ApiCreateOccurrencePage(), transitionsBuilder: _slideTransition),
          ),
        ],
      );

  static Widget _slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    );
  }
}

class AppRoutes {
  static const String home = '/';
  static const String collaborators = '/collaborators';

  // API v1 flow (backend-driven).
  static const String apiHome = '/api';
  static const String apiAssignmentDetail = '/api/checklists/:assignmentId';
  static const String apiExecutionDetail = '/api/executions/:executionId';
  static const String apiOccurrenceDetail = '/api/occurrences/:occurrenceId';
  static const String apiOccurrenceNew = '/api/occurrences/new';
}
