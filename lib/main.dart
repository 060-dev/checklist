import 'dart:async';
import 'package:flutter/material.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/nav.dart';
import 'package:morro_do_peo/services/submission_service.dart';
import 'package:morro_do_peo/services/checklist_service.dart';
import 'package:morro_do_peo/services/operator_service.dart';
import 'package:morro_do_peo/utils/connectivity.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Connectivity().init();
  
  // Inicializa serviços e carrega cache local.
  await ChecklistService().init();
  await OperatorService().init();
  await SubmissionService().init();

  // Tenta sincronizar catálogo e operadores em background se houver internet.
  if (Connectivity.instance.isOnline) {
    unawaited(ChecklistService().syncCatalog());
    unawaited(OperatorService().syncOperators());
  }

  runApp(const MorroDoPeaoApp());
}

class MorroDoPeaoApp extends StatelessWidget {
  const MorroDoPeaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inicializa histórico local + fila offline de envios.
    // Não depende de backend estar conectado.
    SubmissionService().init();
    return MaterialApp.router(
      title: 'Morro do Peão - Checklists',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light, // Force light theme for better visibility in field
      routerConfig: AppRouter.router,
    );
  }
}
