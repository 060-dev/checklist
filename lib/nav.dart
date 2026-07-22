import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/screens/home_page.dart';
import 'package:morro_do_peo/screens/operator_selection_page.dart';
import 'package:morro_do_peo/screens/operational_area_selection_page.dart';
import 'package:morro_do_peo/screens/checklist_selection_page.dart';
import 'package:morro_do_peo/screens/pecuaria_checklist_type_page.dart';
import 'package:morro_do_peo/screens/pen_selection_page.dart';
import 'package:morro_do_peo/screens/pen_checklist_selection_page.dart';
import 'package:morro_do_peo/screens/pecuaria_general_checklist_selection_page.dart';
import 'package:morro_do_peo/screens/checklist_question_page.dart';
import 'package:morro_do_peo/screens/observation_prompt_page.dart';
import 'package:morro_do_peo/screens/observation_record_page.dart';
import 'package:morro_do_peo/screens/review_submit_page.dart';
import 'package:morro_do_peo/screens/success_page.dart';
import 'package:morro_do_peo/screens/api/api_home_page.dart';
import 'package:morro_do_peo/screens/api/api_checklists_page.dart';
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

          final isOfflineFlow = loc.startsWith('/areas') ||
              loc.startsWith('/checklists') ||
              loc.startsWith('/pecuaria') ||
              loc.startsWith('/observation') ||
              loc.startsWith('/review') ||
              loc.startsWith('/success');
          final isApiFlow = loc.startsWith('/api');

          if ((isOfflineFlow || isApiFlow) && session.selectedOperator == null) {
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

          // --- Offline checklist flow --------------------------------------
          GoRoute(
            path: AppRoutes.areas,
            name: 'areas',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const OperationalAreaSelectionPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.checklists,
            name: 'checklists',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ChecklistSelectionPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.pecuaria,
            name: 'pecuaria',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const PecuariaChecklistTypePage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.pecuariaGeneral,
            name: 'pecuariaGeneral',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const PecuariaGeneralChecklistSelectionPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.pens,
            name: 'pens',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const PenSelectionPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.penChecklists,
            name: 'penChecklists',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const PenChecklistSelectionPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.questions,
            name: 'questions',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return CustomTransitionPage(
                child: ChecklistQuestionPage(checklistId: id),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.observation,
            name: 'observation',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ObservationPromptPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.observationRecord,
            name: 'observationRecord',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ObservationRecordPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.review,
            name: 'review',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ReviewSubmitPage(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: AppRoutes.success,
            name: 'success',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const SuccessPage(),
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

  // Offline checklist flow.
  static const String areas = '/areas';
  static const String checklists = '/checklists';
  static const String pecuaria = '/pecuaria';
  static const String pecuariaGeneral = '/pecuaria/gerais';
  static const String pens = '/pecuaria/currais';
  static const String penChecklists = '/pecuaria/currais/checklists';
  static const String questions = '/checklists/:id/questions';
  static const String observation = '/observation';
  static const String observationRecord = '/observation/record';
  static const String review = '/review';
  static const String success = '/success';

  // API v1 flow (backend-driven).
  static const String apiHome = '/api';
  static const String apiAssignmentDetail = '/api/checklists/:assignmentId';
  static const String apiExecutionDetail = '/api/executions/:executionId';
  static const String apiOccurrenceDetail = '/api/occurrences/:occurrenceId';
  static const String apiOccurrenceNew = '/api/occurrences/new';
}
