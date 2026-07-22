import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/screens/api/api_history_page.dart';
import 'package:morro_do_peo/screens/api/api_occurrences_page.dart';
import 'package:morro_do_peo/screens/api/api_today_page.dart';
import 'package:morro_do_peo/state/app_session.dart';

class ApiHomePage extends StatefulWidget {
  const ApiHomePage({super.key});

  @override
  State<ApiHomePage> createState() => _ApiHomePageState();
}

class _ApiHomePageState extends State<ApiHomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;

    final pages = const [ApiTodayPage(), ApiHistoryPage(), ApiOccurrencesPage()];
    final titles = const ['Hoje', 'Histórico', 'Ocorrências'];

    Future<void> confirmChangePerson() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trocar de pessoa?'),
          content: const Text('As respostas não enviadas continuarão salvas neste aparelho.'),
          actions: [
            TextButton(onPressed: () => context.pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => context.pop(true), child: const Text('Trocar')),
          ],
        ),
      );
      if (ok == true && mounted) context.go('/collaborators');
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.swap_horiz_rounded, size: 28), onPressed: confirmChangePerson),
        title: Text(op == null ? titles[_index] : '${titles[_index]} · ${op.name}'),
      ),
      body: pages[_index],
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.14),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Hoje'),
            NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Histórico'),
            NavigationDestination(icon: Icon(Icons.warning_rounded), label: 'Ocorrências'),
          ],
        ),
      ),
    );
  }
}
