import 'package:flutter/material.dart';
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
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>? ?? {};

    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RoleSelectionPage(),
        );

      case AppRoutes.operator:
        return _slideRoute(settings, const OperatorSelectionPage());

      case AppRoutes.areas:
        return _slideRoute(
          settings,
          AreaSelectionPage(
            operatorName: args['op'],
            operatorId: args['opId'],
          ),
        );

      case AppRoutes.checklists:
        return _slideRoute(
          settings,
          ChecklistSelectionPage(
            areaId: args['areaId'] ?? '',
            operatorName: args['op'],
            operatorId: args['opId'],
          ),
        );

      case AppRoutes.checklistIntro:
        return _slideRoute(
          settings,
          ChecklistIntroPage(
            checklistId: args['checklistId'] ?? '',
            operatorName: args['op'],
            operatorId: args['opId'],
          ),
        );

      case AppRoutes.question:
        return _slideRoute(
          settings,
          QuestionPage(
            checklistId: args['checklistId'] ?? '',
            questionIndex: args['questionIndex'] ?? 0,
            operatorName: args['op'],
            operatorId: args['opId'],
          ),
        );

      case AppRoutes.review:
        return _slideRoute(
          settings,
          ReviewPage(
            checklistId: args['checklistId'] ?? '',
            operatorName: args['op'],
            operatorId: args['opId'],
          ),
        );

      case AppRoutes.success:
        return _fadeRoute(
          settings,
          SuccessPage(
            checklistId: args['checklistId'] ?? '',
            operatorName: args['op'],
            operatorId: args['opId'],
            result: args['result'],
          ),
        );

      case AppRoutes.manager:
        return _slideRoute(settings, const ManagerDashboardPage());

      case AppRoutes.submission:
        return _slideRoute(
          settings,
          SubmissionDetailPage(
            submissionId: args['submissionId'] ?? '',
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Rota não encontrada: ${settings.name}')),
          ),
        );
    }
  }

  static Route<dynamic> _slideRoute(RouteSettings settings, Widget child) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
      },
    );
  }

  static Route<dynamic> _fadeRoute(RouteSettings settings, Widget child) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
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
