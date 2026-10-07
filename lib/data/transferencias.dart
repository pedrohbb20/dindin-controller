import 'dart:convert';

import 'models.dart';

/// Um par sugerido: uma saída e uma entrada de mesmo valor, em contas
/// diferentes, que provavelmente são a MESMA transferência entre as contas
/// do usuário (o dinheiro saiu de uma conta e entrou na outra).
class ParTransferencia {
  final Transaction saida; // expense (dinheiro saiu da conta de origem)
  final Transaction entrada; // income (dinheiro entrou na conta de destino)

  const ParTransferencia({required this.saida, required this.entrada});

  /// Chave estável do par (usada na lista local de "não é transferência").
  String get chave => '${saida.id}:${entrada.id}';
}

/// Procura pares candidatos de transferência entre as contas:
/// - mesmo valor (centavos exatos);
/// - um lançamento de saída e um de entrada;
/// - contas diferentes;
/// - datas com diferença de até [maxDias];
/// - cada lançamento casa no máximo uma vez (casamento guloso, do mais
///   recente para o mais antigo, sempre pelo par de menor diferença de datas).
List<ParTransferencia> encontrarParesTransferencia(
  List<Transaction> lancamentos, {
  Set<String> ignoradas = const {},
  int maxDias = 2,
}) {
  final saidas = lancamentos
      .where((t) => t.type == 'expense' && t.id != null)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final entradas =
      lancamentos.where((t) => t.type == 'income' && t.id != null).toList();
  final usadas = <int>{};
  final pares = <ParTransferencia>[];
  for (final s in saidas) {
    Transaction? melhor;
    var melhorDist = maxDias + 1;
    for (final e in entradas) {
      if (usadas.contains(e.id) || e.amountCents != s.amountCents) continue;
      if (e.accountId == s.accountId) continue;
      if (ignoradas.contains('${s.id}:${e.id}')) continue;
      final dist = _diferencaEmDias(s.date, e.date);
      if (dist > maxDias || dist >= melhorDist) continue;
      melhor = e;
      melhorDist = dist;
    }
    if (melhor != null) {
      usadas.add(melhor.id!);
      pares.add(ParTransferencia(saida: s, entrada: melhor));
    }
  }
  return pares;
}

int _diferencaEmDias(String a, String b) {
  final da = DateTime.tryParse(a);
  final db = DateTime.tryParse(b);
  if (da == null || db == null) return 9999;
  return da.difference(db).inDays.abs();
}

/// Lê a lista local de pares respondidos com "não é transferência"
/// (tolerante a nulo, vazio ou lixo).
Set<String> decodeParesIgnorados(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final v = jsonDecode(json);
    if (v is List) return v.whereType<String>().toSet();
  } catch (_) {}
  return {};
}

String encodeParesIgnorados(Set<String> chaves) => jsonEncode(chaves.toList());
