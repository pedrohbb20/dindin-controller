// Testes de unidade do Dindin Controller.
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin_controller/data/models.dart';

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
}
