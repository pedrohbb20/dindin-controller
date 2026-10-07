import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/icons.dart';
import '../data/models.dart';

/// Filtros aplicados na aba Transações (imutável; a tela guarda o atual).
class FiltrosTransacao {
  const FiltrosTransacao({
    this.tipo,
    this.categorias = const {},
    this.contas = const {},
    this.de,
    this.ate,
    this.busca = '',
    this.minCents,
    this.maxCents,
  });

  const FiltrosTransacao.vazio() : this();

  final String? tipo; // null = todos | income | expense | transfer
  final Set<int> categorias;
  final Set<int> contas;
  final DateTime? de;
  final DateTime? ate;
  final String busca;
  final int? minCents;
  final int? maxCents;

  /// Quantos grupos de filtro estão ativos (para o contador do botão).
  int get ativos {
    var n = 0;
    if (tipo != null) n++;
    if (categorias.isNotEmpty) n++;
    if (contas.isNotEmpty) n++;
    if (de != null || ate != null) n++;
    if (busca.trim().isNotEmpty) n++;
    if (minCents != null || maxCents != null) n++;
    return n;
  }

  bool get vazio => ativos == 0;

  FiltrosTransacao limparTipo() => FiltrosTransacao(
        categorias: categorias,
        contas: contas,
        de: de,
        ate: ate,
        busca: busca,
        minCents: minCents,
        maxCents: maxCents,
      );

  FiltrosTransacao limparPeriodo() => FiltrosTransacao(
        tipo: tipo,
        categorias: categorias,
        contas: contas,
        busca: busca,
        minCents: minCents,
        maxCents: maxCents,
      );

  FiltrosTransacao limparBusca() => FiltrosTransacao(
        tipo: tipo,
        categorias: categorias,
        contas: contas,
        de: de,
        ate: ate,
        minCents: minCents,
        maxCents: maxCents,
      );

  FiltrosTransacao limparValor() => FiltrosTransacao(
        tipo: tipo,
        categorias: categorias,
        contas: contas,
        de: de,
        ate: ate,
        busca: busca,
      );

  FiltrosTransacao semCategoria(int id) => FiltrosTransacao(
        tipo: tipo,
        categorias: {...categorias}..remove(id),
        contas: contas,
        de: de,
        ate: ate,
        busca: busca,
        minCents: minCents,
        maxCents: maxCents,
      );

  FiltrosTransacao semConta(int id) => FiltrosTransacao(
        tipo: tipo,
        categorias: categorias,
        contas: {...contas}..remove(id),
        de: de,
        ate: ate,
        busca: busca,
        minCents: minCents,
        maxCents: maxCents,
      );
}

/// Painel de filtros da aba Transações (abre como bottom sheet).
class TransactionFiltersSheet extends StatefulWidget {
  const TransactionFiltersSheet({
    super.key,
    required this.atual,
    required this.categorias,
    required this.contas,
  });

  final FiltrosTransacao atual;
  final List<Category> categorias;
  final List<Account> contas;

  @override
  State<TransactionFiltersSheet> createState() =>
      _TransactionFiltersSheetState();
}

class _TransactionFiltersSheetState extends State<TransactionFiltersSheet> {
  String? _tipo;
  Set<int> _categorias = {};
  Set<int> _contas = {};
  bool _personalizado = false;
  DateTime? _de;
  DateTime? _ate;
  late final TextEditingController _busca;
  late final TextEditingController _min;
  late final TextEditingController _max;
  String? _erroValor;

  @override
  void initState() {
    super.initState();
    _tipo = widget.atual.tipo;
    _categorias = {...widget.atual.categorias};
    _contas = {...widget.atual.contas};
    _personalizado = widget.atual.de != null || widget.atual.ate != null;
    _de = widget.atual.de;
    _ate = widget.atual.ate;
    _busca = TextEditingController(text: widget.atual.busca);
    _min = TextEditingController(
        text: widget.atual.minCents == null
            ? ''
            : centsParaInput(widget.atual.minCents!));
    _max = TextEditingController(
        text: widget.atual.maxCents == null
            ? ''
            : centsParaInput(widget.atual.maxCents!));
  }

  @override
  void dispose() {
    _busca.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  static String _dataTxt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _escolherData(bool ehDe) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: (ehDe ? _de : _ate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: ehDe ? 'Data inicial' : 'Data final',
    );
    if (escolhida == null) return;
    setState(() {
      if (ehDe) {
        _de = escolhida;
      } else {
        _ate = escolhida;
      }
    });
  }

