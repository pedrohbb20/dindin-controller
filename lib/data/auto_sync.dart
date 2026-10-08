import 'dart:async';

import 'package:flutter/widgets.dart';

import 'database.dart';
import 'sync.dart';

/// Sincronização automática com a nuvem: tenta ao abrir o app, de hora em
/// hora (enquanto ele está aberto) e ao voltar para ele depois de um tempo.
/// Só age se a nuvem estiver configurada, logada e a opção estiver ligada
/// em Ajustes; qualquer falha é ignorada (o app segue funcionando offline).
class AutoSync {
  AutoSync._();

  static Timer? _relogio;
  static DateTime? ultima;
  static bool _emAndamento = false;

  /// Liga o relógio da sincronização (chamar uma vez, na abertura do app).
  static void iniciar() {
    WidgetsBinding.instance.addObserver(_Ciclo());
    Timer(const Duration(seconds: 8), tentarAgora);
    _relogio?.cancel();
    _relogio = Timer.periodic(const Duration(hours: 1), (_) => tentarAgora());
  }

  /// Tenta sincronizar agora (respeita a opção de Ajustes e o estado da nuvem).
  static Future<void> tentarAgora() async {
    if (_emAndamento) return;
    if (!Sync.configurado || !Sync.logado) return;
    try {
      final opcao = await Db.i.getSetting('auto_sync_on');
      if (opcao == '0') return;
    } catch (_) {
      return; // sem banco ainda: não sincroniza agora
    }
    _emAndamento = true;
    try {
      await Sync.silencioso();
      ultima = DateTime.now();
    } catch (_) {
      // sem internet ou nuvem fora: tenta de novo no próximo ciclo
    } finally {
      _emAndamento = false;
    }
  }

  /// Chamado ao voltar para o app: sincroniza se passou um tempinho.
  static void aoVoltar() {
    final u = ultima;
    if (u == null ||
        DateTime.now().difference(u) > const Duration(minutes: 30)) {
      tentarAgora();
    }
  }
}

class _Ciclo extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) AutoSync.aoVoltar();
  }
}
