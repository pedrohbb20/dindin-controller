import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/tema.dart';
import 'budgets_screen.dart';
import 'contas_previstas_screen.dart';
import 'review_screen.dart';

/// Resumo do mês: receitas, despesas, saldo e o gráfico por categoria
/// (despesas OU receitas, alternável; rosca interativa: tocar destaca a fatia).
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
  int _fatiaTocada = -1; // -1 = nenhuma fatia destacada

  Map<String, int> _metas = {}; // sync_id da categoria → limite (centavos)
  List<Category> _catDespesas = []; // categorias de despesa (nome e meta)
  int _pendentes = 0; // lançamentos importados aguardando conferência
  List<ContaPrevista> _contasPrevistas = []; // contas fixas cadastradas

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
    final metas = decodeMetasJson(await Db.i.getSetting('budgets_json'));
    final catDespesas = await Db.i.categories(type: 'expense');
    final pendentes = await Db.i.importadosPendentes();
    final contasPrevistas = decodeContasPrevistas(
        await Db.i.getSetting('contas_previstas_json'));
    if (!mounted) return;
    setState(() {
      _receitas = totais['income'] ?? 0;
      _despesas = totais['expense'] ?? 0;
      _despCats = desp;
      _recCats = rec;
      _metas = metas;
      _catDespesas = catDespesas;
      _pendentes = pendentes;
      _contasPrevistas = contasPrevistas;
      _carregando = false;
    });
  }

  void _mudarMes(int delta) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + delta);
      _fatiaTocada = -1;
    });
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

  Future<void> _abrirContas() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContasPrevistasScreen()),
    );
    if (mounted) _carregar();
  }

  /// Próximos vencimentos (7 dias) das contas previstas, ou o convite para
  /// cadastrar as primeiras.
  List<Widget> _secaoContas(BuildContext context) {
    final tema = Theme.of(context);
    if (_contasPrevistas.isEmpty) {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _abrirContas,
            icon: const Icon(Icons.event_repeat, size: 18),
            label: const Text('Adicionar contas previstas'),
          ),
        ),
        const SizedBox(height: 20),
      ];
    }

    final hoje = DateTime.now();
    final hojeZero = DateTime(hoje.year, hoje.month, hoje.day);
    final proximos = <(ContaPrevista, DateTime)>[];
    for (final c in _contasPrevistas) {
      final data = c.proximaData();
      final dias = data.difference(hojeZero).inDays;
      if (dias >= 0 && dias <= 6) proximos.add((c, data));
    }
    proximos.sort((a, b) => a.$2.compareTo(b.$2));

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_repeat,
                      size: 18, color: tema.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Contas previstas',
                        style: tema.textTheme.titleSmall),
                  ),
                  TextButton.icon(
                    onPressed: _abrirContas,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Gerenciar'),
                  ),
                ],
              ),
              if (proximos.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Text('Nada vencendo nos próximos 7 dias.',
                      style: tema.textTheme.bodySmall),
                )
              else
                for (final (conta, data) in proximos.take(5))
                  _linhaVencimento(tema, conta, data, hojeZero),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _linhaVencimento(
      ThemeData tema, ContaPrevista conta, DateTime data, DateTime hojeZero) {
    final dias = data.difference(hojeZero).inDays;
    final quando = switch (dias) {
      0 => 'vence hoje',
      1 => 'vence amanhã',
      _ => 'vence em $dias dias',
    };
    final dataTxt =
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
    final cor =
        dias == 0 ? Colors.orange.shade800 : tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              conta.valorCents > 0
                  ? '${conta.nome} · ${formatCents(conta.valorCents)}'
                  : conta.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          Text('$quando ($dataTxt)',
              style: TextStyle(fontSize: 12, color: cor)),
        ],
      ),
    );
  }

  Future<void> _abrirRevisao() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReviewScreen()),
    );
    if (mounted) _carregar();
  }

  /// Cartão que aparece quando os bancos trouxeram lançamentos para conferir.
  List<Widget> _secaoRevisao(BuildContext context) {
    if (_pendentes == 0) return [];
    return [
      Card(
        child: ListTile(
          leading: Icon(Icons.fact_check_outlined,
              color: Theme.of(context).colorScheme.primary),
          title: Text(_pendentes == 1
              ? '1 lançamento importado para conferir'
              : '$_pendentes lançamentos importados para conferir'),
          subtitle: const Text('Vieram dos bancos automaticamente'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _abrirRevisao,
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _abrirMetas() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BudgetsScreen()),
    );
    if (mounted) _carregar();
  }

  /// Bloco das metas: botão para criar a primeira ou o cartão com as barras
  /// de progresso (da categoria mais apertada para a mais folgada).
  List<Widget> _secaoMetas(BuildContext context) {
    if (_metas.isEmpty) {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _abrirMetas,
            icon: const Icon(Icons.track_changes, size: 18),
            label: const Text('Definir metas de orçamento'),
          ),
        ),
        const SizedBox(height: 20),
      ];
    }
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.track_changes,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Metas de orçamento',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  TextButton.icon(
                    onPressed: _abrirMetas,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar'),
                  ),
                ],
              ),
              ..._linhasMetas(),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  /// Monta as linhas (categoria, gasto no mês, limite), priorizando as que
  /// estão mais perto (ou acima) do limite.
  List<Widget> _linhasMetas() {
    final porSync = <String, Category>{
      for (final c in _catDespesas)
        if (c.syncId != null) c.syncId!: c,
    };
    final itens = <(Category, int, int)>[]; // (categoria, gasto, limite)
    for (final entrada in _metas.entries) {
      final cat = porSync[entrada.key];
      if (cat == null) continue; // categoria removida: a meta fica guardada
      var gasto = 0;
      for (final c in _despCats) {
        if (c.name == cat.name) gasto += c.totalCents;
      }
      itens.add((cat, gasto, entrada.value));
    }
    itens.sort((a, b) => (b.$2 / b.$3).compareTo(a.$2 / a.$3));
    return [for (final it in itens) _linhaMeta(it.$1, it.$2, it.$3)];
  }

  Widget _linhaMeta(Category cat, int gasto, int limite) {
    final razao = gasto / limite;
    final cor = razao >= 1
        ? Colors.red.shade700
        : razao >= 0.75
            ? Colors.orange.shade800
            : Colors.green.shade600;
    final sobra = limite - gasto;
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5)),
              ),
              Text(
                '${formatCents(gasto)} de ${formatCents(limite)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: razao > 1 ? 1.0 : razao,
              minHeight: 7,
              color: cor,
              backgroundColor: cor.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sobra >= 0
                ? 'Restam ${formatCents(sobra)}'
                : 'Passou em ${formatCents(-sobra)}',
            style: TextStyle(fontSize: 11.5, color: cor),
          ),
        ],
      ),
    );
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
          const SizedBox(height: 16),

          // ─── Importados aguardando conferência ───
          ..._secaoRevisao(context),

          // ─── Metas de orçamento (se houver alguma definida) ───
          ..._secaoMetas(context),

          // ─── Contas previstas (vencimentos próximos) ───
          ..._secaoContas(context),

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
                onSelectionChanged: (s) => setState(() {
                  _mostrarReceitas = s.first;
                  _fatiaTocada = -1;
                }),
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
                            child: _graficoRosca(fatias, total),
                          ),
                          Center(
                            child: _centroRosca(fatias, total),
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

  /// Rosca interativa (fl_chart): tocar numa fatia a destaca e aumenta.
  Widget _graficoRosca(List<_Fatia> fatias, int total) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, resposta) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  resposta == null ||
                  resposta.touchedSection == null) {
                _fatiaTocada = -1;
                return;
              }
              _fatiaTocada = resposta.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        sectionsSpace: 2,
        centerSpaceRadius: 52,
        sections: [
          for (var i = 0; i < fatias.length; i++)
            _secaoRosca(fatias[i], i, total),
        ],
      ),
    );
  }

  PieChartSectionData _secaoRosca(_Fatia f, int i, int total) {
    final tocada = i == _fatiaTocada;
    final pct = total == 0 ? 0.0 : 100 * f.totalCents / total;
    return PieChartSectionData(
      color: f.cor,
      value: f.totalCents.toDouble(),
      radius: tocada ? 43 : 32,
      showTitle: tocada,
      title: '${pct.toStringAsFixed(0)}%',
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  /// Centro da rosca: mostra o total do mês ou a fatia que está destacada.
  Widget _centroRosca(List<_Fatia> fatias, int total) {
    final destacada = _fatiaTocada >= 0 && _fatiaTocada < fatias.length;
    if (!destacada) {
      return Column(
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
      );
    }
    final f = fatias[_fatiaTocada];
    final pct = total == 0 ? 0.0 : 100 * f.totalCents / total;
    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            f.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            formatCents(f.totalCents),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
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
