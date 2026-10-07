import 'package:flutter/material.dart';

import 'database.dart';

/// Controlador global do tema do app (modo claro/escuro/sistema e cores),
/// persistido no banco (`settings.tema`, `settings.tema_cor_primaria` e
/// `settings.tema_cor_secundaria`).
///
/// O padrão é o modo ESCURO com o verde original (preferência do Mestre).
class Tema {
  Tema._();

  static final ValueNotifier<ThemeMode> notifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Cor principal (semente dos tons do app).
  static final ValueNotifier<int> corPrimaria =
      ValueNotifier<int>(0xFF2E7D32);

  /// Cor de destaque; null = deixar o Material derivar da principal.
  static final ValueNotifier<int?> corSecundaria = ValueNotifier<int?>(null);

  /// Escuta qualquer mudança do tema (modo ou cores).
  static Listenable get tudo =>
      Listenable.merge([notifier, corPrimaria, corSecundaria]);

  static bool _carregado = false;

  /// Carrega as preferências salvas (padrão: escuro + verde).
  static Future<void> carregar() async {
    if (_carregado) return;
    try {
      final modo = await Db.i.getSetting('tema');
      notifier.value = switch (modo) {
        'claro' => ThemeMode.light,
        'sistema' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
      final primaria =
          int.tryParse(await Db.i.getSetting('tema_cor_primaria') ?? '');
      if (primaria != null) corPrimaria.value = primaria;
      final secundaria =
          int.tryParse(await Db.i.getSetting('tema_cor_secundaria') ?? '');
      corSecundaria.value = secundaria;
    } catch (_) {
      // Banco indisponível no boot: mantém os padrões.
    }
    _carregado = true;
  }

  static Future<void> definirModo(ThemeMode modo) async {
    notifier.value = modo;
    try {
      await Db.i.setSetting('tema', switch (modo) {
        ThemeMode.light => 'claro',
        ThemeMode.system => 'sistema',
        ThemeMode.dark => 'escuro',
      });
    } catch (_) {
      // Sem banco: a mudança vale só nesta sessão.
    }
  }

  static Future<void> definirCores(int primaria, int? secundaria) async {
    corPrimaria.value = primaria;
    corSecundaria.value = secundaria;
    try {
      await Db.i.setSetting('tema_cor_primaria', primaria.toString());
      await Db.i.setSetting('tema_cor_secundaria',
          secundaria == null ? '' : secundaria.toString());
    } catch (_) {
      // Sem banco: a mudança vale só nesta sessão.
    }
  }

  /// Alterna claro/escuro pelo botão rápido da barra de título.
  static Future<void> alternar() async {
    await definirModo(
        notifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  static ColorScheme _esquema(Brightness brilho) {
    final base = ColorScheme.fromSeed(
      seedColor: Color(corPrimaria.value),
      brightness: brilho,
    );
    final destaque = corSecundaria.value;
    if (destaque == null) return base;
    final cor = Color(destaque);
    return base.copyWith(
      secondary: cor,
      onSecondary: contraste(cor),
      secondaryContainer: cor,
      onSecondaryContainer: contraste(cor),
    );
  }

  /// Preto ou branco: o que contrastar melhor com a cor dada.
  static Color contraste(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  static ThemeData claro() =>
      ThemeData(colorScheme: _esquema(Brightness.light));

  static ThemeData escuro() =>
      ThemeData(colorScheme: _esquema(Brightness.dark));
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

/// Cores oferecidas no personalizador de tema (aba Ajustes).
const List<int> coresTema = [
  0xFF2E7D32, // verde
  0xFF66BB6A, // verde claro
  0xFF9CCC65, // verde-limão
  0xFF39D353, // verde neon
  0xFF00897B, // verde-água
  0xFF26C6DA, // ciano
  0xFF64B5F6, // azul bebê
  0xFF1E88E5, // azul
  0xFF1A237E, // azul-marinho
  0xFF5C6BC0, // índigo
  0xFF7B1FA2, // roxo
  0xFFAB47BC, // lilás
  0xFFE91E63, // rosa
  0xFFF06292, // rosa claro
  0xFFD32F2F, // vermelho
  0xFF7B2233, // vinho
  0xFFEF6C00, // laranja
  0xFFFFB300, // âmbar
  0xFF8D6E63, // marrom
  0xFF546E7A, // cinza-azulado
];

/// Tema predefinido (nome + cor principal + destaque opcional).
class PaletaTema {
  const PaletaTema(this.nome, this.primaria, [this.secundaria]);

  final String nome;
  final int primaria;
  final int? secundaria;
}

/// Combinações prontas para escolher com um toque.
const List<PaletaTema> paletasTema = [
  PaletaTema('Verde (padrão)', 0xFF2E7D32),
  PaletaTema('Esmeralda', 0xFF009688),
  PaletaTema('Verde-limão', 0xFF9CCC65),
  PaletaTema('Verde neon', 0xFF39D353),
  PaletaTema('Ciano', 0xFF26C6DA),
  PaletaTema('Azul bebê', 0xFF64B5F6),
  PaletaTema('Marinho & Azul bebê', 0xFF1A237E, 0xFF64B5F6),
  PaletaTema('Roxo', 0xFF7B1FA2),
  PaletaTema('Rosa', 0xFFE91E63),
  PaletaTema('Vermelho', 0xFFD32F2F),
  PaletaTema('Vinho & Rosa', 0xFF7B2233, 0xFFF06292),
  PaletaTema('Laranja', 0xFFEF6C00),
  PaletaTema('Âmbar', 0xFFFFB300),
];
