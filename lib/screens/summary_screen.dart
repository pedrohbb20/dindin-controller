import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/tema.dart';

/// Resumo do mês: receitas, despesas, saldo e o gráfico por categoria
/// (despesas OU receitas, alternável).
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

/// Uma fatia do gráfico (categoria + cor atribuída da paleta).
class _Fatia {
  const _Fatia({
    required this.nome,
    required this.totalCents,
    required this.cor,
  });

  final String nome;
  final int totalCents;
  final Color cor;
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  bool _carregando = true;

  int _receitas = 0;
  int _despesas = 0;
  List<CategoryTotal> _despCats = [];
  List<CategoryTotal> _recCats = [];
  bool _mostrarReceitas = false; // alterna o gráfico despesas/receitas

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final prefixo = mesPrefixo(_mes);
    final totais = await Db.i.monthTotals(prefixo);
    final desp = await Db.i.monthByCategory(prefixo, 'expense');
    final rec = await Db.i.monthByCategory(prefixo, 'income');
    if (!mounted) return;
    setState(() {
      _receitas = totais['income'] ?? 0;
      _despesas = totais['expense'] ?? 0;
      _despCats = desp;
      _recCats = rec;
      _carregando = false;
    });
  }

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _carregar();
  }

  /// Agrupa em no máximo 9 fatias + "Outras", com cores da paleta.
  List<_Fatia> _fatias(List<CategoryTotal> cats) {
    final lista = <_Fatia>[];
    var i = 0;
    var outras = 0;
    for (final c in cats) {
      if (i < 9) {
        lista.add(_Fatia(
          nome: c.name,
          totalCents: c.totalCents,
          cor: paletaGraficos[i % paletaGraficos.length],
        ));
        i++;
      } else {
        outras += c.totalCents;
      }
    }
    if (outras > 0) {
      lista.add(_Fatia(
        nome: 'Outras',
        totalCents: outras,
        cor: paletaGraficos[i % paletaGraficos.length],
      ));
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    final saldoMes = _receitas - _despesas;
    final cats = _mostrarReceitas ? _recCats : _despCats;
    final fatias = _fatias(cats);
    final total = cats.fold<int>(0, (soma, c) => soma + c.totalCents);

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Seletor de mês ───
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _mudarMes(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Mês anterior',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    capitalize(mesAnoFmt.format(_mes)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _mudarMes(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Próximo mês',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ─── Receitas / Despesas do mês ───
          Row(
            children: [
              Expanded(
                child: _cartaoResumo(
                  context,
                  titulo: 'Receitas',
                  valor: _receitas,
                  cor: Colors.green.shade700,
                  icone: Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cartaoResumo(
                  context,
                  titulo: 'Despesas',
                  valor: _despesas,
                  cor: Colors.red.shade700,
                  icone: Icons.arrow_downward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Saldo do mês ───
          Card(
            child: ListTile(
              leading: Icon(
                saldoMes >= 0 ? Icons.savings : Icons.warning_amber_rounded,
                color: saldoMes >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
              title: const Text('Saldo do mês'),
              subtitle: Text(
                  '${capitalize(mesAnoFmt.format(_mes))}: entradas menos saídas'),
              trailing: Text(
                formatCents(saldoMes),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: saldoMes >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Gráfico por categoria (despesas / receitas) ───
          Row(
            children: [
              Expanded(
                child: Text('Por categoria',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Despesas')),
                  ButtonSegment(value: true, label: Text('Receitas')),
                ],
                selected: {_mostrarReceitas},
                onSelectionChanged: (s) =>
                    setState(() => _mostrarReceitas = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fatias.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _mostrarReceitas
                        ? 'Sem receitas neste mês.'
                        : 'Sem despesas neste mês.\nToque em "Nova transação" para começar!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DonutPainter(fatias: fatias),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatCents(total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _mostrarReceitas ? 'em receitas' : 'em gastos',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    for (final f in fatias) _linhaLegenda(context, f, total),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cartaoResumo(
    BuildContext context, {
    required String titulo,
    required int valor,
    required Color cor,
    required IconData icone,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 18, color: cor),
                const SizedBox(width: 6),
                Text(titulo, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatCents(valor),
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: cor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaLegenda(BuildContext context, _Fatia f, int total) {
    final pct = total == 0 ? 0.0 : 100 * f.totalCents / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: f.cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              f.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          Text(
            formatCents(f.totalCents),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desenha o gráfico de rosca (donut) das fatias.
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.fatias});

  final List<_Fatia> fatias;

  @override
  void paint(Canvas canvas, Size size) {
    final total = fatias.fold<int>(0, (s, f) => s + f.totalCents);
    if (total == 0) return;

    final centro = Offset(size.width / 2, size.height / 2);
    final raio = size.shortestSide / 2 - 2;
    const espessura = 30.0;
    final rect = Rect.fromCircle(center: centro, radius: raio - espessura / 2);

    var inicio = -math.pi / 2; // começa no topo
    for (final f in fatias) {
      final sweep = 2 * math.pi * f.totalCents / total;
      final vao = fatias.length > 1 ? 0.025 : 0.0; // respiro entre fatias
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = espessura
        ..color = f.cor;
      canvas.drawArc(
          rect, inicio + vao / 2, math.max(sweep - vao, 0.01), false, paint);
      inicio += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.fatias != fatias;
}
