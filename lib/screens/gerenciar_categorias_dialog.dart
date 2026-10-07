import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/icons.dart';
import '../data/models.dart';

/// Diálogo para gerenciar categorias: lista as existentes (despesas ou
/// receitas) e permite remover cada uma.
///
/// A remoção vira marca (`deleted`), viaja na sincronização e desvincula os
/// lançamentos ativos que usavam a categoria (eles ficam sem categoria).
///
/// Retorna `true` quando alguma categoria foi removida.
class GerenciarCategoriasDialog extends StatefulWidget {
  const GerenciarCategoriasDialog({super.key, this.tipoInicial = 'expense'});

  final String tipoInicial;

  @override
  State<GerenciarCategoriasDialog> createState() =>
      _GerenciarCategoriasDialogState();
}

class _GerenciarCategoriasDialogState extends State<GerenciarCategoriasDialog> {
  late String _tipo = widget.tipoInicial == 'income' ? 'income' : 'expense';
  List<Category> _todas = [];
  bool _carregando = true;
  bool _mudou = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final cats = await Db.i.categories();
    if (!mounted) return;
    setState(() {
      _todas = cats;
      _carregando = false;
    });
  }

  List<Category> get _doTipo => _todas.where((c) => c.type == _tipo).toList();

  Future<void> _remover(Category c) async {
    final n = await Db.i.transacoesComCategoria(c.id!);
    if (!mounted) return;
    final detalhe = n == 0
        ? 'Nenhum lançamento usa esta categoria.'
        : (n == 1
            ? 'Esta categoria está em 1 lançamento. Ele vai ficar sem categoria.'
            : 'Esta categoria está em $n lançamentos. Eles vão ficar sem categoria.');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remover "${c.name}"?'),
        content: Text(detalhe),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await Db.i.deleteCategory(c.id!);
    if (!mounted) return;
    setState(() {
      _mudou = true;
      _todas = _todas.where((x) => x.id != c.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Gerenciar categorias'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Despesas')),
                      ButtonSegment(value: 'income', label: Text('Receitas')),
                    ],
                    selected: {_tipo},
                    onSelectionChanged: (s) => setState(() => _tipo = s.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _doTipo.isEmpty
                        ? Center(
                            child: Text(
                              _tipo == 'expense'
                                  ? 'Nenhuma categoria de despesa.'
                                  : 'Nenhuma categoria de receita.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _doTipo.length,
                            itemBuilder: (context, i) {
                              final c = _doTipo[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(c.colorValue)
                                      .withValues(alpha: 0.2),
                                  child: Icon(
                                    iconeCategoria(c.icon),
                                    size: 18,
                                    color: Color(c.colorValue),
                                  ),
                                ),
                                title: Text(c.name),
                                trailing: IconButton(
                                  tooltip: 'Remover',
                                  icon: Icon(Icons.delete_outline,
                                      color: cs.error),
                                  onPressed: () => _remover(c),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_mudou),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
