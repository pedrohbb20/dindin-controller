import 'package:flutter/material.dart';

import '../data/tema.dart';

/// Aba Ajustes: aparência do app (modo claro/escuro/sistema e cores).
/// As escolhas aplicam na hora e ficam salvas neste aparelho.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListenableBuilder(
      listenable: Tema.tudo,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Modo (claro / escuro / sistema) ───
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modo', style: tema.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                          visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.light, label: Text('Claro')),
                        ButtonSegment(
                            value: ThemeMode.dark, label: Text('Escuro')),
                        ButtonSegment(
                            value: ThemeMode.system, label: Text('Sistema')),
                      ],
                      selected: {Tema.notifier.value},
                      onSelectionChanged: (s) => Tema.definirModo(s.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Prévia ao vivo ───
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prévia', style: tema.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _bola(tema.colorScheme.primary, 'Principal'),
                        const SizedBox(width: 16),
                        _bola(tema.colorScheme.secondary, 'Destaque'),
                        const Spacer(),
                        FilledButton(
                            onPressed: () {}, child: const Text('Botão')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                          value: 0.62, minHeight: 8),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                            label: const Text('Exemplo'),
                            selected: true,
                            onSelected: (_) {}),
                        const Chip(label: Text('Etiqueta')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Cores predefinidas ───
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cores predefinidas', style: tema.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text('Toque para aplicar na hora.',
                        style: tema.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final p in paletasTema) _opcaoPaleta(p),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Personalizado (mescla de principal + destaque) ───
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personalizado', style: tema.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text('Escolha a cor principal e a de destaque (mescla).',
                        style: tema.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Text('Principal', style: tema.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final cor in coresTema)
                          _selo(
                            cor,
                            selecionada: Tema.corPrimaria.value == cor,
                            aoTocar: () => Tema.definirCores(
                                cor, Tema.corSecundaria.value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Destaque (secundária)',
                        style: tema.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _seloAutomatico(),
                        for (final cor in coresTema)
                          _selo(
                            cor,
                            selecionada: Tema.corSecundaria.value == cor,
                            aoTocar: () => Tema.definirCores(
                                Tema.corPrimaria.value, cor),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'As cores ficam salvas neste aparelho.',
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bola(Color cor, String rotulo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(height: 4),
        Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _circulo(Color cor) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      );

  Widget _opcaoPaleta(PaletaTema p) {
    final atual = Tema.corPrimaria.value == p.primaria &&
        Tema.corSecundaria.value == p.secundaria;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Tema.definirCores(p.primaria, p.secundaria),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: atual
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 58,
              height: 26,
              child: Stack(
                children: [
                  Positioned(left: 0, child: _circulo(Color(p.primaria))),
                  if (p.secundaria != null)
                    Positioned(
                        right: 0, child: _circulo(Color(p.secundaria!))),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              p.nome,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selo(int cor, {required bool selecionada, required VoidCallback aoTocar}) {
    final c = Color(cor);
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: aoTocar,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selecionada
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outlineVariant,
            width: selecionada ? 3 : 1,
          ),
        ),
        child: selecionada
            ? Icon(Icons.check, size: 18, color: Tema.contraste(c))
            : null,
      ),
    );
  }

  Widget _seloAutomatico() {
    final selecionada = Tema.corSecundaria.value == null;
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Destaque automático (derivado da principal)',
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => Tema.definirCores(Tema.corPrimaria.value, null),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selecionada ? cs.onSurface : cs.outlineVariant,
              width: selecionada ? 3 : 1,
            ),
          ),
          child: Icon(Icons.auto_awesome, size: 17, color: cs.primary),
        ),
      ),
    );
  }
}
