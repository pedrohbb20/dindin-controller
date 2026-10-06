import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import 'models.dart';

/// Banco de dados local do Dindin Controller (SQLite).
class Db {
  Db._();
  static final Db i = Db._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'dindin.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
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
        note TEXT
      )
    ''');

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
      await db.insert('categories', c);
    }

    // ─── Semente: contas padrão ───
    final contas = <Map<String, Object?>>[
      {'name': 'Carteira', 'type': 'cash', 'initial_balance_cents': 0, 'color_value': 0xFF2E7D32},
      {'name': 'Conta Corrente', 'type': 'bank', 'initial_balance_cents': 0, 'color_value': 0xFF1565C0},
    ];
    for (final a in contas) {
      await db.insert('accounts', a);
    }
  }

  // ─── Contas ───
  Future<List<Account>> accounts() async {
    final db = await database;
    final rows = await db.query('accounts', where: 'archived = 0', orderBy: 'name');
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
                         FROM transactions t WHERE t.account_id = a.id), 0)
             + COALESCE((SELECT SUM(t.amount_cents) FROM transactions t
                         WHERE t.to_account_id = a.id AND t.type = 'transfer'), 0)
             AS balance_cents
      FROM accounts a
      WHERE a.archived = 0
      ORDER BY a.name
    ''');
    return rows.map(AccountBalance.fromMap).toList();
  }

  Future<int> insertAccount(Account a) async {
    final db = await database;
    return db.insert('accounts', a.toMap());
  }

  Future<int> totalBalance() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(balance_cents), 0) AS total FROM (
        SELECT a.initial_balance_cents
               + COALESCE((SELECT SUM(CASE WHEN t.type = 'income' THEN t.amount_cents
                                           WHEN t.type = 'expense' THEN -t.amount_cents
                                           ELSE -t.amount_cents END)
                           FROM transactions t WHERE t.account_id = a.id), 0)
               + COALESCE((SELECT SUM(t.amount_cents) FROM transactions t
                           WHERE t.to_account_id = a.id AND t.type = 'transfer'), 0)
               AS balance_cents
        FROM accounts a WHERE a.archived = 0
      )
    ''');
    return ((rows.first['total'] as num?) ?? 0).toInt();
  }

  // ─── Categorias ───
  Future<List<Category>> categories({String? type}) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: type == null ? 'archived = 0' : 'archived = 0 AND type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'name',
    );
    return rows.map(Category.fromMap).toList();
  }

  // ─── Transações ───
  Future<int> insertTransaction(Transaction t) async {
    final db = await database;
    return db.insert('transactions', t.toMap());
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TxView>> transactions({String? month, int limit = 300}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.id, t.type, t.amount_cents, t.date, t.note,
             a.name AS account_name,
             a2.name AS to_account_name,
             c.name AS category_name, c.icon, c.color_value
      FROM transactions t
      JOIN accounts a ON a.id = t.account_id
      LEFT JOIN accounts a2 ON a2.id = t.to_account_id
      LEFT JOIN categories c ON c.id = t.category_id
      ${month != null ? 'WHERE t.date LIKE ?' : ''}
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
      WHERE date LIKE ? AND type IN ('income', 'expense')
      GROUP BY type
    ''', ['$month%']);
    final result = {'income': 0, 'expense': 0};
    for (final r in rows) {
      result[r['type'] as String] = (r['total'] as num).toInt();
    }
    return result;
  }

  Future<List<CategoryTotal>> monthExpensesByCategory(String month) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT c.name, c.icon, c.color_value,
             COALESCE(SUM(t.amount_cents), 0) AS total
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.type = 'expense' AND t.date LIKE ?
      GROUP BY t.category_id
      ORDER BY total DESC
    ''', ['$month%']);
    return rows
        .map((m) => CategoryTotal(
              name: m['name'] as String,
              icon: (m['icon'] as String?) ?? 'more_horiz',
              colorValue: (m['color_value'] as int?) ?? 0xFF757575,
              totalCents: (m['total'] as num).toInt(),
            ))
        .toList();
  }
}
