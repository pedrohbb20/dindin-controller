import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';

import 'models.dart';

/// Banco de dados local do Dindin Controller (SQLite).
///
/// v3: todas as tabelas sincronizáveis ganharam as colunas `sync_id`
/// (código único do registro), `updated_at` (carimbo de tempo, ISO8601 UTC)
/// e `deleted` (marca de exclusão). Exclusões viram marca em vez de sumirem,
/// para poderem viajar até o outro aparelho na sincronização (ver sync.dart).
class Db {
  Db._();
  static final Db i = Db._();

  static const _uuid = Uuid();

  /// Tabelas que participam da sincronização.
  static const tabelasSync = [
    'accounts',
    'categories',
    'investments',
    'dividends',
    'transactions',
  ];

  Database? _db;

  /// Carimbo de tempo atual em ISO8601 UTC (padrão da sincronização).
  static String agoraIso() => DateTime.now().toUtc().toIso8601String();

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'dindin.db');
    return openDatabase(
      path,
      version: 4,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        initial_balance_cents INTEGER NOT NULL DEFAULT 0,
        color_value INTEGER NOT NULL DEFAULT 4284513675,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'more_horiz',
        color_value INTEGER NOT NULL DEFAULT 4287332747,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        date TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        to_account_id INTEGER REFERENCES accounts(id),
        category_id INTEGER REFERENCES categories(id),
        note TEXT,
        title TEXT
      )
    ''');

    await _createInvestTables(db);
    // Mesmas colunas de sincronização que os bancos antigos recebem
    await _migrateToV3(db);

    // ─── Semente: categorias padrão ───
    final categorias = <Map<String, Object?>>[
      // Despesas
      {'name': 'Alimentação', 'type': 'expense', 'icon': 'restaurant', 'color_value': 0xFFEF6C00},
      {'name': 'Transporte', 'type': 'expense', 'icon': 'directions_bus', 'color_value': 0xFF1976D2},
      {'name': 'Moradia', 'type': 'expense', 'icon': 'home', 'color_value': 0xFF6D4C41},
      {'name': 'Saúde', 'type': 'expense', 'icon': 'favorite', 'color_value': 0xFFE53935},
      {'name': 'Educação', 'type': 'expense', 'icon': 'school', 'color_value': 0xFF3949AB},
      {'name': 'Lazer', 'type': 'expense', 'icon': 'sports_esports', 'color_value': 0xFF8E24AA},
      {'name': 'Compras', 'type': 'expense', 'icon': 'shopping_bag', 'color_value': 0xFFD81B60},
      {'name': 'Contas e Serviços', 'type': 'expense', 'icon': 'receipt_long', 'color_value': 0xFF546E7A},
      {'name': 'Outros', 'type': 'expense', 'icon': 'more_horiz', 'color_value': 0xFF757575},
      // Receitas
      {'name': 'Salário', 'type': 'income', 'icon': 'work', 'color_value': 0xFF2E7D32},
      {'name': 'Renda Extra', 'type': 'income', 'icon': 'trending_up', 'color_value': 0xFF43A047},
      {'name': 'Investimentos', 'type': 'income', 'icon': 'savings', 'color_value': 0xFF00897B},
      {'name': 'Outros', 'type': 'income', 'icon': 'card_giftcard', 'color_value': 0xFF757575},
    ];
    for (final c in categorias) {
      await db.insert('categories', _carimbar(c));
    }

    // ─── Semente: contas padrão ───
    final contas = <Map<String, Object?>>[
      {'name': 'Carteira', 'type': 'cash', 'initial_balance_cents': 0, 'color_value': 0xFF2E7D32},
      {'name': 'Conta Corrente', 'type': 'bank', 'initial_balance_cents': 0, 'color_value': 0xFF1565C0},
    ];
    for (final a in contas) {
      await db.insert('accounts', _carimbar(a));
    }
  }

  /// Migração para bancos antigos (v1 só gastos; v2 investimentos).
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createInvestTables(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    if (oldVersion < 4) {
      // v4: título próprio do lançamento (ex: "Gabryel").
      await db.execute('ALTER TABLE transactions ADD COLUMN title TEXT');
    }
  }

  /// v3: adiciona as colunas de sincronização e carimba quem já existia.
  Future<void> _migrateToV3(Database db) async {
    for (final t in tabelasSync) {
      await db.execute('ALTER TABLE $t ADD COLUMN sync_id TEXT');
      await db.execute('ALTER TABLE $t ADD COLUMN updated_at TEXT');
      await db.execute(
          'ALTER TABLE $t ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
    }
    await db.execute('ALTER TABLE settings ADD COLUMN updated_at TEXT');

    // Carimba cada registro existente com um sync_id próprio.
    final agora = agoraIso();
    for (final t in tabelasSync) {
      final linhas = await db.query(t, columns: ['id']);
      for (final l in linhas) {
        await db.update(
          t,
          {'sync_id': _uuid.v4(), 'updated_at': agora},
          where: 'id = ?',
          whereArgs: [l['id']],
        );
      }
    }
    for (final t in tabelasSync) {
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_${t}_sync_id ON $t(sync_id)');
    }
  }

  /// Completa um mapa de inserção com os campos de sincronização.
  static Map<String, Object?> _carimbar(Map<String, Object?> m) {
    m['sync_id'] ??= _uuid.v4();
    m['updated_at'] = agoraIso();
    m['deleted'] ??= 0;
    return m;
  }

  Future<void> _createInvestTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS investments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticker TEXT NOT NULL,
        kind TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        avg_price_cents INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dividends(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        ticker TEXT,
        amount_cents INTEGER NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ─── Contas ───
  Future<List<Account>> accounts({bool incluirArquivadas = false}) async {
    final db = await database;
    final rows = await db.query('accounts',
        where: incluirArquivadas
            ? 'deleted = 0'
            : 'archived = 0 AND deleted = 0',
        orderBy: 'name');
    return rows.map(Account.fromMap).toList();
  }

  Future<List<AccountBalance>> accountBalances() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.id, a.name, a.type, a.color_value,
             a.initial_balance_cents
             + COALESCE((SELECT SUM(CASE WHEN t.type = 'income' THEN t.amount_cents
                                         WHEN t.type = 'expense' THEN -t.amount_cents
                                         ELSE -t.amount_cents END)
                         FROM transactions t
                         WHERE t.account_id = a.id AND t.deleted = 0), 0)
             + COALESCE((SELECT SUM(t.amount_cents) FROM transactions t
                         WHERE t.to_account_id = a.id AND t.type = 'transfer'
                           AND t.deleted = 0), 0)
             AS balance_cents
      FROM accounts a
      WHERE a.archived = 0 AND a.deleted = 0
      ORDER BY a.name
    ''');
    return rows.map(AccountBalance.fromMap).toList();
  }

  Future<int> insertAccount(Account a) async {
    final db = await database;
    return db.insert('accounts', _carimbar(a.toMap()));
  }

  Future<int> totalBalance() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(balance_cents), 0) AS total FROM (
        SELECT a.initial_balance_cents
               + COALESCE((SELECT SUM(CASE WHEN t.type = 'income' THEN t.amount_cents
                                           WHEN t.type = 'expense' THEN -t.amount_cents
                                           ELSE -t.amount_cents END)
                           FROM transactions t
                           WHERE t.account_id = a.id AND t.deleted = 0), 0)
               + COALESCE((SELECT SUM(t.amount_cents) FROM transactions t
                           WHERE t.to_account_id = a.id AND t.type = 'transfer'
                             AND t.deleted = 0), 0)
               AS balance_cents
        FROM accounts a WHERE a.archived = 0 AND a.deleted = 0
      )
    ''');
    return ((rows.first['total'] as num?) ?? 0).toInt();
  }

  // ─── Categorias ───
  Future<List<Category>> categories({String? type}) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: type == null
          ? 'archived = 0 AND deleted = 0'
          : 'archived = 0 AND deleted = 0 AND type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'name',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category c) async {
    final db = await database;
    return db.insert('categories', _carimbar(c.toMap()));
  }

  /// Quantos lançamentos ativos usam esta categoria (aviso antes de remover).
  Future<int> transacoesComCategoria(int categoriaId) async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM transactions '
        'WHERE category_id = ? AND deleted = 0',
        [categoriaId]);
    return ((rows.first['n'] as num?) ?? 0).toInt();
  }

  /// Remove a categoria (vira marca `deleted`, viaja na sincronização) e
  /// desvincula os lançamentos ativos dela (eles ficam sem categoria).
  Future<void> deleteCategory(int id) async {
    final db = await database;
    final agora = agoraIso();
    await db.update('transactions', {'category_id': null, 'updated_at': agora},
        where: 'category_id = ? AND deleted = 0', whereArgs: [id]);
    await db.update('categories', {'deleted': 1, 'updated_at': agora},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── Transações ───
  Future<int> insertTransaction(Transaction t) async {
    final db = await database;
    return db.insert('transactions', _carimbar(t.toMap()));
  }

  /// Exclusão vira marca (vai para a nuvem e some da interface).
  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.update('transactions', {'deleted': 1, 'updated_at': agoraIso()},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Busca uma transação pelo id (para editar).
  Future<Transaction?> transactionById(int id) async {
    final db = await database;
    final rows = await db
        .query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Transaction.fromMap(rows.first);
  }

  /// Edita uma transação existente. O carimbo `updated_at` é renovado para a
  /// alteração viajar até os outros aparelhos na sincronização.
  Future<void> updateTransaction(Transaction t) async {
    final db = await database;
    final mapa = t.toMap()
      ..remove('id')
      ..['updated_at'] = agoraIso();
    await db.update('transactions', mapa, where: 'id = ?', whereArgs: [t.id]);
  }

  Future<List<TxView>> transactions({String? month, int limit = 300}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.id, t.type, t.amount_cents, t.date, t.title, t.note,
             a.name AS account_name,
             a2.name AS to_account_name,
             c.name AS category_name, c.icon, c.color_value
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      LEFT JOIN accounts a2 ON a2.id = t.to_account_id
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.deleted = 0 ${month != null ? 'AND t.date LIKE ?' : ''}
      ORDER BY t.date DESC, t.id DESC
      LIMIT ?
    ''', [if (month != null) '$month%', limit]);
    return rows.map(TxView.fromMap).toList();
  }

  // ─── Resumo ───
  Future<Map<String, int>> monthTotals(String month) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT type, COALESCE(SUM(amount_cents), 0) AS total
      FROM transactions
      WHERE date LIKE ? AND type IN ('income', 'expense') AND deleted = 0
      GROUP BY type
    ''', ['$month%']);
    final result = {'income': 0, 'expense': 0};
    for (final r in rows) {
      result[r['type'] as String] = (r['total'] as num).toInt();
    }
    return result;
  }

  Future<List<CategoryTotal>> monthExpensesByCategory(String month) =>
      monthByCategory(month, 'expense');

  /// Totais do mês por categoria, filtrando por tipo ('expense' ou 'income').
  Future<List<CategoryTotal>> monthByCategory(String month, String type) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT c.name, c.icon, c.color_value,
             COALESCE(SUM(t.amount_cents), 0) AS total
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.type = ? AND t.date LIKE ? AND t.deleted = 0
      GROUP BY t.category_id
      ORDER BY total DESC
    ''', [type, '$month%']);
    return rows
        .map((m) => CategoryTotal(
              name: m['name'] as String,
              icon: (m['icon'] as String?) ?? 'more_horiz',
              colorValue: (m['color_value'] as int?) ?? 0xFF757575,
              totalCents: (m['total'] as num).toInt(),
            ))
        .toList();
  }

  // ─── Investimentos ───
  Future<List<Investment>> investments() async {
    final db = await database;
    final rows = await db
        .query('investments', where: 'deleted = 0', orderBy: 'kind, ticker');
    return rows.map(Investment.fromMap).toList();
  }

  Future<int> insertInvestment(Investment inv) async {
    final db = await database;
    return db.insert('investments', _carimbar(inv.toMap()));
  }

  Future<void> updateInvestment(Investment inv) async {
    final db = await database;
    final mapa = inv.toMap()..['updated_at'] = agoraIso();
    await db.update('investments', mapa,
        where: 'id = ?', whereArgs: [inv.id]);
  }

  /// Exclusão vira marca (vai para a nuvem e some da interface).
  Future<void> deleteInvestment(int id) async {
    final db = await database;
    await db.update('investments', {'deleted': 1, 'updated_at': agoraIso()},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── Proventos ───
  Future<List<Dividend>> dividends({int limit = 400}) async {
    final db = await database;
    final rows = await db.query('dividends',
        where: 'deleted = 0', orderBy: 'date DESC, id DESC', limit: limit);
    return rows.map(Dividend.fromMap).toList();
  }

  Future<int> insertDividend(Dividend d) async {
    final db = await database;
    return db.insert('dividends', _carimbar(d.toMap()));
  }

  /// Exclusão vira marca (vai para a nuvem e some da interface).
  Future<void> deleteDividend(int id) async {
    final db = await database;
    await db.update('dividends', {'deleted': 1, 'updated_at': agoraIso()},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Últimos [months] meses com proventos (mais recente primeiro).
  Future<List<MonthTotal>> dividendsByMonth({int months = 24}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT substr(date, 1, 7) AS m, COALESCE(SUM(amount_cents), 0) AS total
      FROM dividends
      WHERE deleted = 0
      GROUP BY m
      ORDER BY m DESC
      LIMIT ?
    ''', [months]);
    return rows
        .map((r) => MonthTotal(
              month: r['m'] as String,
              totalCents: (r['total'] as num).toInt(),
            ))
        .toList();
  }

  // ─── Configurações (key-value) ───
  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value, {String? updatedAt}) async {
    final db = await database;
    await db.insert(
        'settings',
        {'key': key, 'value': value, 'updated_at': updatedAt ?? agoraIso()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Linha completa de uma configuração (com carimbo de tempo).
  Future<Map<String, Object?>?> settingRow(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first;
  }

  // ─── Suporte à sincronização (usado por sync.dart) ───
  Future<List<Map<String, Object?>>> rawAll(String tabela) async {
    final db = await database;
    return db.query(tabela);
  }

  Future<int> rawInsert(String tabela, Map<String, Object?> valores) async {
    final db = await database;
    return db.insert(tabela, valores);
  }

  Future<void> rawUpdate(
      String tabela, int id, Map<String, Object?> valores) async {
    final db = await database;
    await db.update(tabela, valores, where: 'id = ?', whereArgs: [id]);
  }

  /// Instalação nova (só com as sementes, nada digitado ainda)? Usado na
  /// primeira sincronização de um aparelho novo: limpa as sementes locais
  /// para a nuvem trazer tudo sem duplicar.
  Future<bool> pareceInstalacaoNova() async {
    final db = await database;
    if (await getSetting('sync_initialized') != null) return false;
    Future<int> contar(String t) async {
      final r = await db.rawQuery('SELECT COUNT(*) AS n FROM $t');
      return ((r.first['n'] as num?) ?? 0).toInt();
    }

    final tx = await contar('transactions');
    final inv = await contar('investments');
    final div = await contar('dividends');
    final acc = await contar('accounts');
    final cat = await contar('categories');
    return tx == 0 && inv == 0 && div == 0 && acc <= 2 && cat <= 13;
  }

  /// Remove as sementes de uma instalação nova (ver [pareceInstalacaoNova]).
  Future<void> limparDadosDeSemente() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('investments');
    await db.delete('dividends');
    await db.delete('accounts');
    await db.delete('categories');
  }
}
