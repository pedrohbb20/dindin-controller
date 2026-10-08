// Testes de unidade do Dindin Controller.
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin_controller/data/atualizacoes.dart';
import 'package:dindin_controller/data/models.dart';
import 'package:dindin_controller/data/transferencias.dart';

void main() {
  group('parseAmountToCents', () {
    test('aceita vírgula decimal (25,90)', () {
      expect(parseAmountToCents('25,90'), 2590);
    });

    test('aceita separador de milhar (1.234,56)', () {
      expect(parseAmountToCents('1.234,56'), 123456);
    });

    test('aceita ponto decimal (25.90)', () {
      expect(parseAmountToCents('25.90'), 2590);
    });

    test('rejeita texto, vazio, zero e negativo', () {
      expect(parseAmountToCents('abc'), isNull);
      expect(parseAmountToCents(''), isNull);
      expect(parseAmountToCents('0'), isNull);
      expect(parseAmountToCents('-5'), isNull);
    });
  });

  group('formatCents', () {
    test('formata centavos como Real', () {
      expect(formatCents(123456), contains('1.234,56'));
      expect(formatCents(0), contains('0,00'));
    });
  });

  group('toIsoDate / mesPrefixo', () {
    test('gera data ISO com zero à esquerda', () {
      expect(toIsoDate(DateTime(2026, 10, 6)), '2026-10-06');
    });

    test('gera prefixo de mês', () {
      expect(mesPrefixo(DateTime(2026, 10, 6)), '2026-10');
    });
  });

  group('centsParaInput', () {
    test('formata centavos para o campo de edição', () {
      expect(centsParaInput(2590), '25,90');
      expect(centsParaInput(100000), '1000,00');
      expect(centsParaInput(5), '0,05');
    });
  });

  group('Transaction.title', () {
    test('guarda e lê o título próprio do lançamento', () {
      final t = Transaction(
        type: 'expense',
        amountCents: 500,
        date: '2026-10-06',
        accountId: 1,
        title: 'Gabryel',
      );
      expect(t.toMap()['title'], 'Gabryel');
      final lido = Transaction.fromMap({
        'id': 1,
        'type': 'expense',
        'amount_cents': 500,
        'date': '2026-10-06',
        'account_id': 1,
        'title': 'Gabryel',
      });
      expect(lido.title, 'Gabryel');
    });
  });

  group('metas de orçamento (JSON em settings)', () {
    test('ida e volta preserva os limites', () {
      final metas = {'sync-a': 50000, 'sync-b': 25000};
      expect(decodeMetasJson(encodeMetasJson(metas)), metas);
    });

    test('tolerante a nulo, vazio e lixo', () {
      expect(decodeMetasJson(null), isEmpty);
      expect(decodeMetasJson(''), isEmpty);
      expect(decodeMetasJson('{quebrado'), isEmpty);
      expect(decodeMetasJson('[1,2,3]'), isEmpty);
    });

    test('ignora valores inválidos e converte números', () {
      expect(decodeMetasJson('{"a": 1500, "b": "x", "c": -3, "d": 0}'),
          {'a': 1500});
      expect(decodeMetasJson('{"a": 15.0}'), {'a': 15});
    });
  });

  group('pares de transferência entre contas', () {
    Transaction tx(int id, String type, int cents, String date, int acc) =>
        Transaction(
            id: id,
            type: type,
            amountCents: cents,
            date: date,
            accountId: acc);

    test('casa saída e entrada de mesmo valor em contas diferentes', () {
      final pares = encontrarParesTransferencia([
        tx(1, 'expense', 9300, '2026-10-06', 5),
        tx(2, 'income', 9300, '2026-10-06', 3),
      ]);
      expect(pares.length, 1);
      expect(pares.first.saida.id, 1);
      expect(pares.first.entrada.id, 2);
      expect(pares.first.chave, '1:2');
    });

    test('não casa mesma conta nem valores diferentes', () {
      final pares = encontrarParesTransferencia([
        tx(1, 'expense', 9300, '2026-10-06', 5),
        tx(2, 'income', 9300, '2026-10-06', 5),
        tx(3, 'income', 5000, '2026-10-05', 3),
      ]);
      expect(pares, isEmpty);
    });

    test('respeita a janela de dias (padrão: 2)', () {
      expect(
          encontrarParesTransferencia([
            tx(1, 'expense', 9300, '2026-10-06', 5),
            tx(2, 'income', 9300, '2026-10-03', 3),
          ]),
          isEmpty);
      expect(
          encontrarParesTransferencia([
            tx(1, 'expense', 9300, '2026-10-06', 5),
            tx(2, 'income', 9300, '2026-10-04', 3),
          ]).length,
          1);
    });

    test('ignora pares marcados como "não é transferência"', () {
      expect(
          encontrarParesTransferencia([
            tx(1, 'expense', 9300, '2026-10-06', 5),
            tx(2, 'income', 9300, '2026-10-06', 3),
          ], ignoradas: {'1:2'}),
          isEmpty);
    });

    test('cada lançamento casa no máximo uma vez', () {
      final pares = encontrarParesTransferencia([
        tx(1, 'expense', 9300, '2026-10-06', 5),
        tx(2, 'expense', 9300, '2026-10-04', 6),
        tx(3, 'income', 9300, '2026-10-05', 3),
      ]);
      expect(pares.length, 1);
    });

    test('lista de ignorados tolerante a nulo, lixo e ida e volta', () {
      expect(decodeParesIgnorados(null), isEmpty);
      expect(decodeParesIgnorados('nada'), isEmpty);
      expect(decodeParesIgnorados('["1:2","3:4"]'), {'1:2', '3:4'});
      expect(encodeParesIgnorados({'1:2'}), '["1:2"]');
    });
  });

  group('atualizações do app', () {
    test('compara versões com v, sem v e com pedaços faltando', () {
      expect(Atualizacoes.ehMaisNova('v1.7.2', '1.7.1'), isTrue);
      expect(Atualizacoes.ehMaisNova('1.7.1', 'v1.7.2'), isFalse);
      expect(Atualizacoes.ehMaisNova('v1.7.1', '1.7.1'), isFalse);
      expect(Atualizacoes.ehMaisNova('v1.7', '1.7.0'), isFalse);
      expect(Atualizacoes.ehMaisNova('v1.10.0', '1.9.9'), isTrue);
      expect(Atualizacoes.ehMaisNova('v2.0.0', '1.99.99'), isTrue);
      expect(Atualizacoes.ehMaisNova('v1.7.2', '1.7.2'), isFalse);
    });
  });
}
