import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import 'gerenciar_categorias_dialog.dart';
import 'nova_categoria_dialog.dart';

/// Formulário de transação: cria uma nova ou edita uma existente
/// (despesa, receita ou transferência).
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key, this.editar});

  /// Transação a editar; null = nova transação.
  final Transaction? editar;

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _valorCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  String _tipo = 'expense';
  int? _contaId;
  int? _contaDestinoId;
  int? _categoriaId;
  DateTime _data = DateTime.now();

  bool _carregando = true;
  List<Account> _contas = [];
  List<Category> _categorias = [];
  String? _erro;

  bool get _editando => widget.editar != null;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    // Na edição, contas arquivadas também entram na lista para não perder
    // o vínculo de lançamentos antigos (ex: Mercado Pago).
    final contas = await Db.i.accounts(incluirArquivadas: _editando);
    final cats = await Db.i.categories();
    if (!mounted) return;
    final ed = widget.editar;
    setState(() {
      _contas = contas;
      _categorias = cats;
      if (ed != null) {
        // Edição: pré-preenche com a transação atual.
        _tipo = ed.type;
        _valorCtrl.text = centsParaInput(ed.amountCents);
        _data = DateTime.tryParse(ed.date) ?? _data;
        _notaCtrl.text = ed.note ?? '';
        _contaId = ed.accountId;
        _contaDestinoId = ed.toAccountId;
        _categoriaId = ed.categoryId;
        // Se a categoria não existir mais (foi removida), não seleciona.
        if (_categoriaId != null &&
            !cats.any((c) => c.id == _categoriaId)) {
          _categoriaId = null;
        }
        // Mesmo caso para contas removidas de vez.
        if (_contaId != null && !contas.any((c) => c.id == _contaId)) {
          _contaId = null;
        }
        if (_contaDestinoId != null &&
            !contas.any((c) => c.id == _contaDestinoId)) {
          _contaDestinoId = null;
        }
      } else {
        _contaId = contas.isNotEmpty ? contas.first.id : null;
        _contaDestinoId = contas.length > 1 ? contas[1].id : null;
      }
      _carregando = false;
    });
  }

  List<Category> get _catsDoTipo =>
      _categorias.where((c) => c.type == _tipo).toList();

  /// Abre o diálogo de nova categoria; se criar, já seleciona na transação.
  Future<void> _novaCategoria() async {
    final criada = await showDialog<Category>(
      context: context,
      builder: (_) => NovaCategoriaDialog(tipoInicial: _tipo),
    );
    if (criada == null) return;
    setState(() {
      _categorias = [..._categorias, criada];
      _categoriaId = criada.id;
    });
  }

  /// Abre o diálogo de gerenciar; se removeu alguma, recarrega a lista e
  /// limpa a seleção caso a categoria escolhida tenha sido removida.
  Future<void> _gerenciarCategorias() async {
    final mudou = await showDialog<bool>(
      context: context,
      builder: (_) => GerenciarCategoriasDialog(tipoInicial: _tipo),
    );
    if (mudou != true || !mounted) return;
    final cats = await Db.i.categories();
    if (!mounted) return;
    setState(() {
      _categorias = cats;
      final ids = cats.map((c) => c.id).toSet();
      if (_categoriaId != null && !ids.contains(_categoriaId)) {
        _categoriaId = null;
      }
    });
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _salvar() async {
    final cents = parseAmountToCents(_valorCtrl.text);
    if (cents == null) {
      setState(() => _erro = 'Informe um valor válido (ex: 25,90).');
      return;
    }
    if (_contaId == null) {
      setState(() => _erro = 'Escolha a conta.');
      return;
    }
    if (_tipo != 'transfer' && _categoriaId == null) {
      setState(() => _erro = 'Escolha a categoria.');
      return;
    }
    if (_tipo == 'transfer' &&
        (_contaDestinoId == null || _contaDestinoId == _contaId)) {
      setState(() => _erro =
          'Na transferência, a conta de destino precisa ser diferente.');
      return;
    }

    final tx = Transaction(
      id: widget.editar?.id,
      type: _tipo,
      amountCents: cents,
      date: toIsoDate(_data),
      accountId: _contaId!,
      toAccountId: _tipo == 'transfer' ? _contaDestinoId : null,
      categoryId: _tipo == 'transfer' ? null : _categoriaId,
      note: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
    );
    if (_editando) {
      await Db.i.updateTransaction(tx);
    } else {
      await Db.i.insertTransaction(tx);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: _carregando
          ? const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_editando ? 'Editar transação' : 'Nova transação',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),

                  // Tipo
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Despesa')),
                      ButtonSegment(value: 'income', label: Text('Receita')),
                      ButtonSegment(value: 'transfer', label: Text('Transferir')),
                    ],
                    selected: {_tipo},
                    onSelectionChanged: (s) => setState(() {
                      _tipo = s.first;
                      _categoriaId = null;
                      _erro = null;
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Valor
                  TextField(
                    controller: _valorCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: r'R$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Conta de origem
                  DropdownButtonFormField<int>(
                    initialValue: _contaId,
                    decoration: InputDecoration(
                      labelText: _tipo == 'transfer' ? 'Conta de origem' : 'Conta',
                      border: const OutlineInputBorder(),
                    ),
                    items: _contas
                        .map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _contaId = v),
                  ),

                  if (_tipo == 'transfer') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _contaDestinoId,
                      decoration: const InputDecoration(
                        labelText: 'Conta de destino',
                        border: OutlineInputBorder(),
                      ),
                      items: _contas
                          .map((c) =>
                              DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _contaDestinoId = v),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey('categoria_$_tipo'),
                      initialValue: _categoriaId,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Selecionar'),
                      items: _catsDoTipo
                          .map((c) =>
                              DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _categoriaId = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _gerenciarCategorias,
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('Gerenciar'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: _novaCategoria,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nova categoria'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Data
                  OutlinedButton.icon(
                    onPressed: _escolherData,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('Data: ${dataCurtaFmt.format(_data)}'),
                  ),
                  const SizedBox(height: 12),

                  // Observação
                  TextField(
                    controller: _notaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _erro!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: _salvar,
                    icon: const Icon(Icons.check),
                    label: Text(_editando ? 'Salvar alterações' : 'Salvar'),
                  ),
                ],
              ),
            ),
    );
  }
}
