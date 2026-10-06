import 'package:intl/intl.dart';

/// ─── Formatação (pt-BR) ───────────────────────────────────────────────
final NumberFormat moedaFmt =
    NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);
final DateFormat mesAnoFmt = DateFormat('MMMM yyyy', 'pt_BR');
final DateFormat dataCurtaFmt = DateFormat('dd/MM/yyyy');

String formatCents(int cents) => moedaFmt.format(cents / 100);

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String mesPrefixo(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Converte texto digitado ("25,90", "1.234,56", "25.90") em centavos.
int? parseAmountToCents(String input) {
  var t = input.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  final v = double.tryParse(t);
  if (v == null || v <= 0) return null;
  return (v * 100).round();
}

/// ─── Modelos ───────────────────────────────────────────────────────────
class Account {
  final int? id;
  final String name;
  final String type; // cash | bank | savings | credit
  final int initialBalanceCents;
  final int colorValue;
  final bool archived;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.initialBalanceCents = 0,
    this.colorValue = 0xFF607D8B,
    this.archived = false,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'initial_balance_cents': initialBalanceCents,
        'color_value': colorValue,
        'archived': archived ? 1 : 0,
      };

  static Account fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String,
        initialBalanceCents: (m['initial_balance_cents'] as int?) ?? 0,
        colorValue: (m['color_value'] as int?) ?? 0xFF607D8B,
        archived: ((m['archived'] as int?) ?? 0) == 1,
      );

  String get typeLabel => switch (type) {
        'cash' => 'Carteira',
        'bank' => 'Conta bancária',
        'savings' => 'Poupança',
        'credit' => 'Crédito',
        _ => 'Outro',
      };
}

class AccountBalance {
  final int id;
  final String name;
  final String type;
  final int colorValue;
  final int balanceCents;

  const AccountBalance({
    required this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    required this.balanceCents,
  });

  static AccountBalance fromMap(Map<String, Object?> m) => AccountBalance(
        id: m['id'] as int,
        name: m['name'] as String,
        type: m['type'] as String,
        colorValue: (m['color_value'] as int?) ?? 0xFF607D8B,
        balanceCents: ((m['balance_cents'] as num?) ?? 0).toInt(),
      );

  String get typeLabel => switch (type) {
        'cash' => 'Carteira',
        'bank' => 'Conta bancária',
        'savings' => 'Poupança',
        'credit' => 'Crédito',
        _ => 'Outro',
      };
}

class Category {
  final int? id;
  final String name;
  final String type; // income | expense
  final String icon; // nome do ícone (ver icons.dart)
  final int colorValue;
  final bool archived;

  const Category({
    this.id,
    required this.name,
    required this.type,
    this.icon = 'more_horiz',
    this.colorValue = 0xFF757575,
    this.archived = false,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color_value': colorValue,
        'archived': archived ? 1 : 0,
      };

  static Category fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String,
        icon: (m['icon'] as String?) ?? 'more_horiz',
        colorValue: (m['color_value'] as int?) ?? 0xFF757575,
        archived: ((m['archived'] as int?) ?? 0) == 1,
      );
}

class Transaction {
  final int? id;
  final String type; // income | expense | transfer
  final int amountCents;
  final String date; // YYYY-MM-DD
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final String? note;

  const Transaction({
    this.id,
    required this.type,
    required this.amountCents,
    required this.date,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.note,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'amount_cents': amountCents,
        'date': date,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'category_id': categoryId,
        'note': note,
      };

  static Transaction fromMap(Map<String, Object?> m) => Transaction(
        id: m['id'] as int?,
        type: m['type'] as String,
        amountCents: (m['amount_cents'] as int?) ?? 0,
        date: m['date'] as String,
        accountId: m['account_id'] as int,
        toAccountId: m['to_account_id'] as int?,
        categoryId: m['category_id'] as int?,
        note: m['note'] as String?,
      );
}

/// Transação "achatada" com nomes resolvidos (para listagens).
class TxView {
  final int id;
  final String type;
  final int amountCents;
  final String date;
  final String accountName;
  final String? toAccountName;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final String? note;

  const TxView({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.date,
    required this.accountName,
    this.toAccountName,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.note,
  });

  static TxView fromMap(Map<String, Object?> m) => TxView(
        id: m['id'] as int,
        type: m['type'] as String,
        amountCents: (m['amount_cents'] as int?) ?? 0,
        date: m['date'] as String,
        accountName: (m['account_name'] as String?) ?? '',
        toAccountName: m['to_account_name'] as String?,
        categoryName: m['category_name'] as String?,
        categoryIcon: m['icon'] as String?,
        categoryColor: m['color_value'] as int?,
        note: m['note'] as String?,
      );
}

class CategoryTotal {
  final String name;
  final String icon;
  final int colorValue;
  final int totalCents;

  const CategoryTotal({
    required this.name,
    required this.icon,
    required this.colorValue,
    required this.totalCents,
  });
}
