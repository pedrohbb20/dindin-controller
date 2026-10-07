import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../data/icons.dart';
import '../data/models.dart';

/// Metas de orçamento: limite mensal de gasto por categoria (despesa).
///
/// Os limites ficam em `settings.budgets_json`, no formato
/// `{ sync_id_da_categoria: limite_em_centavos }`, e viajam na sincronização
/// (PC ↔ celular). Metas de categorias removidas ficam guardadas sem efeito.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  bool _carregando = true;
  List<Category> _categorias = [];
  Map<String, int> _metas = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final cats = await Db.i.categories(type: 'expense');
    final metas = decodeMetasJson(await Db.i.getSetting('budgets_json'));
    if (!mounted) return;
    setState(() {
      _categorias = cats.where((c) => c.syncId != null).toList();
      _metas = metas;
      _carregando = false;
    });
  }

  Future<void> _salvar() =>
      Db.i.setSetting('budgets_json', encodeMetasJson(_metas));

  int get _totalPlanejado =>
      _metas.values.fold<int>(0, (soma, valor) => soma + valor);

  Future<void> _editarMeta(Category cat) async {
    final resultado = await showDialog<_ResultadoMeta>(
      context: context,
      builder: (_) =>
          _DialogMeta(categoria: cat, atualCents: _metas[cat.syncId]),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      if (resultado.remover) {
        _metas.remove(cat.syncId);
      } else if (resultado.limiteCents != null) {
        _metas[cat.syncId!] = resultado.limiteCents!;
      }
    });
    await _salvar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Metas de orçamento')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Metas de orçamento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Defina um limite de gasto mensal por categoria. '
            'A barra de progresso aparece no Resumo e se renova todo mês.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_metas.isNotEmpty) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.track_changes),
                title: Text(
                  _metas.length == 1
                      ? '1 meta definida'
                      : '${_metas.length} metas definidas',
                ),
                subtitle: const Text('Total planejado por mês'),
                trailing: Text(
                  formatCents(_totalPlanejado),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            child: Column(
              children: [for (final cat in _categorias) _tile(context, cat)],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Toque numa categoria para definir, mudar ou remover a meta.',
            style: tema.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Category cat) {
    final meta = _metas[cat.syncId];
    final cor = Color(cat.colorValue);
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: cor.withValues(alpha: 0.18),
        child: Icon(iconeCategoria(cat.icon), size: 18, color: cor),
      ),
      title: Text(cat.name),
      trailing: meta == null
          ? Text('Sem meta', style: Theme.of(context).textTheme.bodySmall)
          : Text(
              formatCents(meta),
              style: TextStyle(fontWeight: FontWeight.w600, color: cor),
            ),
      onTap: () => _editarMeta(cat),
    );
  }
}

/// Resultado escolhido no diálogo: salvar um limite ou remover a meta.
class _ResultadoMeta {
  const _ResultadoMeta.salvar(this.limiteCents) : remover = false;
  const _ResultadoMeta.remover() : limiteCents = null, remover = true;

  final int? limiteCents;
  final bool remover;
}

class _DialogMeta extends StatefulWidget {
  const _DialogMeta({required this.categoria, this.atualCents});

  final Category categoria;
  final int? atualCents;

  @override
  State<_DialogMeta> createState() => _DialogMetaState();
}

class _DialogMetaState extends State<_DialogMeta> {
  late final TextEditingController _campo;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _campo = TextEditingController(
      text: widget.atualCents == null ? '' : centsParaInput(widget.atualCents!),
    );
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _salvar() {
    final cents = parseAmountToCents(_campo.text);
    if (cents == null) {
      setState(() => _erro = 'Digite um valor válido, maior que zero.');
      return;
    }
    Navigator.of(context).pop(_ResultadoMeta.salvar(cents));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Meta de ${widget.categoria.name}'),
      content: TextField(
        controller: _campo,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          prefixText: r'R$ ',
          hintText: '0,00',
          labelText: 'Limite mensal',
          errorText: _erro,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _salvar(),
      ),
      actions: [
        if (widget.atualCents != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _ResultadoMeta.remover()),
            child: Text(
              'Remover',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
