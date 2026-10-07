import 'package:flutter/material.dart';

import '../data/sync.dart';
import '../data/tema.dart';
import 'add_transaction_sheet.dart';
import 'accounts_screen.dart';
import 'investments_screen.dart';
import 'summary_screen.dart';
import 'sync_screen.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aba = 0;
  int _versao = 0; // incrementa para recarregar as telas após mudanças

  @override
  void initState() {
    super.initState();
    // Sincronização silenciosa ao abrir (só roda se configurada e logada).
    WidgetsBinding.instance.addPostFrameCallback((_) => Sync.silencioso());
  }

  void _recarregar() => setState(() => _versao++);

  static const _titulos = [
    'Dindin Controller',
    'Transações',
    'Contas',
    'Investimentos',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_aba]),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Sincronização',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              );
              // dados podem ter chegado da nuvem enquanto a tela estava aberta
              if (mounted) _recarregar();
            },
            icon: const Icon(Icons.cloud_outlined),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: Tema.notifier,
            builder: (context, modo, _) => IconButton(
              tooltip: modo == ThemeMode.dark
                  ? 'Mudar para o modo claro'
                  : 'Mudar para o modo escuro',
              onPressed: Tema.alternar,
              icon: Icon(
                modo == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _aba,
        children: [
          SummaryScreen(key: ValueKey('resumo$_versao')),
          TransactionsScreen(key: ValueKey('txs$_versao'), onChanged: _recarregar),
          AccountsScreen(key: ValueKey('contas$_versao'), onChanged: _recarregar),
          InvestmentsScreen(key: ValueKey('inv$_versao')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Resumo',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transações',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Contas',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Investir',
          ),
        ],
      ),
      floatingActionButton: _aba == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: _abrirNovaTransacao,
              icon: const Icon(Icons.add),
              label: const Text('Nova transação'),
            ),
    );
  }

  Future<void> _abrirNovaTransacao() async {
    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddTransactionSheet(),
    );
    if (salvou == true) _recarregar();
  }
}
