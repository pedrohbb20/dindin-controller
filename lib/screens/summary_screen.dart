import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/icons.dart';
import '../data/models.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  bool _carregando = true;

  int _receitas = 0;
  int _despesas = 0;
  int _patrimonio = 0;
  List<CategoryTotal> _porCategoria = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final prefixo = mesPrefixo(_mes);
    final totais = await Db.i.monthTotals(prefixo);
    final cats = await Db.i.monthExpensesByCategory(prefixo);
    final patr = await Db.i.totalBalance();
    if (!mounted) return;
    setState(() {
      _receitas = totais['income'] ?? 0;
      _despesas = totais['expense'] ?? 0;
      _porCategoria = cats;
      _patrimonio = patr;
      _carregando = false;
    });
  }

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    final cs = Theme.of(context).colorScheme;
    final saldoMes = _receitas - _despesas;
    final maxTotal = _porCategoria.isEmpty ? 1 : _porCategoria.first.totalCents;

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

          // ─── Patrimônio total ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patrimônio (todas as contas)',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    formatCents(_patrimonio),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

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

          Card(
            child: ListTile(
              leading: Icon(
                saldoMes >= 0 ? Icons.savings : Icons.warning_amber_rounded,
                color: saldoMes >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
              title: const Text('Saldo do mês'),
              subtitle: Text('${capitalize(mesAnoFmt.format(_mes))}: entradas menos saídas'),
              trailing: Text(
                formatCents(saldoMes),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: saldoMes >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Gastos por categoria ───
          Text('Gastos por categoria',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_porCategoria.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Sem despesas neste mês.\nToque em "Nova transação" para começar!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            )
          else
            ..._porCategoria.map((c) => _linhaCategoria(context, c, maxTotal)),
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaCategoria(BuildContext context, CategoryTotal c, int maxTotal) {
    final cor = Color(c.colorValue);
    final fracao = maxTotal == 0 ? 0.0 : c.totalCents / maxTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cor.withValues(alpha: 0.18),
                  child: Icon(
                    iconeCategoria(c.icon),
                    size: 18,
                    color: cor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(c.name)),
                Text(
                  formatCents(c.totalCents),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fracao,
                minHeight: 6,
                backgroundColor: cor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(cor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
