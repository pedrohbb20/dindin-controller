# Dindin Controller

App pessoal de finanças (clone do "Money Tracker"), feito em Flutter, para **Linux (PC)** e **Android (celular)**, com **sincronização em nuvem** (Supabase) entre os aparelhos.

## O que tem
- Resumo mensal (receitas, despesas, saldo) com gráfico de rosca por categoria
- Transações (despesa, receita e transferência), contas e categorias (criar e remover)
- Painel de Investimentos (carteira, proventos por mês, reserva de emergência, cotações ao vivo)
- Sincronização PC com celular (login por email; cada conta vê só os próprios dados)
- Modo escuro como padrão

## Estrutura
- `lib/` — código do app (Flutter/Dart)
- `tool/` — scripts de importação de dados, sincronização e arte do ícone
- `assets/logo/` — arte oficial do ícone e da marca
- `CHANGELOG.md` — registro de atualizações (v1.0.0 até a atual)

## Como rodar no PC (Linux)
```bash
export PATH="$PATH:$HOME/.local/opt/flutter/bin"
flutter pub get
flutter build linux --debug
./build/linux/x64/debug/bundle/dindin_controller
```

## Como gerar o APK (Android)
```bash
export ANDROID_HOME="$HOME/Android/sdk"
flutter build apk --release --split-per-abi
# saída: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Nuvem (sincronização)
Projeto Supabase com tabelas espelho do banco local; o script de criação fica em `tool/supabase_schema.sql` (com regras de segurança por usuário). As chaves ficam em `lib/data/sync_config.dart`.

> Projeto pessoal, não publicado em loja.
