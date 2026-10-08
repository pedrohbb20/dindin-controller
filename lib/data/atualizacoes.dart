import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'database.dart';
import 'notificacoes.dart';

/// Verificação de atualização do app: consulta a última release no GitHub
/// (repositório público) e guarda a novidade no banco local. O Resumo mostra
/// um cartão com o botão Baixar (link direto do arquivo) e uma notificação
/// local avisa uma vez por versão.
class Atualizacoes {
  Atualizacoes._();

  static const _repo = 'pedrohbb20/dindin-controller';
  static DateTime? _ultimaChecagem;

  /// Compara versões tipo "v1.7.2" com "1.7.1". Devolve true se [tag] for
  /// mais nova que [atual] (tolerante a "v", sufixos e pedaços faltando).
  static bool ehMaisNova(String tag, String atual) {
    List<int> parse(String s) => s
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .split('.')
        .where((p) => p.isNotEmpty)
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final a = parse(tag);
    final b = parse(atual);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Consulta a última release (no máximo a cada 30 minutos) e atualiza o
  /// aviso guardado no banco. Falhas são silenciosas: sem internet vale o
  /// último estado conhecido.
  static Future<void> verificar({bool forcar = false}) async {
    if (!forcar &&
        _ultimaChecagem != null &&
        DateTime.now().difference(_ultimaChecagem!) <
            const Duration(minutes: 30)) {
      return;
    }
    _ultimaChecagem = DateTime.now();
    try {
      final info = await PackageInfo.fromPlatform();
      final versaoAtual = info.version; // ex.: "1.7.2"
      final json = await _buscarUltimaRelease();
      if (json == null) return;
      final tag = (json['tag_name'] as String?) ?? '';
      final assets = (json['assets'] as List?) ?? const [];
      String? urlApk;
      for (final a in assets) {
        if (a is! Map) continue;
        final nome = a['name']?.toString() ?? '';
        if (nome.endsWith('.apk')) {
          urlApk = a['browser_download_url']?.toString();
          break;
        }
      }
      final url = urlApk ?? (json['html_url'] as String?) ?? '';
      if (tag.isEmpty || url.isEmpty) return;
      if (ehMaisNova(tag, versaoAtual)) {
        final jaVisto = await Db.i.getSetting('app_update_tag') ?? '';
        await Db.i.setSetting('app_update_tag', tag);
        await Db.i.setSetting('app_update_url', url);
        if (jaVisto != tag) {
          await Notificacoes.mostrarAtualizacao(tag);
        }
      } else {
        // Já estamos na mais nova: limpa o aviso só quando a versão
        // guardada também já foi alcançada (sem internet, nada muda).
        final guardada = await Db.i.getSetting('app_update_tag') ?? '';
        if (guardada.isNotEmpty && !ehMaisNova(guardada, versaoAtual)) {
          await Db.i.setSetting('app_update_tag', '');
          await Db.i.setSetting('app_update_url', '');
        }
      }
    } catch (_) {
      // sem internet ou GitHub fora do ar: tenta de novo mais tarde
    }
  }

  static Future<Map<String, dynamic>?> _buscarUltimaRelease() async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await cliente.getUrl(
          Uri.parse('https://api.github.com/repos/$_repo/releases/latest'));
      req.headers.set('User-Agent', 'dindin-controller');
      req.headers.set('Accept', 'application/vnd.github+json');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final corpo = await resp.transform(utf8.decoder).join();
      return jsonDecode(corpo) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      cliente.close(force: true);
    }
  }
}
