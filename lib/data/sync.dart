import 'package:supabase_flutter/supabase_flutter.dart';

import 'database.dart';
import 'sync_config.dart';

/// Resultado de uma sincronização.
class ResultadoSync {
  final bool ok;
  final int enviados;
  final int recebidos;
  final String? mensagem;

  /// Aviso (mensagem informativa, não é erro).
  final bool aviso;
  final List<String> avisos;

  const ResultadoSync({
    required this.ok,
    this.enviados = 0,
    this.recebidos = 0,
    this.mensagem,
    this.aviso = false,
    this.avisos = const [],
  });
}

/// Motor de sincronização PC ↔ celular (Supabase).
///
/// Estratégia (local primeiro):
/// 1. PUXA: tudo que está na nuvem e é mais recente que a cópia local entra
///    no banco daqui (comparação pelo carimbo `updated_at`).
/// 2. EMPURRA: o que é novo ou mais recente daqui sobe para a nuvem.
/// Exclusões viajam como marca (`deleted`), nunca apagando de verdade.
class Sync {
  Sync._();

  static const _lote = 300;
  static const _chavesSync = ['reserve_cents', 'reserve_goal_cents'];

  /// Cliente Supabase (só usar depois de checar [_iniciado]).
  static SupabaseClient get _cli => Supabase.instance.client;

  static bool get configurado => SyncConfig.configurado;

