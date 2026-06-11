import 'package:flutter/material.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/nav.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/utils/connectivity.dart';
import 'package:morro_do_peo/services/offline_queue_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Connectivity.instance.init();
  await OfflineQueueService.instance.init(sendAttempt: (_, __) async {});
  runApp(const MorroDoPeaoApp());
}

class MorroDoPeaoApp extends StatelessWidget {
  const MorroDoPeaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppSession(),
      child: Builder(
        builder: (context) => MaterialApp.router(
          title: 'Morro do Peão - Checklists',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.light, // Force light theme for better visibility in field
          routerConfig: AppRouter.create(context.read<AppSession>()),
        ),
      ),
    );
  }
}
