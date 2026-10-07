import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/icons.dart';
import '../data/models.dart';
import '../data/tema.dart';

/// Diálogo para criar uma nova categoria (despesa ou receita).
///
/// Retorna a [Category] criada (já com id) ou null se o usuário cancelar.
class NovaCategoriaDialog extends StatefulWidget {
  const NovaCategoriaDialog({super.key, this.tipoInicial = 'expense'});

  final String tipoInicial;

  @override
  State<NovaCategoriaDialog> createState() => _NovaCategoriaDialogState();
}

class _NovaCategoriaDialogState extends State<NovaCategoriaDialog> {
  final _nomeCtrl = TextEditingController();
  late String _tipo = widget.tipoInicial == 'income' ? 'income' : 'expense';
  String _icone = 'more_horiz';
  int _cor = paletaCoresInt.first;
  String? _erro;
  bool _salvando = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Dê um nome para a categoria.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final nova = Category(
        name: nome,
        type: _tipo,
        icon: _icone,
        colorValue: _cor,
      );
      final id = await Db.i.insertCategory(nova);
      if (!mounted) return;
      Navigator.of(context).pop(Category(
        id: id,
        name: nome,
        type: _tipo,
        icon: _icone,
        colorValue: _cor,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível criar. Tente outro nome.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Nova categoria'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pré-visualização + nome
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(_cor).withValues(alpha: 0.2),
                    child: Icon(iconeCategoria(_icone), color: Color(_cor)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nomeCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nome (ex.: Pet, Igreja, Viagem)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _salvar(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tipo
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Despesa')),
                  ButtonSegment(value: 'income', label: Text('Receita')),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 14),

              // Ícone
              Text('Ícone', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entrada in kIconesCategoria.entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _icone = entrada.key),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: _icone == entrada.key
                            ? Color(_cor).withValues(alpha: 0.25)
                            : cs.surfaceContainerHighest,
                        child: Icon(
                          entrada.value,
                          size: 20,
                          color: _icone == entrada.key
                              ? Color(_cor)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Cor
              Text('Cor', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in paletaCoresInt)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _cor = v),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(v),
                          shape: BoxShape.circle,
                          border: _cor == v
                              ? Border.all(color: cs.onSurface, width: 2.5)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),

              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!, style: TextStyle(color: cs.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Criar categoria'),
        ),
      ],
    );
  }
}