  void _limparTudo() {
    setState(() {
      _tipo = null;
      _categorias = {};
      _contas = {};
      _personalizado = false;
      _de = null;
      _ate = null;
      _busca.clear();
      _min.clear();
      _max.clear();
      _erroValor = null;
    });
  }

  void _aplicar() {
    int? min;
    int? max;
    if (_min.text.trim().isNotEmpty) {
      min = parseAmountToCents(_min.text);
      if (min == null) {
        setState(() => _erroValor =
            'Valor mínimo inválido (use algo maior que zero, ex.: 10,00).');
        return;
      }
    }
    if (_max.text.trim().isNotEmpty) {
      max = parseAmountToCents(_max.text);
      if (max == null) {
        setState(() => _erroValor =
            'Valor máximo inválido (use algo maior que zero, ex.: 250,00).');
        return;
      }
    }
    if (min != null && max != null && min > max) {
      setState(() => _erroValor = 'O valor mínimo ficou maior que o máximo.');
      return;
    }
    Navigator.of(context).pop(FiltrosTransacao(
      tipo: _tipo,
      categorias: _categorias,
      contas: _contas,
      de: _personalizado ? _de : null,
      ate: _personalizado ? _ate : null,
      busca: _busca.text,
      minCents: min,
      maxCents: max,
    ));
  }

  Widget _chipTipo(String rotulo, String? valor) => ChoiceChip(
        label: Text(rotulo),
        selected: _tipo == valor,
        onSelected: (_) => setState(() => _tipo = valor),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Filtros', style: tema.textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: _limparTudo,
                  child: const Text('Limpar tudo'),
                ),
              ],
            ),

            // ─── Tipo ───
            Text('Tipo', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chipTipo('Tudo', null),
                _chipTipo('Despesas', 'expense'),
                _chipTipo('Receitas', 'income'),
                _chipTipo('Transferências', 'transfer'),
              ],
            ),
            const SizedBox(height: 18),

            // ─── Período ───
            Text('Período', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Mês selecionado'),
                  selected: !_personalizado,
                  onSelected: (_) => setState(() {
                    _personalizado = false;
                    _de = null;
                    _ate = null;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Personalizado'),
                  selected: _personalizado,
                  onSelected: (_) => setState(() => _personalizado = true),
                ),
              ],
            ),
            if (_personalizado) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _escolherData(true),
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(
                        _de == null ? 'De: escolher' : 'De: ${_dataTxt(_de!)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _escolherData(false),
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(
                        _ate == null
                            ? 'Até: escolher'
                            : 'Até: ${_dataTxt(_ate!)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),

            // ─── Categorias ───
            Text('Categorias', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in widget.categorias)
                  FilterChip(
                    avatar: CircleAvatar(
                      backgroundColor:
                          Color(c.colorValue).withValues(alpha: 0.25),
                      child: Icon(iconeCategoria(c.icon),
                          size: 14, color: Color(c.colorValue)),
                    ),
                    label: Text(c.name),
                    selected: _categorias.contains(c.id),
                    onSelected: (marcada) => setState(() {
                      if (marcada) {
                        _categorias.add(c.id!);
                      } else {
                        _categorias.remove(c.id);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // ─── Bancos ───
            Text('Bancos', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final a in widget.contas)
                  FilterChip(
                    label: Text(a.name),
                    selected: _contas.contains(a.id),
                    onSelected: (marcada) => setState(() {
                      if (marcada) {
                        _contas.add(a.id!);
                      } else {
                        _contas.remove(a.id);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // ─── Busca ───
            TextField(
              controller: _busca,
              decoration: const InputDecoration(
                labelText: 'Busca (título ou observação)',
                hintText: 'Ex.: 99, Netflix, mercado',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),

            // ─── Valor ───
            Text('Valor (R\$)', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      prefixText: r'R$ ',
                      hintText: '0,00',
                      labelText: 'Mínimo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      prefixText: r'R$ ',
                      hintText: '0,00',
                      labelText: 'Máximo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_erroValor != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _erroValor!,
                  style: TextStyle(
                      color: tema.colorScheme.error, fontSize: 12),
                ),
              ),

            // ─── Aplicar ───
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _aplicar,
                icon: const Icon(Icons.filter_alt),
                label: const Text('Aplicar filtros'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Os filtros ficam ativos enquanto o app estiver aberto.',
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
