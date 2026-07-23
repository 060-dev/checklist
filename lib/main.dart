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
    // The sender needs real credentials, so it's wired here (after `_session`
    // exists) rather than in `main()`.
    OfflineQueueService.instance.init(
      sendApiMutation: (item) => sendQueuedMutation(item, _session),
    );
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
        builder: (context, child) => Column(
          children: [
            ValueListenableBuilder<int>(
              valueListenable:
                  OfflineQueueService.instance.pendingCountNotifier,
              builder: (context, count, _) => count <= 0
                  ? const SizedBox.shrink()
                  : SafeArea(
                      bottom: false,
                      child: Container(
                        width: double.infinity,
                        color: AppColors.warningLight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_upload_outlined,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              count == 1
                                  ? '1 ação pendente — será enviada quando houver conexão.'
                                  : '$count ações pendentes — serão enviadas quando houver conexão.',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (child != null) Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
