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
  // Note: `sendApiMutation` isn't wired yet — Mobile API v1 mutation sending
  // is a follow-up step (see OfflineQueueService.enqueueApiMutation).
  runApp(const MorroDoPeaoApp());
}

class MorroDoPeaoApp extends StatefulWidget {
  const MorroDoPeaoApp({super.key});

  @override
  State<MorroDoPeaoApp> createState() => _MorroDoPeaoAppState();
}

class _MorroDoPeaoAppState extends State<MorroDoPeaoApp> {
  late final AppSession _session = AppSession();
  late final RouterConfig<Object> _router = AppRouter.create(_session);

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: restores API config + last selected employee. UI can
    // react to `session.isLoaded` if it needs to gate on this.
    _session.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _session,
      child: MaterialApp.router(
        title: 'Morro do Peão - Checklists',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: _router,
      ),
    );
  }
}
