import 'package:flutter/material.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/nav.dart';
import 'package:morro_do_peo/services/submission_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
