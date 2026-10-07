import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/transferencias.dart';

/// Tela "Possíveis transferências": sugere casar uma saída e uma entrada de
/// mesmo valor em contas diferentes, que provavelmente são a mesma
/// transferência entre as contas do usuário (ex.: Pix do Nubank para o
/// Mercado Pago). Casar evita contar como despesa + receita e mantém os
/// saldos das contas certos.
class TransferenciasScreen extends StatefulWidget {
  const TransferenciasScreen({super.key});

  @override
  State<TransferenciasScreen> createState() => _TransferenciasScreenState();
}

class _TransferenciasScreenState extends State<TransferenciasScreen> {
  bool _carregando = true;
  List<ParTransferencia> _pares = [];
  Map<int, String> _contas = {};
  Set<String> _ignoradas = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final contas = await Db.i.accounts();
    final candidatas = await Db.i.transacoesRecentes();
    final ignoradas = decodeParesIgnorados(
        await Db.i.getSetting('transferencias_ignoradas_json'));
    final pares = encontrarParesTransferencia(candidatas, ignoradas: ignoradas);
    if (!mounted) return;
    setState(() {
      _contas = {for (final c in contas) c.id ?? -1: c.name};
      _ignoradas = ignoradas;
      _pares = pares;
      _carregando = false;
    });
  }

  Future<void> _casar(ParTransferencia p) async {
    await Db.i.casarParComoTransferencia(
        p.saida.id!, p.entrada.id!, p.entrada.accountId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Casal como transferência ✓ não conta mais como despesa + receita')));
    _carregar();
  }

  Future<void> _naoEhTransferencia(ParTransferencia p) async {
    final novas = {..._ignoradas, p.chave};
    await Db.i.setSetting(
        'transferencias_ignoradas_json', encodeParesIgnorados(novas));
    _carregar();
  }

  String _dataCurta(String iso) =>
      iso.length >= 10 ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}' : iso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Possíveis transferências')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _pares.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz,
                            size: 44, color: tema.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text('Nenhuma transferência para casar por agora.',
                            textAlign: TextAlign.center,
                            style: tema.textTheme.bodyMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Quando uma saída e uma entrada de mesmo valor aparecerem em contas diferentes, elas vão aparecer aqui.',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pares.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                        child: Text(
                          'O dinheiro saiu de uma conta e entrou em outra. '
                          'Casar junta os dois lados numa única transferência.',
                          style: tema.textTheme.bodySmall,
                        ),
                      );
                    }
                    return _cartaoPar(tema, _pares[i - 1]);
                  },
                ),
    );
  }

  Widget _cartaoPar(ThemeData tema, ParTransferencia p) {
    final saida = p.saida;
    final entrada = p.entrada;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatCents(saida.amountCents),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            _linha(tema, Icons.arrow_upward, Colors.red.shade700,
                'Saiu de ${_contas[saida.accountId] ?? 'conta'}', saida),
            const SizedBox(height: 4),
            _linha(tema, Icons.arrow_downward, Colors.green.shade700,
                'Entrou em ${_contas[entrada.accountId] ?? 'conta'}', entrada),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _naoEhTransferencia(p),
                  child: const Text('Não é transferência'),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: () => _casar(p),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Casar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(ThemeData tema, IconData icone, Color cor, String rotulo,
      Transaction t) {
    final detalhe = (t.note ?? t.title ?? '').trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icone, size: 18, color: cor),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rotulo, style: const TextStyle(fontSize: 13.5)),
              Text(
                detalhe.isEmpty
                    ? _dataCurta(t.date)
                    : '${_dataCurta(t.date)} · $detalhe',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
