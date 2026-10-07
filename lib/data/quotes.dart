import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Cotação de mercado de um ativo (fonte: Yahoo Finance).
class Quote {
  const Quote({required this.ticker, required this.price, this.changePct});

  final String ticker;
  final double price;

  /// Variação do dia em % (quando disponível).
  final double? changePct;
}

/// Busca cotações atuais dos tickers da B3 no Yahoo Finance.
///
/// Usa apenas `dart:io` (sem dependências externas). Falhas individuais
/// (rede, ticker inexistente) são silenciosamente ignoradas — o app
/// continua funcionando offline, apenas sem a cotação daquele ativo.
class QuotesService {
  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/151.0.0.0 Safari/537.36';

  static Future<Map<String, Quote>> buscar(List<String> tickers) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final resultado = <String, Quote>{};

    Future<void> buscarUm(String ticker) async {
      try {
        final url = Uri.parse('https://query1.finance.yahoo.com/v8/finance/'
            'chart/$ticker.SA?range=1d&interval=1d');
        final req =
            await client.getUrl(url).timeout(const Duration(seconds: 8));
        req.headers.set('User-Agent', _userAgent);
        final resp = await req.close().timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return;
        final corpo = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(corpo) as Map<String, dynamic>;
        final chart = json['chart'] as Map<String, dynamic>?;
        final lista = chart?['result'] as List<dynamic>?;
        if (lista == null || lista.isEmpty) return;
        final meta =
            (lista.first as Map<String, dynamic>)['meta'] as Map<String, dynamic>?;
        if (meta == null) return;
        final preco = (meta['regularMarketPrice'] as num?)?.toDouble();
        if (preco == null || preco <= 0) return;
        final anterior = (meta['chartPreviousClose'] as num?)?.toDouble() ??
            (meta['previousClose'] as num?)?.toDouble();
        double? variacao;
        if (anterior != null && anterior > 0) {
          variacao = (preco - anterior) / anterior * 100;
        }
        resultado[ticker] =
            Quote(ticker: ticker, price: preco, changePct: variacao);
      } catch (_) {
        // sem internet / ticker inválido: segue sem a cotação.
      }
    }

    await Future.wait(tickers.map(buscarUm));
    client.close(force: true);
    return resultado;
  }

  /// Soma dos dividendos pagos por cota nos últimos 12 meses (Yahoo).
  /// Retorna ticker → soma em reais (ex.: 1.1278 = R$ 1,1278 por cota).
  /// Falhas individuais são ignoradas.
  static Future<Map<String, double>> dividendos12m(
      List<String> tickers) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final resultado = <String, double>{};
    final corte = DateTime.now()
            .subtract(const Duration(days: 365))
            .millisecondsSinceEpoch ~/
        1000;

    Future<void> buscarUm(String ticker) async {
      try {
        final url = Uri.parse('https://query1.finance.yahoo.com/v8/finance/'
            'chart/$ticker.SA?range=2y&interval=1mo&events=div');
        final req =
            await client.getUrl(url).timeout(const Duration(seconds: 8));
        req.headers.set('User-Agent', _userAgent);
        final resp = await req.close().timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return;
        final corpo = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(corpo) as Map<String, dynamic>;
        final chart = json['chart'] as Map<String, dynamic>?;
        final lista = chart?['result'] as List<dynamic>?;
        if (lista == null || lista.isEmpty) return;
        final eventos = ((lista.first as Map<String, dynamic>)['events']
            as Map<String, dynamic>?)?['dividends'] as Map<String, dynamic>?;
        if (eventos == null) return;
        var soma = 0.0;
        for (final e in eventos.values) {
          final mapa = e as Map<String, dynamic>;
          final ts = (mapa['date'] as num?)?.toInt() ?? 0;
          final valor = (mapa['amount'] as num?)?.toDouble() ?? 0;
          if (ts >= corte && valor > 0) soma += valor;
        }
        if (soma > 0) resultado[ticker] = soma;
      } catch (_) {
        // sem internet / sem dividendos: segue sem este ticker.
      }
    }

    await Future.wait(tickers.map(buscarUm));
    client.close(force: true);
    return resultado;
  }
}
