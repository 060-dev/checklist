import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/screens/alerts_page.dart';
import 'package:morro_do_peo/screens/history_page.dart';
import 'package:morro_do_peo/screens/occurrences_page.dart';
import 'package:morro_do_peo/screens/purchases_page.dart';
import 'package:morro_do_peo/screens/today_page.dart';
import 'package:morro_do_peo/state/app_session.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  int _unhandledAlertCount = 0;

  void _onAlertCountChanged(int count) {
    if (mounted && count != _unhandledAlertCount) {
      setState(() => _unhandledAlertCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;

    final pages = [
      const TodayPage(),
      const HistoryPage(),
      const OccurrencesPage(),
      const PurchasesPage(),
      AlertsPage(onCountChanged: _onAlertCountChanged),
    ];
    final titles = const [
      'Checklists',
      'Histórico',
      'Ocorrências',
      'Compras',
      'Avisos',
    ];

    Future<void> confirmLogout() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair do aplicativo?'),
          content: const Text(
            'As respostas não enviadas continuarão salvas neste aparelho.',
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => context.pop(true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        session.resetAll();
        context.go('/');
      }
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 26),
            onPressed: confirmLogout,
          ),
        ],
        title: Text(
          op == null ? titles[_index] : '${titles[_index]} · ${op.name}',
        ),
      ),
      body: pages[_index],
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              return const TextStyle(
                fontSize: 12,
                overflow: TextOverflow.ellipsis,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.14),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.today_rounded),
                label: 'Checklists',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history_rounded),
                label: 'Histórico',
              ),
              const NavigationDestination(
                icon: Icon(Icons.warning_rounded),
                label: 'Ocorrências',
              ),
              const NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart),
                label: 'Compras',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _unhandledAlertCount > 0,
                  label: Text(
                    _unhandledAlertCount > 9 ? '9+' : '$_unhandledAlertCount',
                  ),
                  child: const Icon(Icons.notifications_rounded),
                ),
                label: 'Avisos',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
