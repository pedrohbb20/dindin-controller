import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';

/// Formulário de nova transação (despesa, receita ou transferência).
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

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
    final contas = await Db.i.accounts();
    final cats = await Db.i.categories();
    if (!mounted) return;
    setState(() {
      _contas = contas;
      _categorias = cats;
      _contaId = contas.isNotEmpty ? contas.first.id : null;
      _contaDestinoId = contas.length > 1 ? contas[1].id : null;
      _carregando = false;
    });
  }

  List<Category> get _catsDoTipo =>
      _categorias.where((c) => c.type == _tipo).toList();

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
      setState(() => _erro = 'Na transferência, a conta de destino precisa ser diferente.');
      return;
    }

    await Db.i.insertTransaction(Transaction(
      type: _tipo,
      amountCents: cents,
      date: toIsoDate(_data),
      accountId: _contaId!,
      toAccountId: _tipo == 'transfer' ? _contaDestinoId : null,
      categoryId: _tipo == 'transfer' ? null : _categoriaId,
      note: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
    ));
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
                  Text('Nova transação',
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
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ),
    );
  }
}
