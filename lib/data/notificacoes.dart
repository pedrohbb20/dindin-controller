import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Notificações locais: lembretes dos vencimentos das contas previstas.
/// Funciona no Android e no Linux; qualquer erro é silencioso para nunca
/// atrapalhar o app.
class Notificacoes {
  Notificacoes._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _pronto = false;

  static Future<void> iniciar() async {
    if (_pronto) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const linux = LinuxInitializationSettings(defaultActionName: 'Abrir');
      const config = InitializationSettings(android: android, linux: linux);
      await _plugin.initialize(settings: config);
      _pronto = true;
    } catch (_) {
      // Sem suporte a notificações: o app segue funcionando normalmente.
    }
  }

  static Future<void> pedirPermissao() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  static const NotificationDetails _detalhes = NotificationDetails(
    android: AndroidNotificationDetails(
      'dindin_vencimentos',
      'Vencimentos',
      channelDescription: 'Lembretes das contas previstas do Dindin',
      importance: Importance.high,
      priority: Priority.high,
    ),
    linux: LinuxNotificationDetails(),
  );

  static const NotificationDetails _detalhesAtualizacao = NotificationDetails(
    android: AndroidNotificationDetails(
      'dindin_atualizacoes',
      'Atualizações do app',
      channelDescription: 'Aviso quando sai uma versão nova do Dindin',
      importance: Importance.high,
      priority: Priority.high,
    ),
    linux: LinuxNotificationDetails(),
  );

  /// Avisa (uma vez por versão) que saiu uma versão nova do app.
  static Future<void> mostrarAtualizacao(String versao) async {
    if (!_pronto) await iniciar();
    if (!_pronto) return;
    try {
      await _plugin.show(
        id: 2,
        title: 'Nova versão do Dindin: $versao',
        body: 'Abra o app para ver o link de download no Resumo.',
        notificationDetails: _detalhesAtualizacao,
      );
    } catch (_) {}
  }

  /// Cancela e reagenda os lembretes: às 9h do dia de cada vencimento
  /// (as 4 próximas ocorrências de cada conta).
  static Future<void> programarVencimentos(List<ContaPrevista> contas) async {
    if (!_pronto) await iniciar();
    if (!_pronto) return;
    try {
      for (var id = 100; id < 200; id++) {
        await _plugin.cancel(id: id);
      }
      var id = 100;
      for (final c in contas) {
        var base = DateTime.now();
        for (var k = 0; k < 4 && id < 200; k++) {
          final dia = c.proximaData(base);
          final quando = DateTime(dia.year, dia.month, dia.day, 9);
          if (quando.isAfter(DateTime.now())) {
            await _plugin.zonedSchedule(
              id: id++,
              title: 'Vence hoje: ${c.nome}',
              body: c.valorCents > 0
                  ? 'Valor previsto: ${formatCents(c.valorCents)}'
                  : 'Conta prevista no Dindin',
              scheduledDate: tz.TZDateTime.from(quando, tz.local),
              notificationDetails: _detalhes,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          }
          base = DateTime(dia.year, dia.month, dia.day + 1);
        }
      }
    } catch (_) {
      // Agendamento indisponível nesta plataforma: ignora.
    }
  }

  /// Dispara uma notificação imediata (botão "Testar notificação").
  static Future<void> testar() async {
    if (!_pronto) await iniciar();
    if (!_pronto) return;
    try {
      await _plugin.show(
        id: 1,
        title: 'Dindin Controller',
        body:
            'Notificações funcionando! Você será lembrado das contas previstas. 🎉',
        notificationDetails: _detalhes,
      );
    } catch (_) {}
  }
}