  static bool get _iniciado {
    try {
      // ignore: unnecessary_statements
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool get logado =>
      configurado && _iniciado && _cli.auth.currentUser != null;

  static String? get email => logado ? _cli.auth.currentUser?.email : null;

  // ─── Conta ───

  /// Entra com email e senha. Devolve null em sucesso, ou a mensagem de erro.
  static Future<String?> entrar(String email, String senha) async {
    if (!configurado || !_iniciado) {
      return 'A nuvem não está ligada neste aparelho (reabra o app com internet).';
    }
    try {
      await _cli.auth.signInWithPassword(email: email.trim(), password: senha);
      return null;
    } on AuthException catch (e) {
      return 'Não deu: ${e.message}';
    } catch (e) {
      return 'Falha de conexão: $e';
    }
  }

  /// Cria a conta. Devolve resultado (ok) ou mensagem para o usuário.
  static Future<ResultadoSync> criarConta(String email, String senha) async {
    if (!configurado || !_iniciado) {
      return const ResultadoSync(
          ok: false,
          mensagem:
              'A nuvem não está ligada neste aparelho (reabra o app com internet).');
    }
    try {
      final r = await _cli.auth.signUp(email: email.trim(), password: senha);
      if (r.session == null) {
        return ResultadoSync(
          ok: false,
          aviso: true,
          mensagem: 'Conta criada! Agora confirme o email que enviamos para '
              '$email e depois toque em "Entrar e sincronizar".',
        );
      }
      return const ResultadoSync(ok: true, mensagem: 'Conta criada e conectada!');
    } on AuthException catch (e) {
      return ResultadoSync(ok: false, mensagem: 'Não deu: ${e.message}');
    } catch (e) {
      return ResultadoSync(ok: false, mensagem: 'Falha de conexão: $e');
    }
  }

  static Future<void> sair() async {
    if (!configurado || !_iniciado) return;
    await _cli.auth.signOut();
  }

  // ─── Sincronização ───

  /// Primeira sincronização de um aparelho novo: se o banco local só tem as
  /// sementes (nada digitado ainda), limpa para a nuvem trazer tudo limpo.
  static Future<void> primeiraVezSePreciso() async {
    if (await Db.i.pareceInstalacaoNova()) {
      await Db.i.limparDadosDeSemente();
    }
  }

  static Future<ResultadoSync> sincronizar() async {
    if (!configurado) {
      return const ResultadoSync(
          ok: false, mensagem: 'A chave da nuvem ainda não foi configurada.');
    }
    if (!_iniciado) {
      return const ResultadoSync(
          ok: false,
          mensagem:
              'A nuvem não iniciou neste aparelho (reabra o app com internet).');
    }
    if (_cli.auth.currentUser == null) {
      return const ResultadoSync(
          ok: false, mensagem: 'Entre com a sua conta para sincronizar.');
    }

    var enviados = 0;
    var recebidos = 0;
    final avisos = <String>[];
    try {
      await primeiraVezSePreciso();

      final r1 = await _sincronizarSimples('accounts');
      final r2 = await _sincronizarSimples('categories');
      final r3 = await _sincronizarSimples('investments');
      final r4 = await _sincronizarSimples('dividends');
      final r5 = await _sincronizarTransacoes(avisos);
      final r6 = await _sincronizarSettings();

      enviados = r1.$1 + r2.$1 + r3.$1 + r4.$1 + r5.$1 + r6.$1;
      recebidos = r1.$2 + r2.$2 + r3.$2 + r4.$2 + r5.$2 + r6.$2;

      await Db.i.setSetting('last_sync_at', Db.agoraIso());
      await Db.i.setSetting(
          'last_sync_resumo', 'enviei $enviados · recebi $recebidos');
      await Db.i.setSetting('sync_initialized', '1');

      return ResultadoSync(
          ok: true, enviados: enviados, recebidos: recebidos, avisos: avisos);
    } catch (e) {
      return ResultadoSync(
        ok: false,
        enviados: enviados,
        recebidos: recebidos,
        mensagem: _mensagemErro(e),
        avisos: avisos,
      );
    }
  }

  /// Versão silenciosa (abertura do app): não mostra nada, só tenta.
  static Future<void> silencioso() async {
    try {
      if (!configurado || !_iniciado) return;
      if (_cli.auth.currentUser == null) return;
      await sincronizar();
    } catch (_) {
      // sem nuvem o app continua funcionando normalmente
    }
  }

  // ─── Internos ───

  static String _mensagemErro(Object e) {
    if (e is PostgrestException) {
      final texto = '${e.message} ${e.details ?? ''}';
      if (texto.contains('does not exist')) {
        return 'As tabelas da nuvem ainda não foram criadas '
            '(rode o script SQL no painel do Supabase).';
      }
      return 'Erro da nuvem: ${e.message}';
    }
    return 'Erro: $e';
  }

  static DateTime? _data(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  /// true se [a] é mais recente que [b] (carimbos ISO8601).
  static bool _maisNovo(Object? a, Object? b) {
    final da = _data(a);
    final db = _data(b);
    if (da == null) return false;
    if (db == null) return true;
    return da.isAfter(db);
  }

  static bool _bool(Object? v) => v == true || v == 1 || v == 'true';

  static Iterable<List<Map<String, Object?>>> _lotes(
      List<Map<String, Object?>> itens) sync* {
    for (var i = 0; i < itens.length; i += _lote) {
      final fim = i + _lote > itens.length ? itens.length : i + _lote;
      yield itens.sublist(i, fim);
    }
  }

  /// Busca TODAS as linhas de uma tabela na nuvem (paginando de 1000 em 1000;
  /// o Supabase devolve no máximo 1000 por requisição).
  static Future<List<Map<String, dynamic>>> _buscarTodas(
    String tabela, {
    String ordem = 'sync_id',
  }) async {
    const pagina = 1000;
    final tudo = <Map<String, dynamic>>[];
    final consulta = _cli.from(tabela).select().order(ordem);
    while (true) {
      final lote = await consulta.range(tudo.length, tudo.length + pagina - 1);
      tudo.addAll(lote);
      if (lote.length < pagina) break;
    }
    return tudo;
  }

  /// Sincroniza uma tabela "simples" (sem referências a traduzir).
  static Future<(int, int)> _sincronizarSimples(String tabela) async {
    final db = Db.i;
    final locais = await db.rawAll(tabela);
    final remotas = await _buscarTodas(tabela);

    final locaisPorSync = <String, Map<String, Object?>>{
      for (final l in locais)
        if (l['sync_id'] != null) l['sync_id'] as String: l,
    };
    final remotasPorSync = <String, Map<String, dynamic>>{
      for (final r in remotas) r['sync_id'] as String: r,
    };

    // 1) PUXAR (nuvem → local)
    var recebidos = 0;
    for (final r in remotas) {
      final sid = r['sync_id'] as String;
      final local = locaisPorSync[sid];
      if (local == null) {
        await db.rawInsert(tabela, _paraLocalSimples(tabela, r));
        recebidos++;
      } else if (_maisNovo(r['updated_at'], local['updated_at'])) {
        await db.rawUpdate(tabela, local['id'] as int, _paraLocalSimples(tabela, r));
        recebidos++;
      }
    }

    // 2) EMPURRAR (local → nuvem), só o que é novo ou mais recente que a nuvem
    final atuais = await db.rawAll(tabela);
    final enviar = <Map<String, Object?>>[];
    for (final l in atuais) {
      final sid = l['sync_id'] as String?;
      if (sid == null) continue;
      final remota = remotasPorSync[sid];
      if (remota == null || _maisNovo(l['updated_at'], remota['updated_at'])) {
        enviar.add(_paraNuvemSimples(tabela, l));
      }
    }
    var enviados = 0;
    for (final lote in _lotes(enviar)) {
      await _cli.from(tabela).upsert(lote, defaultToNull: false);
      enviados += lote.length;
    }
    return (enviados, recebidos);
  }

  /// Sincroniza os lançamentos (traduzindo contas/categorias por sync_id).
  static Future<(int, int)> _sincronizarTransacoes(List<String> avisos) async {
    final db = Db.i;
    final contas = await db.rawAll('accounts');
    final cats = await db.rawAll('categories');

    final contaPorId = <int, String>{};
    final contaPorSync = <String, int>{};
    for (final c in contas) {
      final sid = c['sync_id'] as String?;
      if (sid == null) continue;
      contaPorId[c['id'] as int] = sid;
      contaPorSync[sid] = c['id'] as int;
    }
    final catPorId = <int, String>{};
    final catPorSync = <String, int>{};
    for (final c in cats) {
      final sid = c['sync_id'] as String?;
      if (sid == null) continue;
      catPorId[c['id'] as int] = sid;
      catPorSync[sid] = c['id'] as int;
    }

    final locais = await db.rawAll('transactions');
    final remotas = await _buscarTodas('transactions');
    final remotasPorSync = <String, Map<String, dynamic>>{
      for (final r in remotas) r['sync_id'] as String: r,
    };

    // 1) PUXAR (nuvem → local)
    var recebidos = 0;
    for (final r in remotas) {
      final sid = r['sync_id'] as String;
      Map<String, Object?>? local;
      for (final l in locais) {
        if (l['sync_id'] == sid) {
          local = l;
          break;
        }
      }
      if (local != null && !_maisNovo(r['updated_at'], local['updated_at'])) {
        continue;
      }
      final convertida =
          _transacaoParaLocal(r, contaPorSync, catPorSync, avisos);
      if (convertida == null) continue;
      if (local == null) {
        await db.rawInsert('transactions', convertida);
        recebidos++;
      } else {
        await db.rawUpdate('transactions', local['id'] as int, convertida);
        recebidos++;
      }
    }

    // 2) EMPURRAR (local → nuvem)
    final enviar = <Map<String, Object?>>[];
    for (final l in await db.rawAll('transactions')) {
      final sid = l['sync_id'] as String?;
      if (sid == null) {
        avisos.add('Um lançamento sem código de sincronização ficou de fora.');
        continue;
      }
      final remota = remotasPorSync[sid];
      if (remota != null && !_maisNovo(l['updated_at'], remota['updated_at'])) {
        continue;
      }
      final acc = contaPorId[l['account_id'] as int];
      if (acc == null) {
        avisos.add('Um lançamento com conta sem código ficou de fora.');
        continue;
      }
      final toAcc = l['to_account_id'] == null
          ? null
          : contaPorId[l['to_account_id'] as int];
      final cat =
          l['category_id'] == null ? null : catPorId[l['category_id'] as int];
      enviar.add({
        'sync_id': sid,
        'type': l['type'],
        'amount_cents': l['amount_cents'],
        'date': l['date'],
        'account_sync': acc,
        'to_account_sync': toAcc,
        'category_sync': cat,
        'note': l['note'],
        'title': l['title'],
        'deleted': ((l['deleted'] as int?) ?? 0) == 1,
        'updated_at': l['updated_at'],
      });
    }
    var enviados = 0;
    for (final lote in _lotes(enviar)) {
      await _cli.from('transactions').upsert(lote, defaultToNull: false);
      enviados += lote.length;
    }
    return (enviados, recebidos);
  }

  /// Converte um lançamento da nuvem para o formato local (com ids locais).
  static Map<String, Object?>? _transacaoParaLocal(
    Map<String, dynamic> r,
    Map<String, int> contaPorSync,
    Map<String, int> catPorSync,
    List<String> avisos,
  ) {
    final acc = contaPorSync[r['account_sync'] as String?];
    if (acc == null) {
      avisos.add(
          'Um lançamento da nuvem aponta para uma conta que ainda não existe aqui.');
      return null;
    }
    final toAccSync = r['to_account_sync'] as String?;
    final toAcc = toAccSync == null ? null : contaPorSync[toAccSync];
    if (toAccSync != null && toAcc == null) {
      avisos.add(
          'Um lançamento da nuvem aponta para uma conta de destino que ainda não existe aqui.');
      return null;
    }
    final catSync = r['category_sync'] as String?;
    final cat = catSync == null ? null : catPorSync[catSync];
    return {
      'sync_id': r['sync_id'],
      'type': r['type'],
      'amount_cents': (r['amount_cents'] as num).toInt(),
      'date': r['date'],
      'account_id': acc,
      'to_account_id': toAcc,
      'category_id': cat,
      'note': r['note'],
      'title': r['title'],
      'deleted': _bool(r['deleted']) ? 1 : 0,
      'updated_at': r['updated_at'],
    };
  }

  /// Sincroniza as configurações financeiras (reserva de emergência).
  static Future<(int, int)> _sincronizarSettings() async {
    final db = Db.i;
    final remotas = await _buscarTodas('settings', ordem: 'key');
    final remotasPorChave = <String, Map<String, dynamic>>{
      for (final r in remotas) r['key'] as String: r,
    };

    // 1) PUXAR
    var recebidos = 0;
    for (final chave in _chavesSync) {
      final local = await db.settingRow(chave);
      final remota = remotasPorChave[chave];
      if (remota != null &&
          (local == null ||
              _maisNovo(remota['updated_at'], local['updated_at']))) {
        await db.setSetting(chave, remota['value'] as String,
            updatedAt: remota['updated_at'] as String?);
        recebidos++;
      }
    }

    // 2) EMPURRAR
    final enviar = <Map<String, Object?>>[];
    for (final chave in _chavesSync) {
      final local = await db.settingRow(chave);
      if (local == null) continue;
      final remota = remotasPorChave[chave];
      if (remota == null || _maisNovo(local['updated_at'], remota['updated_at'])) {
        var carimbo = local['updated_at'] as String?;
        if (carimbo == null) {
          carimbo = Db.agoraIso();
          await db.setSetting(chave, local['value'] as String, updatedAt: carimbo);
        }
        enviar.add({
          'key': chave,
          'value': local['value'],
          'updated_at': carimbo,
        });
      }
    }
    var enviados = 0;
    if (enviar.isNotEmpty) {
      await _cli
          .from('settings')
          .upsert(enviar, onConflict: 'user_id,key', defaultToNull: false);
      enviados += enviar.length;
    }
    return (enviados, recebidos);
  }

  /// Formato local de uma tabela simples (a partir da linha da nuvem).
  static Map<String, Object?> _paraLocalSimples(
      String tabela, Map<String, dynamic> r) {
    switch (tabela) {
      case 'accounts':
        return {
          'sync_id': r['sync_id'],
          'name': r['name'],
          'type': r['type'],
          'initial_balance_cents':
              (r['initial_balance_cents'] as num?)?.toInt() ?? 0,
          'color_value': (r['color_value'] as num?)?.toInt() ?? 0xFF607D8B,
          'archived': _bool(r['archived']) ? 1 : 0,
          'deleted': _bool(r['deleted']) ? 1 : 0,
          'updated_at': r['updated_at'],
        };
      case 'categories':
        return {
          'sync_id': r['sync_id'],
          'name': r['name'],
          'type': r['type'],
          'icon': (r['icon'] as String?) ?? 'more_horiz',
          'color_value': (r['color_value'] as num?)?.toInt() ?? 0xFF757575,
          'archived': _bool(r['archived']) ? 1 : 0,
          'deleted': _bool(r['deleted']) ? 1 : 0,
          'updated_at': r['updated_at'],
        };
      case 'investments':
        return {
          'sync_id': r['sync_id'],
          'ticker': r['ticker'],
          'kind': r['kind'],
          'quantity': (r['quantity'] as num?)?.toInt() ?? 0,
          'avg_price_cents': (r['avg_price_cents'] as num?)?.toInt() ?? 0,
          'note': r['note'],
          'deleted': _bool(r['deleted']) ? 1 : 0,
          'updated_at': r['updated_at'],
        };
      case 'dividends':
        return {
          'sync_id': r['sync_id'],
          'date': r['date'],
          'ticker': r['ticker'],
          'amount_cents': (r['amount_cents'] as num?)?.toInt() ?? 0,
          'note': r['note'],
          'deleted': _bool(r['deleted']) ? 1 : 0,
          'updated_at': r['updated_at'],
        };
      default:
        throw ArgumentError('Tabela sem mapeamento: $tabela');
    }
  }

  /// Formato da nuvem de uma tabela simples (a partir da linha local).
  static Map<String, Object?> _paraNuvemSimples(
      String tabela, Map<String, Object?> l) {
    switch (tabela) {
      case 'accounts':
        return {
          'sync_id': l['sync_id'],
          'name': l['name'],
          'type': l['type'],
          'initial_balance_cents': l['initial_balance_cents'],
          'color_value': l['color_value'],
          'archived': ((l['archived'] as int?) ?? 0) == 1,
          'deleted': ((l['deleted'] as int?) ?? 0) == 1,
          'updated_at': l['updated_at'],
        };
      case 'categories':
        return {
          'sync_id': l['sync_id'],
          'name': l['name'],
          'type': l['type'],
          'icon': l['icon'],
          'color_value': l['color_value'],
          'archived': ((l['archived'] as int?) ?? 0) == 1,
          'deleted': ((l['deleted'] as int?) ?? 0) == 1,
          'updated_at': l['updated_at'],
        };
      case 'investments':
        return {
          'sync_id': l['sync_id'],
          'ticker': l['ticker'],
          'kind': l['kind'],
          'quantity': l['quantity'],
          'avg_price_cents': l['avg_price_cents'],
          'note': l['note'],
          'deleted': ((l['deleted'] as int?) ?? 0) == 1,
          'updated_at': l['updated_at'],
        };
      case 'dividends':
        return {
          'sync_id': l['sync_id'],
          'date': l['date'],
          'ticker': l['ticker'],
          'amount_cents': l['amount_cents'],
          'note': l['note'],
          'deleted': ((l['deleted'] as int?) ?? 0) == 1,
          'updated_at': l['updated_at'],
        };
      default:
        throw ArgumentError('Tabela sem mapeamento: $tabela');
    }
  }
}
