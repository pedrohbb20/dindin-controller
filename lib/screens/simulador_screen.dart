import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';

/// Simulador de patrimônio futuro: aportes + juros compostos em duas
/// curvas, o valor NOMINAL e o valor em dinheiro de hoje (descontando a
/// inflação). Roda inteiro no aparelho, sem internet.
class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key, this.inicialCents = 0});

  /// Patrimônio inicial (ex.: valor de mercado atual da carteira).
  final int inicialCents;

  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  double _aporte = 150; // R$ por mês
  double _taxaAnual = 10; // % ao ano (nominal)
  double _inflacaoAnual = 4; // % ao ano
  int _anos = 20;

  double _taxaMensal(double anualPct) =>
      math.pow(1 + anualPct / 100, 1 / 12).toDouble() - 1;

  List<FlSpot> _serie({required bool descontarInflacao}) {
    final rm = _taxaMensal(_taxaAnual);
    final ri = _taxaMensal(_inflacaoAnual);
    final spots = <FlSpot>[];
    var nominal = widget.inicialCents / 100.0;
    for (var m = 0; m <= _anos * 12; m++) {
      if (m > 0) nominal = nominal * (1 + rm) + _aporte;
      final valor = descontarInflacao
          ? nominal / math.pow(1 + ri, m).toDouble()
          : nominal;
      spots.add(FlSpot(m.toDouble(), valor));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nominal = _serie(descontarInflacao: false);
    final real = _serie(descontarInflacao: true);
    final finalNominal = nominal.last.y;
    final finalReal = real.last.y;
    final maxY = finalNominal * 1.05;

    return Scaffold(
      appBar: AppBar(title: const Text('Simulador do futuro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Quanto os seus aportes viram ao longo do tempo, e quanto disso '
            'sobrevive à inflação (o resto é ilusão do número grande).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),

          // ─── Ajustes ───
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                children: [
                  _slider(
                    titulo: 'Aporte por mês',
                    valorTxt: formatCents(_aporte.round() * 100),
                    valor: _aporte,
                    min: 25,
                    max: 2000,
                    divisoes: 79,
                    aoMudar: (v) => setState(() => _aporte = v),
                  ),
                  _slider(
                    titulo: 'Rendimento ao ano',
                    valorTxt: '${_taxaAnual.toStringAsFixed(1)}%',
                    valor: _taxaAnual,
                    min: 4,
                    max: 18,
                    divisoes: 28,
                    aoMudar: (v) => setState(() => _taxaAnual = v),
                  ),
                  _slider(
                    titulo: 'Inflação ao ano',
                    valorTxt: '${_inflacaoAnual.toStringAsFixed(1)}%',
                    valor: _inflacaoAnual,
                    min: 0,
                    max: 10,
                    divisoes: 20,
                    aoMudar: (v) => setState(() => _inflacaoAnual = v),
                  ),
                  _slider(
                    titulo: 'Prazo',
                    valorTxt: '$_anos anos',
                    valor: _anos.toDouble(),
                    min: 5,
                    max: 40,
                    divisoes: 35,
                    aoMudar: (v) => setState(() => _anos = v.round()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Resumo ───
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Em $_anos anos',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _bolinha(cs.primary),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Valor na conta (nominal)')),
                      Text(compactoReais(finalNominal),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _bolinha(cs.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Poder de compra de hoje (inflação de '
                          '${_inflacaoAnual.toStringAsFixed(1)}% ao ano)',
                        ),
                      ),
                      Text(compactoReais(finalReal),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    finalNominal > 0
                        ? 'A inflação come '
                            '${(100 * (1 - finalReal / finalNominal)).toStringAsFixed(0)}% '
                            'desse montante.'
                        : '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Gráfico ───
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 18, 12),
              child: SizedBox(
                height: 240,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (_anos * 12).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (tocados) => [
                          for (final t in tocados)
                            LineTooltipItem(
                              '${(t.x / 12).toStringAsFixed(0)} anos: '
                              '${compactoReais(t.y)}',
                              const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          interval: maxY / 4,
                          getTitlesWidget: (v, meta) => Text(
                            compactoReais(v),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (_anos / 4).ceilToDouble() * 12,
                          getTitlesWidget: (v, meta) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${(v / 12).round()}a',
                                style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: nominal,
                        color: cs.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                            show: true,
                            color: cs.primary.withValues(alpha: 0.10)),
                      ),
                      LineChartBarData(
                        spots: real,
                        color: cs.secondary,
                        barWidth: 3,
                        dashArray: [6, 4],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Simulação educativa: não é promessa de rendimento.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bolinha(Color cor) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      );

  Widget _slider({
    required String titulo,
    required String valorTxt,
    required double valor,
    required double min,
    required double max,
    required int divisoes,
    required ValueChanged<double> aoMudar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(titulo)),
            Text(valorTxt,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          value: valor.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisoes,
          onChanged: aoMudar,
        ),
      ],
    );
  }
}
