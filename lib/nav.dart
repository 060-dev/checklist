import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/screens/role_selection_page.dart';
import 'package:morro_do_peo/screens/operator_selection_page.dart';
import 'package:morro_do_peo/screens/area_selection_page.dart';
import 'package:morro_do_peo/screens/checklist_selection_page.dart';
import 'package:morro_do_peo/screens/checklist_intro_page.dart';
import 'package:morro_do_peo/screens/question_page.dart';
import 'package:morro_do_peo/screens/review_page.dart';
import 'package:morro_do_peo/screens/success_page.dart';
import 'package:morro_do_peo/screens/manager_dashboard_page.dart';
import 'package:morro_do_peo/screens/submission_detail_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      // Role Selection (Home)
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RoleSelectionPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.operator,
        name: 'operator',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const OperatorSelectionPage(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      // Operator Flow
      GoRoute(
        path: AppRoutes.areas,
        name: 'areas',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: AreaSelectionPage(operatorName: state.uri.queryParameters['op'], operatorId: state.uri.queryParameters['opId']),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.checklists}/:areaId',
        name: 'checklists',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: ChecklistSelectionPage(
            areaId: state.pathParameters['areaId'] ?? '',
            operatorName: state.uri.queryParameters['op'],
            operatorId: state.uri.queryParameters['opId'],
          ),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.checklistIntro}/:checklistId',
        name: 'checklist-intro',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: ChecklistIntroPage(
            checklistId: state.pathParameters['checklistId'] ?? '',
            operatorName: state.uri.queryParameters['op'],
            operatorId: state.uri.queryParameters['opId'],
          ),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.question}/:checklistId/:questionIndex',
        name: 'question',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: QuestionPage(
            checklistId: state.pathParameters['checklistId'] ?? '',
            questionIndex: int.tryParse(state.pathParameters['questionIndex'] ?? '0') ?? 0,
            operatorName: state.uri.queryParameters['op'],
            operatorId: state.uri.queryParameters['opId'],
          ),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.review}/:checklistId',
        name: 'review',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: ReviewPage(
            checklistId: state.pathParameters['checklistId'] ?? '',
            operatorName: state.uri.queryParameters['op'],
            operatorId: state.uri.queryParameters['opId'],
          ),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.success}/:checklistId',
        name: 'success',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: SuccessPage(
            checklistId: state.pathParameters['checklistId'] ?? '',
            operatorName: state.uri.queryParameters['op'],
            operatorId: state.uri.queryParameters['opId'],
            result: state.uri.queryParameters['result'],
          ),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      // Manager Flow
      GoRoute(
        path: AppRoutes.manager,
        name: 'manager',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ManagerDashboardPage(),
          transitionsBuilder: _slideTransition,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.submission}/:submissionId',
        name: 'submission-detail',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: SubmissionDetailPage(
            submissionId: state.pathParameters['submissionId'] ?? '',
          ),
          transitionsBuilder: _slideTransition,
        ),
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

  static Widget _fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

class AppRoutes {
  static const String home = '/';
  static const String operator = '/operator';
  static const String areas = '/areas';
  static const String checklists = '/checklists';
  static const String checklistIntro = '/checklist-intro';
  static const String question = '/question';
  static const String review = '/review';
  static const String success = '/success';
  static const String manager = '/manager';
  static const String submission = '/submission';
}
