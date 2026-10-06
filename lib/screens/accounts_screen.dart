import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _carregando = true;
  List<AccountBalance> _contas = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final contas = await Db.i.accountBalances();
    if (!mounted) return;
    setState(() {
      _contas = contas;
      _carregando = false;
    });
  }

  Future<void> _novaConta() async {
    final nomeCtrl = TextEditingController();
    final saldoCtrl = TextEditingController();
    String tipo = 'cash';

    final criou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nova conta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome (ex: Nubank, Reserva...)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Carteira (dinheiro)')),
                  DropdownMenuItem(value: 'bank', child: Text('Conta bancária')),
                  DropdownMenuItem(value: 'savings', child: Text('Poupança / Reserva')),
                  DropdownMenuItem(value: 'credit', child: Text('Crédito')),
                ],
                onChanged: (v) => setDialogState(() => tipo = v ?? 'cash'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: saldoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Saldo inicial (opcional)',
                  prefixText: r'R$ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    if (criou != true) return;
    final nome = nomeCtrl.text.trim();
    if (nome.isEmpty) return;
    final saldo = saldoCtrl.text.trim().isEmpty
        ? 0
        : (parseAmountToCents(saldoCtrl.text) ?? 0);
    await Db.i.insertAccount(Account(
      name: nome,
      type: tipo,
      initialBalanceCents: saldo,
    ));
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          ..._contas.map((c) => _cartaoConta(context, c)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _novaConta,
              icon: const Icon(Icons.add),
              label: const Text('Nova conta'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoConta(BuildContext context, AccountBalance c) {
    final cor = Color(c.colorValue);
    final positivo = c.balanceCents >= 0;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.18),
          child: Icon(
            switch (c.type) {
              'cash' => Icons.payments_outlined,
              'bank' => Icons.account_balance_outlined,
              'savings' => Icons.savings_outlined,
              'credit' => Icons.credit_card,
              _ => Icons.account_balance_wallet_outlined,
            },
            color: cor,
            size: 22,
          ),
        ),
        title: Text(c.name),
        subtitle: Text(c.typeLabel),
        trailing: Text(
          formatCents(c.balanceCents),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: positivo ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ),
    );
  }
}
