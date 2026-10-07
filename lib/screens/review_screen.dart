import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/icons.dart';
import '../data/models.dart';

/// Fila de conferência dos lançamentos que entraram automaticamente pelos
/// bancos (importação Pluggy). Permite corrigir a categoria na hora.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _carregando = true;
  List<TxView> _itens = [];
  List<Category> _categorias = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final itens = await Db.i.importadosParaConferir();
    final categorias = await Db.i.categories();
    if (!mounted) return;
    setState(() {
      _itens = itens;
      _categorias = categorias;
      _carregando = false;
    });
  }

  Future<void> _marcarTudo() async {
    await Db.i.marcarImportadosConferidos();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _corrigir(TxView t) async {
    final atual = await Db.i.transactionById(t.id);
    if (atual == null || !mounted) return;
    final opcoes = _categorias.where((c) => c.type == atual.type).toList();
    final escolhida = await showDialog<Category>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Categoria'),
        content: SizedBox(
          width: 360,
          height: 420,
          child: ListView(
            children: [
              for (final c in opcoes)
                ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        Color(c.colorValue).withValues(alpha: 0.2),
                    child: Icon(iconeCategoria(c.icon),
                        size: 16, color: Color(c.colorValue)),
                  ),
                  title: Text(c.name),
                  selected: c.id == atual.categoryId,
                  onTap: () => Navigator.of(ctx).pop(c),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (escolhida == null || !mounted) return;
    await Db.i.updateTransaction(Transaction(
      id: atual.id,
      type: atual.type,
      amountCents: atual.amountCents,
      date: atual.date,
      accountId: atual.accountId,
      toAccountId: atual.toAccountId,
      categoryId: escolhida.id,
      title: atual.title,
      note: atual.note,
    ));
    await _carregar();
  }

  String _dataBonita(String iso) {
    final partes = iso.split('-');
    if (partes.length != 3) return iso;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferir importados'),
        actions: [
          TextButton(
            onPressed: _itens.isEmpty ? null : _marcarTudo,
            child: const Text('Marcar tudo como visto'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _itens.isEmpty
              ? _vazio(context)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _itens.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == 0) return _cabecalho(context);
                    return _item(context, _itens[i - 1]);
                  },
                ),
    );
  }

  Widget _cabecalho(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Text(
        'Estes lançamentos entraram sozinhos, direto dos bancos. '
        'Confira as categorias; toque para corrigir.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _vazio(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            const Text('Tudo conferido por aqui! 🎉',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, TxView t) {
    final cor = t.categoryColor != null
        ? Color(t.categoryColor!)
        : Theme.of(context).colorScheme.secondary;

    final valor = switch (t.type) {
      'income' => '+ ${formatCents(t.amountCents)}',
      'expense' => '- ${formatCents(t.amountCents)}',
      _ => formatCents(t.amountCents),
    };
    final valorCor = switch (t.type) {
      'income' => Colors.green.shade700,
      'expense' => Colors.red.shade700,
      _ => Colors.blueGrey,
    };

    final ehTransferencia = t.type == 'transfer';

    return ListTile(
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
      title: Text(
        (t.note == null || t.note!.isEmpty) ? 'Sem descrição' : t.note!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_dataBonita(t.date)} · ${t.accountName} · $valor',
        style: TextStyle(
            color: valorCor, fontWeight: FontWeight.w600, fontSize: 12.5),
      ),
      trailing: ehTransferencia
          ? const Text('Transferência')
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: OutlinedButton.icon(
                onPressed: () => _corrigir(t),
                icon: const Icon(Icons.edit, size: 14),
                label: Text(
                  t.categoryName ?? 'Sem categoria',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
      onTap: ehTransferencia ? null : () => _corrigir(t),
    );
  }
}
