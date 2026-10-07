import 'package:flutter/material.dart';

import 'database.dart';

/// Controlador global do tema do app (claro/escuro), persistido no banco.
///
/// O padrão é o modo ESCURO (preferência do Mestre). O usuário pode alternar
/// pelo botão na barra de título; a escolha é salva em `settings.tema`.
class Tema {
  Tema._();

  static final ValueNotifier<ThemeMode> notifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);
  static bool _carregado = false;

  /// Carrega a preferência salva (padrão: escuro).
  static Future<void> carregar() async {
    if (_carregado) return;
    try {
      final salvo = await Db.i.getSetting('tema');
      notifier.value = salvo == 'claro' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      // Banco indisponível no boot: mantém o padrão (escuro).
    }
    _carregado = true;
  }

  /// Alterna claro/escuro e salva a escolha.
  static Future<void> alternar() async {
    notifier.value =
        notifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      await Db.i.setSetting(
          'tema', notifier.value == ThemeMode.dark ? 'escuro' : 'claro');
    } catch (_) {
      // Sem banco: o tema muda só nesta sessão.
    }
  }

  static ThemeData claro() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      );

  static ThemeData escuro() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
      );
}

/// Paleta dos gráficos por categoria (valores ARGB, como salvos no banco).
const List<int> paletaCoresInt = [
  0xFF66BB6A, // verde
  0xFF42A5F5, // azul
  0xFFEF5350, // vermelho
  0xFFFFA726, // laranja
  0xFFAB47BC, // roxo
  0xFF26C6DA, // ciano
  0xFFEC407A, // rosa
  0xFF8D6E63, // marrom
  0xFF9CCC65, // verde-limão
  0xFF5C6BC0, // índigo
  0xFFFFCA28, // amarelo
  0xFF78909C, // cinza-azulado
];

/// A mesma paleta como cores prontas para pintar (contrasta nos dois temas).
final List<Color> paletaGraficos = [
  for (final v in paletaCoresInt) Color(v),
];
