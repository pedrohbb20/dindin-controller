import 'package:flutter/material.dart';

import 'add_transaction_sheet.dart';
import 'accounts_screen.dart';
import 'summary_screen.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aba = 0;
  int _versao = 0; // incrementa para recarregar as telas após mudanças

  void _recarregar() => setState(() => _versao++);

  static const _titulos = ['Dindin Controller', 'Transações', 'Contas'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_aba]),
        centerTitle: false,
      ),
      body: IndexedStack(
        index: _aba,
        children: [
          SummaryScreen(key: ValueKey('resumo$_versao')),
          TransactionsScreen(key: ValueKey('txs$_versao'), onChanged: _recarregar),
          AccountsScreen(key: ValueKey('contas$_versao'), onChanged: _recarregar),
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
