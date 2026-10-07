import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/icons.dart';
import '../data/models.dart';
import 'add_transaction_sheet.dart';
import 'transaction_filters_sheet.dart';

/// Aba Transações: separada por meses (igual ao Resumo) e com filtros de
/// tipo, categoria, banco, período personalizado, busca por texto e valor.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.onChanged});

  /// Chamado após exclusão de uma transação (para o app recarregar tudo).
  final VoidCallback? onChanged;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  bool _carregando = true;
  List<TxView> _itens = [];

  List<Category> _categorias = [];
  List<Account> _contas = [];
  FiltrosTransacao _filtros = const FiltrosTransacao.vazio();

  bool get _periodoPersonalizado => _filtros.de != null || _filtros.ate != null;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final categorias = await Db.i.categories();
    final contas = await Db.i.accounts(incluirArquivadas: true);
    final itens = await Db.i.transactions(
      month: _periodoPersonalizado ? null : mesPrefixo(_mes),
      de: _filtros.de == null ? null : toIsoDate(_filtros.de!),
      ate: _filtros.ate == null ? null : toIsoDate(_filtros.ate!),
      tipo: _filtros.tipo,
      categorias: _filtros.categorias.toList(),
      contas: _filtros.contas.toList(),
      texto: _filtros.busca,
      minCents: _filtros.minCents,
      maxCents: _filtros.maxCents,
    );
    if (!mounted) return;
    setState(() {
      _categorias = categorias;
      _contas = contas;
      _itens = itens;
      _carregando = false;
    });
  }

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _carregar();
  }

  void _aplicarFiltros(FiltrosTransacao novos) {
    setState(() => _filtros = novos);
    _carregar();
  }

  Future<void> _abrirFiltros() async {
    final resultado = await showModalBottomSheet<FiltrosTransacao>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionFiltersSheet(
        atual: _filtros,
        categorias: _categorias,
        contas: _contas,
      ),
    );
    if (resultado == null || !mounted) return;
    _aplicarFiltros(resultado);
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

  String _dataTxt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _rotuloTipo(String tipo) => switch (tipo) {
        'expense' => 'Despesas',
        'income' => 'Receitas',
        _ => 'Transferências',
      };

  String _nomeCategoria(int id) {
    for (final c in _categorias) {
      if (c.id == id) return c.name;
    }
    return 'categoria removida';
  }

  String _nomeConta(int id) {
    for (final a in _contas) {
      if (a.id == id) return a.name;
    }
    return 'conta removida';
  }

  String _rotuloPeriodo() {
    final de = _filtros.de;
    final ate = _filtros.ate;
    if (de != null && ate != null) return '${_dataTxt(de)} a ${_dataTxt(ate)}';
    if (de != null) return 'A partir de ${_dataTxt(de)}';
    return 'Até ${_dataTxt(ate!)}';
  }

  String _rotuloValor() {
    final min = _filtros.minCents;
    final max = _filtros.maxCents;
    if (min != null && max != null) {
      return '${formatCents(min)} a ${formatCents(max)}';
    }
    if (min != null) return 'a partir de ${formatCents(min)}';
    return 'até ${formatCents(max!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _cabecalho(context),
        if (!_filtros.vazio) _chipsAtivos(context),
        if (!_carregando && _itens.isNotEmpty) _resumoDoFiltro(context),
        const Divider(height: 1),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _itens.isEmpty
                  ? _vazio(context)
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: _itens.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _item(context, _itens[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  /// Seletor de mês (ou do intervalo personalizado) + botão de filtros.
  Widget _cabecalho(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: [
          if (!_periodoPersonalizado)
            IconButton(
              onPressed: () => _mudarMes(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Mês anterior',
            ),
          Expanded(
            child: Center(
              child: Text(
                _periodoPersonalizado
                    ? _rotuloPeriodo()
                    : capitalize(mesAnoFmt.format(_mes)),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (!_periodoPersonalizado)
            IconButton(
              onPressed: () => _mudarMes(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Próximo mês',
            ),
          IconButton(
            onPressed: _abrirFiltros,
            tooltip: 'Filtros',
            icon: _filtros.ativos == 0
                ? const Icon(Icons.filter_list)
                : Badge(
                    label: Text('${_filtros.ativos}'),
                    child: const Icon(Icons.filter_list),
                  ),
          ),
        ],
      ),
    );
  }

  /// Etiquetas dos filtros ativos (tocar no X remove só aquele filtro).
  Widget _chipsAtivos(BuildContext context) {
    final chips = <Widget>[];
    if (_filtros.tipo != null) {
      chips.add(InputChip(
        label: Text('Tipo: ${_rotuloTipo(_filtros.tipo!)}'),
        onDeleted: () => _aplicarFiltros(_filtros.limparTipo()),
      ));
    }
    for (final id in _filtros.categorias.toList()..sort()) {
      chips.add(InputChip(
        label: Text('Categoria: ${_nomeCategoria(id)}'),
        onDeleted: () => _aplicarFiltros(_filtros.semCategoria(id)),
      ));
    }
    for (final id in _filtros.contas.toList()..sort()) {
      chips.add(InputChip(
        label: Text('Banco: ${_nomeConta(id)}'),
        onDeleted: () => _aplicarFiltros(_filtros.semConta(id)),
      ));
    }
    if (_periodoPersonalizado) {
      chips.add(InputChip(
        label: Text('Período: ${_rotuloPeriodo()}'),
        onDeleted: () => _aplicarFiltros(_filtros.limparPeriodo()),
      ));
    }
    if (_filtros.busca.trim().isNotEmpty) {
      chips.add(InputChip(
        label: Text('Busca: "${_filtros.busca.trim()}"'),
        onDeleted: () => _aplicarFiltros(_filtros.limparBusca()),
      ));
    }
    if (_filtros.minCents != null || _filtros.maxCents != null) {
      chips.add(InputChip(
        label: Text('Valor: ${_rotuloValor()}'),
        onDeleted: () => _aplicarFiltros(_filtros.limparValor()),
      ));
    }
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == chips.length) {
            return TextButton(
              onPressed: () => _aplicarFiltros(const FiltrosTransacao.vazio()),
              child: const Text('Limpar'),
            );
          }
          return chips[i];
        },
      ),
    );
  }

  /// Resumo do que está sendo mostrado: quantidade e somas de entradas/saídas.
  Widget _resumoDoFiltro(BuildContext context) {
    var entradas = 0;
    var saidas = 0;
    for (final t in _itens) {
      if (t.type == 'income') {
        entradas += t.amountCents;
      } else if (t.type == 'expense') {
        saidas += t.amountCents;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          Text(
            '${_itens.length} lançamento${_itens.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          if (entradas > 0)
            Text(
              '+ ${formatCents(entradas)}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          if (entradas > 0 && saidas > 0) const SizedBox(width: 12),
          if (saidas > 0)
            Text(
              '- ${formatCents(saidas)}',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _vazio(BuildContext context) {
    final comFiltros = !_filtros.vazio;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              comFiltros
                  ? Icons.filter_alt_off_outlined
                  : Icons.receipt_long_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              comFiltros
                  ? 'Nenhum lançamento com esses filtros.'
                  : 'Nenhuma transação em ${capitalize(mesAnoFmt.format(_mes))}.\nToque em "Nova transação" para registrar!',
              textAlign: TextAlign.center,
            ),
            if (comFiltros) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    _aplicarFiltros(const FiltrosTransacao.vazio()),
                icon: const Icon(Icons.clear),
                label: const Text('Limpar filtros'),
              ),
            ],
          ],
        ),
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
