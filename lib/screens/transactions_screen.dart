import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/icons.dart';
import '../data/models.dart';
import 'add_transaction_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.onChanged});

  /// Chamado após exclusão de uma transação (para o app recarregar tudo).
  final VoidCallback? onChanged;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _carregando = true;
  List<TxView> _itens = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final itens = await Db.i.transactions();
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _carregando = false;
    });
  }

  Future<void> _excluir(TxView t) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir transação?'),
        content: Text(
          '${_titulo(t)} de ${formatCents(t.amountCents)} em ${_dataBonita(t.date)}.\n\nEssa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await Db.i.deleteTransaction(t.id);
    widget.onChanged?.call();
  }

  /// Abre o formulário preenchido para editar o lançamento.
  Future<void> _editar(TxView t) async {
    final atual = await Db.i.transactionById(t.id);
    if (atual == null || !mounted) return;
    final mudou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(editar: atual),
    );
    if (mudou == true) {
      await _carregar();
      widget.onChanged?.call();
    }
  }

  String _titulo(TxView t) {
    if (t.type == 'transfer') return 'Transferência';
    return t.categoryName ?? 'Sem categoria';
  }

  String _dataBonita(String iso) {
    final partes = iso.split('-');
    if (partes.length != 3) return iso;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_itens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text(
                'Nenhuma transação ainda.\nToque em "Nova transação" para registrar a primeira!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _itens.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final t = _itens[i];
          return _item(context, t);
        },
      ),
    );
  }

  Widget _item(BuildContext context, TxView t) {
    final cor = t.categoryColor != null
        ? Color(t.categoryColor!)
        : Theme.of(context).colorScheme.secondary;

    final (valorTxt, valorCor) = switch (t.type) {
      'income' => ('+ ${formatCents(t.amountCents)}', Colors.green.shade700),
      'expense' => ('- ${formatCents(t.amountCents)}', Colors.red.shade700),
      _ => (formatCents(t.amountCents), Colors.blueGrey),
    };

    final temTitulo = t.title != null && t.title!.isNotEmpty;
    final temObs = t.note != null && t.note!.isNotEmpty;

    // Linha principal: o título próprio do lançamento; sem ele, a categoria.
    final linhaPrincipal = temTitulo ? t.title! : _titulo(t);

    // Linha do meio: categoria · data · banco (a categoria só aparece aqui
    // quando o título próprio está ocupando a linha principal).
    final partes = <String>[
      if (temTitulo) _titulo(t),
      _dataBonita(t.date),
      if (t.type == 'transfer' && t.toAccountName != null)
        '${t.accountName} → ${t.toAccountName}'
      else
        t.accountName,
    ];

    return ListTile(
      isThreeLine: temObs,
      leading: CircleAvatar(
        backgroundColor: cor.withValues(alpha: 0.18),
        child: Icon(
          t.categoryIcon != null
              ? iconeCategoria(t.categoryIcon)
              : Icons.swap_horiz,
          color: cor,
          size: 20,
        ),
      ),
      title:
          Text(linhaPrincipal, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(partes.join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (temObs)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                t.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
        ],
      ),
      trailing: Text(
        valorTxt,
        style: TextStyle(fontWeight: FontWeight.w600, color: valorCor),
      ),
      onTap: () => _editar(t),
      onLongPress: () => _excluir(t),
    );
  }
}
