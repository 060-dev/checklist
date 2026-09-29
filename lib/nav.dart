import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/models/purchase_models.dart';
import 'package:morro_do_peo/screens/welcome_page.dart';
import 'package:morro_do_peo/screens/activation_page.dart';
import 'package:morro_do_peo/screens/checklists_page.dart';
import 'package:morro_do_peo/screens/home_page.dart';
import 'package:morro_do_peo/screens/execution_detail_page.dart';
import 'package:morro_do_peo/screens/occurrence_detail_page.dart';
import 'package:morro_do_peo/screens/create_occurrence_page.dart';
import 'package:morro_do_peo/screens/create_purchase_page.dart';
import 'package:morro_do_peo/screens/purchase_detail_page.dart';
import 'package:morro_do_peo/screens/purchase_dashboard_page.dart';
import 'package:morro_do_peo/state/app_session.dart';

class AppRouter {
  static GoRouter create(AppSession session) => GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (loc.startsWith('/api') && session.selectedOperator == null) {
        return AppRoutes.activate;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: WelcomePage()),
      ),
      GoRoute(
        path: AppRoutes.activate,
        name: 'activate',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ActivationPage(),
          transitionsBuilder: _slideTransition,
        ),
      ),

      // --- API v1 flow (backend-driven) --------------------------------
      GoRoute(
        path: AppRoutes.apiHome,
        name: 'apiHome',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const HomePage(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.apiAssignmentDetail,
        name: 'apiAssignmentDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['assignmentId'] ?? '';
          return CustomTransitionPage(
            child: AssignmentDetailPage(assignmentId: id),
            transitionsBuilder: _slideTransition,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.apiExecutionDetail,
        name: 'apiExecutionDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['executionId'] ?? '';
          return CustomTransitionPage(
            child: ExecutionDetailPage(executionId: id),
            transitionsBuilder: _slideTransition,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.apiOccurrenceNew,
        name: 'apiOccurrenceNew',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const CreateOccurrencePage(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.apiOccurrenceDetail,
        name: 'apiOccurrenceDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['occurrenceId'] ?? '';
          return CustomTransitionPage(
            child: OccurrenceDetailPage(occurrenceId: id),
            transitionsBuilder: _slideTransition,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.apiPurchaseNew,
        name: 'apiPurchaseNew',
        pageBuilder: (context, state) {
          final detail = state.extra as PurchaseRequestDetail?;
          return CustomTransitionPage(
            child: CreatePurchasePage(initialDetail: detail),
            transitionsBuilder: _slideTransition,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.apiPurchaseDashboard,
        name: 'apiPurchaseDashboard',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const PurchaseDashboardPage(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: AppRoutes.apiPurchaseDetail,
        name: 'apiPurchaseDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['purchaseId'] ?? '';
          return CustomTransitionPage(
            child: PurchaseDetailPage(requestId: id),
            transitionsBuilder: _slideTransition,
          );
        },
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
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }
}

class AppRoutes {
  static const String home = '/';
  static const String activate = '/activate';

  // API v1 flow (backend-driven).
  static const String apiHome = '/api';
  static const String apiAssignmentDetail = '/api/checklists/:assignmentId';
  static const String apiExecutionDetail = '/api/executions/:executionId';
  static const String apiOccurrenceDetail = '/api/occurrences/:occurrenceId';
  static const String apiOccurrenceNew = '/api/occurrences/new';

  static const String apiPurchaseDashboard = '/compras/dashboard';
  static const String apiPurchaseNew = '/compras/nova';
  static const String apiPurchaseDetail = '/compras/:purchaseId';
}
