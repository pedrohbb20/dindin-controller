import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/quotes.dart';

/// Aba de Investimentos: carteira (FIIs, ações, ETFs), proventos e reserva.
class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

const List<String> _mesesCurto = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _labelMes(String ym) {
  final mes = int.parse(ym.substring(5, 7));
  final ano = ym.substring(2, 4);
  return '${_mesesCurto[mes - 1]}/$ano';
}

Color _corDoTipo(String kind) => switch (kind) {
      'fii' => const Color(0xFF3949AB),
      'acao' => const Color(0xFF00897B),
      'etf' => const Color(0xFFEF6C00),
      _ => const Color(0xFF757575),
    };

IconData _iconeDoTipo(String kind) => switch (kind) {
      'fii' => Icons.apartment,
      'acao' => Icons.show_chart,
      'etf' => Icons.pie_chart_outline,
      _ => Icons.savings_outlined,
    };

String _rotuloDoTipo(String kind) => switch (kind) {
      'fii' => 'FIIs',
      'acao' => 'Ações',
      'etf' => 'ETFs',
      _ => 'Outros',
    };

/// Converte texto em centavos aceitando zero/vazio (para a reserva).
int _parseCentsZero(String input) {
  final t = input.trim();
  if (t.isEmpty) return 0;
  var s = t.replaceAll(r'R$', '').replaceAll(' ', '');
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  final v = double.tryParse(s);
  if (v == null || v < 0) return 0;
  return (v * 100).round();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  bool _carregando = true;

  List<Investment> _posicoes = [];
  List<MonthTotal> _porMes = []; // mais recente primeiro
  List<Dividend> _proventos = [];
  int _reservaCents = 0;
  int _metaReservaCents = 0;

  Map<String, Quote> _cotas = {};
  DateTime? _cotasEm;
  bool _buscandoCotas = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final posicoes = await Db.i.investments();
    final porMes = await Db.i.dividendsByMonth(months: 12);
    final proventos = await Db.i.dividends(limit: 20);
    final reserva =
        int.tryParse(await Db.i.getSetting('reserve_cents') ?? '') ?? 0;
    final meta =
        int.tryParse(await Db.i.getSetting('reserve_goal_cents') ?? '') ?? 0;
    if (!mounted) return;
    setState(() {
      _posicoes = posicoes;
      _porMes = porMes;
      _proventos = proventos;
      _reservaCents = reserva;
      _metaReservaCents = meta;
      _carregando = false;
    });
    _buscarCotas();
  }

  /// Busca cotações atuais (Yahoo Finance) sem bloquear a tela.
  Future<void> _buscarCotas() async {
    if (_buscandoCotas || _posicoes.isEmpty) return;
    setState(() => _buscandoCotas = true);
    final tickers = _posicoes.map((p) => p.ticker).toList();
    final cotas = await QuotesService.buscar(tickers);
    if (!mounted) return;
    setState(() {
      if (cotas.isNotEmpty) {
        _cotas = cotas;
        _cotasEm = DateTime.now();
      }
      _buscandoCotas = false;
    });
  }

  String _horaCotas() {
    final t = _cotasEm;
    if (t == null) return '—';
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  // ─── Cálculos ───
  int get _totalInvestido =>
      _posicoes.fold(0, (soma, p) => soma + p.investedCents);

  int _totalPorTipo(String kind) => _posicoes
      .where((p) => p.kind == kind)
      .fold(0, (soma, p) => soma + p.investedCents);

  int get _total12Meses => _porMes.fold(0, (soma, m) => soma + m.totalCents);

  int get _mediaMensal =>
      _porMes.isEmpty ? 0 : (_total12Meses / _porMes.length).round();

  int get _proventoMesAtual {
    final prefixo = mesPrefixo(DateTime.now());
    for (final m in _porMes) {
      if (m.month == prefixo) return m.totalCents;
    }
    return 0;
  }

  int get _qtdFii => _posicoes.where((p) => p.kind == 'fii').length;
  int get _qtdAcao => _posicoes.where((p) => p.kind == 'acao').length;
  int get _qtdEtf => _posicoes.where((p) => p.kind == 'etf').length;

  bool get _temCotas => _cotas.isNotEmpty;

  /// Valor de mercado total (ativos sem cotação entram pelo valor de custo).
  int get _totalMercadoCents {
    var soma = 0;
    for (final p in _posicoes) {
      final cota = _cotas[p.ticker];
      soma += cota == null
          ? p.investedCents
          : (cota.price * p.quantity * 100).round();
    }
    return soma;
  }

  int get _lucroCents => _totalMercadoCents - _totalInvestido;

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    final cs = Theme.of(context).colorScheme;
    final maxMes = _porMes.isEmpty
        ? 1
        : _porMes.map((m) => m.totalCents).reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Patrimônio (valor de mercado) ───
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Patrimônio (valor de mercado)',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      if (_buscandoCotas)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _buscarCotas,
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Atualizar cotações',
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _temCotas ? formatCents(_totalMercadoCents) : '—',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_posicoes.length} ativos'
                          '${_qtdFii > 0 ? ' · $_qtdFii FIIs' : ''}'
                          '${_qtdAcao > 0 ? ' · $_qtdAcao ações' : ''}'
                          '${_qtdEtf > 0 ? ' · $_qtdEtf ETFs' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        _temCotas
                            ? 'cotações ${_horaCotas()} · Yahoo Finance'
                            : 'sem conexão com cotações',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Investido (custo) + Lucro total ───
          Row(
            children: [
              Expanded(
                child: _cartaoResumo(
                  context,
                  titulo: 'Investido (custo)',
                  valor: _totalInvestido,
                  cor: cs.primary,
                  icone: Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cartaoResumo(
                  context,
                  titulo: 'Lucro total',
                  valor: _lucroCents,
                  textoValor: !_temCotas
                      ? '—'
                      : '${_lucroCents >= 0 ? '+' : '-'}'
                          '${formatCents(_lucroCents.abs())}',
                  subtexto: _temCotas && _totalInvestido > 0
                      ? '${_lucroCents >= 0 ? '+' : ''}'
                          '${(100 * _lucroCents / _totalInvestido).toStringAsFixed(1)}% sobre o custo'
                      : null,
                  cor: !_temCotas
                      ? cs.primary
                      : (_lucroCents >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                  icone: Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Proventos do mês / média ───
          Row(
            children: [
              Expanded(
                child: _cartaoResumo(
                  context,
                  titulo: 'Proventos do mês',
                  valor: _proventoMesAtual,
                  cor: Colors.green.shade700,
                  icone: Icons.calendar_month,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cartaoResumo(
                  context,
                  titulo: 'Média mensal (12m)',
                  valor: _mediaMensal,
                  cor: Colors.teal.shade700,
                  icone: Icons.stacked_line_chart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Reserva de emergência ───
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined,
                          size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Reserva de emergência')),
                      IconButton(
                        onPressed: _editarReserva,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Editar reserva',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCents(_reservaCents),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  if (_metaReservaCents > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_reservaCents / _metaReservaCents).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: cs.primary.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(100 * _reservaCents / _metaReservaCents).clamp(0, 100).toStringAsFixed(1)}% da meta '
                      'de ${formatCents(_metaReservaCents)}'
                      '${_reservaCents < _metaReservaCents ? ' · faltam ${formatCents(_metaReservaCents - _reservaCents)}' : ' · meta batida! 🎉'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else
                    Text(
                      'Toque no lápis para definir uma meta.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Proventos por mês ───
          Row(
            children: [
              Expanded(
                child: Text('Proventos por mês',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _abrirEditorProvento,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Registrar'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_porMes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Nenhum provento registrado ainda.\nToque em "Registrar" para lançar o primeiro!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    for (final m in _porMes.take(12))
                      _linhaProventoMes(context, m, maxMes),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined, size: 18),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('Total dos últimos 12 meses')),
                        Text(
                          formatCents(_total12Meses),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ─── Minha carteira ───
          Row(
            children: [
              Expanded(
                child: Text('Minha carteira',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => _abrirEditorPosicao(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_posicoes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Nenhum ativo na carteira.\nToque em "Adicionar" para cadastrar seus FIIs, ações e ETFs!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            )
          else
            ..._secoesDaCarteira(context),

          const SizedBox(height: 20),

          // ─── Proventos recentes ───
          if (_proventos.isNotEmpty) ...[
            Text('Proventos recentes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _proventos.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _linhaProvento(context, _proventos[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Seções da carteira, agrupadas por tipo ───
  List<Widget> _secoesDaCarteira(BuildContext context) {
    final widgets = <Widget>[];
    for (final kind in ['fii', 'acao', 'etf']) {
      final doTipo = _posicoes.where((p) => p.kind == kind).toList();
      if (doTipo.isEmpty) continue;
      final total = _totalPorTipo(kind);
      final cor = _corDoTipo(kind);

      widgets.add(
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(_iconeDoTipo(kind), size: 18, color: cor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_rotuloDoTipo(kind)} (${doTipo.length})',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: cor),
                      ),
                    ),
                    Text(
                      formatCents(total),
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: cor),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final p in doTipo) _linhaPosicao(context, p),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _linhaPosicao(BuildContext context, Investment p) {
    final cor = _corDoTipo(p.kind);
    final total = _totalInvestido;
    final pct = total == 0 ? 0.0 : 100 * p.investedCents / total;
    final cota = _cotas[p.ticker];
    final saldoMercado =
        cota == null ? null : (cota.price * p.quantity * 100).round();
    final variacaoPct = cota == null || p.avgPriceCents == 0
        ? null
        : 100 * (cota.price * 100 - p.avgPriceCents) / p.avgPriceCents;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cor.withValues(alpha: 0.15),
        child: Text(
          p.ticker.characters.first,
          style: TextStyle(color: cor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(p.ticker, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${p.quantity} ${p.kind == 'fii' ? 'cotas' : 'unid.'} '
        '× ${formatCents(p.avgPriceCents)}'
        '${cota != null ? ' · agora ${formatCents((cota.price * 100).round())}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatCents(saldoMercado ?? p.investedCents),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (variacaoPct != null)
            Text(
              '${variacaoPct >= 0 ? '+' : ''}${variacaoPct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: variacaoPct >= 0
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            )
          else
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      onTap: () => _abrirEditorPosicao(existente: p),
      onLongPress: () => _excluirPosicao(p),
    );
  }

  Widget _linhaProventoMes(BuildContext context, MonthTotal m, int maxMes) {
    final fracao = maxMes == 0 ? 0.0 : m.totalCents / maxMes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(_labelMes(m.month),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fracao,
                    minHeight: 8,
                    backgroundColor: Colors.green.withValues(alpha: 0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCents(m.totalCents),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linhaProvento(BuildContext context, Dividend d) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.payments_outlined, size: 20),
      title: Text(
        d.ticker != null && d.ticker!.isNotEmpty
            ? 'Provento · ${d.ticker}'
            : (d.note ?? 'Proventos da carteira'),
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(_dataBonita(d.date),
          style: Theme.of(context).textTheme.bodySmall),
      trailing: Text(
        '+ ${formatCents(d.amountCents)}',
        style: TextStyle(
            fontWeight: FontWeight.w600, color: Colors.green.shade700),
      ),
      onLongPress: () => _excluirProvento(d),
    );
  }

  String _dataBonita(String iso) {
    final partes = iso.split('-');
    if (partes.length != 3) return iso;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  Widget _cartaoResumo(
    BuildContext context, {
    required String titulo,
    required int valor,
    required Color cor,
    required IconData icone,
    String? textoValor,
    String? subtexto,
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
                Expanded(
                  child: Text(titulo,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              textoValor ?? formatCents(valor),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cor),
            ),
            if (subtexto != null) ...[
              const SizedBox(height: 2),
              Text(
                subtexto,
                style: TextStyle(fontSize: 11, color: cor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Ações ───
  Future<void> _excluirPosicao(Investment p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir ${p.ticker}?'),
        content: Text(
            '${p.quantity} ${p.kind == 'fii' ? 'cotas' : 'unidades'} · ${formatCents(p.investedCents)}.\n\nEssa ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar != true) return;
    await Db.i.deleteInvestment(p.id!);
    _carregar();
  }

  Future<void> _excluirProvento(Dividend d) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir provento?'),
        content: Text(
            '${formatCents(d.amountCents)} em ${_dataBonita(d.date)}.\n\nEssa ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar != true) return;
    await Db.i.deleteDividend(d.id!);
    _carregar();
  }

  Future<void> _abrirEditorPosicao({Investment? existente}) async {
    final mudou = await showDialog<bool>(
      context: context,
      builder: (_) => _PosicaoDialog(inicial: existente),
    );
    if (mudou == true) _carregar();
  }

  Future<void> _abrirEditorProvento() async {
    final mudou = await showDialog<bool>(
      context: context,
      builder: (_) => const _ProventoDialog(),
    );
    if (mudou == true) _carregar();
  }

  Future<void> _editarReserva() async {
    final mudou = await showDialog<bool>(
      context: context,
      builder: (_) => _ReservaDialog(
        atualCents: _reservaCents,
        metaCents: _metaReservaCents,
      ),
    );
    if (mudou == true) _carregar();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Diálogo: cadastrar/editar posição
// ─────────────────────────────────────────────────────────────────────────
class _PosicaoDialog extends StatefulWidget {
  const _PosicaoDialog({this.inicial});

  final Investment? inicial;

  @override
  State<_PosicaoDialog> createState() => _PosicaoDialogState();
}

class _PosicaoDialogState extends State<_PosicaoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ticker;
  late final TextEditingController _quantidade;
  late final TextEditingController _precoMedio;
  late final TextEditingController _nota;
  late String _tipo;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _ticker = TextEditingController(text: i?.ticker ?? '');
    _quantidade = TextEditingController(text: i?.quantity.toString() ?? '');
    _precoMedio = TextEditingController(
        text: i != null ? (i.avgPriceCents / 100).toStringAsFixed(2) : '');
    _nota = TextEditingController(text: i?.note ?? '');
    _tipo = i?.kind ?? 'fii';
  }

  @override
  void dispose() {
    _ticker.dispose();
    _quantidade.dispose();
    _precoMedio.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final qtd = int.parse(_quantidade.text.trim());
    final preco = parseAmountToCents(_precoMedio.text)!;
    final posicao = Investment(
      id: widget.inicial?.id,
      ticker: _ticker.text.trim().toUpperCase(),
      kind: _tipo,
      quantity: qtd,
      avgPriceCents: preco,
      note: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
    );
    if (posicao.id == null) {
      await Db.i.insertInvestment(posicao);
    } else {
      await Db.i.updateInvestment(posicao);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.inicial == null ? 'Nova posição' : 'Editar posição'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _ticker,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Ticker (ex.: BTAL11)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o ticker' : null,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fii', label: Text('FII')),
                  ButtonSegment(value: 'acao', label: Text('Ação')),
                  ButtonSegment(value: 'etf', label: Text('ETF')),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantidade,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return (n == null || n <= 0) ? 'Inválida' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _precoMedio,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço médio',
                        prefixText: r'R$ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          parseAmountToCents(v ?? '') == null ? 'Inválido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nota,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Diálogo: registrar provento
// ─────────────────────────────────────────────────────────────────────────
class _ProventoDialog extends StatefulWidget {
  const _ProventoDialog();

  @override
  State<_ProventoDialog> createState() => _ProventoDialogState();
}

class _ProventoDialogState extends State<_ProventoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valor = TextEditingController();
  final _ticker = TextEditingController();
  final _nota = TextEditingController();
  DateTime _data = DateTime.now();

  @override
  void dispose() {
    _valor.dispose();
    _ticker.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final provento = Dividend(
      date: toIsoDate(_data),
      ticker: _ticker.text.trim().isEmpty ? null : _ticker.text.trim().toUpperCase(),
      amountCents: parseAmountToCents(_valor.text)!,
      note: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
    );
    await Db.i.insertDividend(provento);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar provento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _valor,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor recebido',
                  prefixText: r'R$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    parseAmountToCents(v ?? '') == null ? 'Valor inválido' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Data'),
                subtitle: Text(
                    '${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}'),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: _escolherData,
              ),
              TextFormField(
                controller: _ticker,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Ativo (opcional, ex.: BTAL11)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nota,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Diálogo: reserva de emergência
// ─────────────────────────────────────────────────────────────────────────
class _ReservaDialog extends StatefulWidget {
  const _ReservaDialog({required this.atualCents, required this.metaCents});

  final int atualCents;
  final int metaCents;

  @override
  State<_ReservaDialog> createState() => _ReservaDialogState();
}

class _ReservaDialogState extends State<_ReservaDialog> {
  late final TextEditingController _atual;
  late final TextEditingController _meta;

  @override
  void initState() {
    super.initState();
    _atual = TextEditingController(
        text: widget.atualCents > 0
            ? (widget.atualCents / 100).toStringAsFixed(2)
            : '');
    _meta = TextEditingController(
        text: widget.metaCents > 0
            ? (widget.metaCents / 100).toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _atual.dispose();
    _meta.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    await Db.i.setSetting('reserve_cents', _parseCentsZero(_atual.text).toString());
    await Db.i.setSetting(
        'reserve_goal_cents', _parseCentsZero(_meta.text).toString());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reserva de emergência'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _atual,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quanto tenho hoje',
              prefixText: r'R$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _meta,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Meta (quanto quero ter)',
              prefixText: r'R$ ',
              helperText: 'Deixe 0 para não acompanhar meta',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
