import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/notificacoes.dart';

/// Gerenciar as contas previstas (fixas): Netflix no dia 12, salário no
/// dia 5... O Dindin avisa por notificação às 9h do dia de cada vencimento.
class ContasPrevistasScreen extends StatefulWidget {
  const ContasPrevistasScreen({super.key});

  @override
  State<ContasPrevistasScreen> createState() => _ContasPrevistasScreenState();
}

class _ContasPrevistasScreenState extends State<ContasPrevistasScreen> {
  bool _carregando = true;
  List<ContaPrevista> _contas = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final contas = decodeContasPrevistas(
        await Db.i.getSetting('contas_previstas_json'));
    contas.sort((a, b) => a.dia.compareTo(b.dia));
    if (!mounted) return;
    setState(() {
      _contas = contas;
      _carregando = false;
    });
  }

  Future<void> _salvar() async {
    await Db.i.setSetting(
        'contas_previstas_json', encodeContasPrevistas(_contas));
    await Notificacoes.programarVencimentos(_contas);
  }

  Future<void> _adicionar() async {
    final nova = await showDialog<ContaPrevista>(
      context: context,
      builder: (_) => const _ContaDialog(),
    );
    if (nova == null || !mounted) return;
    setState(() {
      _contas = [..._contas, nova]..sort((a, b) => a.dia.compareTo(b.dia));
    });
    await _salvar();
  }

  Future<void> _editar(ContaPrevista conta) async {
    final mudou = await showDialog<ContaPrevista>(
      context: context,
      builder: (_) => _ContaDialog(inicial: conta),
    );
    if (mudou == null || !mounted) return;
    setState(() {
      _contas = [
        for (final item in _contas)
          if (item.id == mudou.id) mudou else item,
      ]..sort((a, b) => a.dia.compareTo(b.dia));
    });
    await _salvar();
  }

  Future<void> _remover(ContaPrevista conta) async {
    setState(() {
      _contas = [
        for (final item in _contas)
          if (item.id != conta.id) item,
      ];
    });
    await _salvar();
  }

  Future<void> _testarNotificacao() async {
    await Notificacoes.pedirPermissao();
    await Notificacoes.testar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Notificação de teste enviada! Se não apareceu, confira as permissões do sistema.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas previstas'),
        actions: [
          IconButton(
            onPressed: _testarNotificacao,
            tooltip: 'Testar notificação',
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionar,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Text(
                  'Cadastre as contas que vencem todo mês. O Dindin te avisa '
                  'por notificação às 9h do dia de cada vencimento (e mostra '
                  'os próximos no Resumo).',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_contas.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.event_repeat,
                              size: 48, color: tema.colorScheme.outline),
                          const SizedBox(height: 10),
                          const Text(
                            'Nenhuma conta prevista ainda.\nToque em "Adicionar" para cadastrar a primeira!',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < _contas.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _linha(tema, _contas[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _linha(ThemeData tema, ContaPrevista conta) {
    final valor = conta.valorCents > 0
        ? '~ ${formatCents(conta.valorCents)}'
        : 'valor não informado';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tema.colorScheme.primary.withValues(alpha: 0.15),
        child: Icon(Icons.event_repeat,
            size: 20, color: tema.colorScheme.primary),
      ),
      title: Text(conta.nome),
      subtitle: Text('Todo dia ${conta.dia} · $valor'),
      trailing: IconButton(
        onPressed: () => _remover(conta),
        tooltip: 'Remover',
        icon: const Icon(Icons.delete_outline),
      ),
      onTap: () => _editar(conta),
    );
  }
}

/// Diálogo de cadastro/edição de uma conta prevista.
class _ContaDialog extends StatefulWidget {
  const _ContaDialog({this.inicial});

  final ContaPrevista? inicial;

  @override
  State<_ContaDialog> createState() => _ContaDialogState();
}

class _ContaDialogState extends State<_ContaDialog> {
  late final TextEditingController _nome;
  late final TextEditingController _dia;
  late final TextEditingController _valor;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _nome = TextEditingController(text: i?.nome ?? '');
    _dia = TextEditingController(text: i?.dia.toString() ?? '');
    _valor = TextEditingController(
        text: i != null && i.valorCents > 0 ? centsParaInput(i.valorCents) : '');
  }

  @override
  void dispose() {
    _nome.dispose();
    _dia.dispose();
    _valor.dispose();
    super.dispose();
  }

  void _salvar() {
    final nome = _nome.text.trim();
    final dia = int.tryParse(_dia.text.trim());
    if (nome.isEmpty || dia == null || dia < 1 || dia > 31) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preencha o nome e um dia válido (1 a 31).'),
      ));
      return;
    }
    final valorCents =
        _valor.text.trim().isEmpty ? 0 : (parseAmountToCents(_valor.text) ?? 0);
    Navigator.of(context).pop(ContaPrevista(
      id: widget.inicial?.id ?? const Uuid().v4(),
      nome: nome,
      valorCents: valorCents,
      dia: dia,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.inicial == null ? 'Nova conta prevista' : 'Editar conta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nome,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome (ex.: Netflix)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dia,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Dia do mês',
                    hintText: '1 a 31',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _valor,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor (opcional)',
                    prefixText: r'R$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A notificação chega às 9h desse dia, todo mês.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
