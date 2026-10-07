# Registro de Atualizações (Changelog)

Aplicativo **Dindin Controller**: clone pessoal do Money Tracker (Flutter), para Linux (PC) e Android (celular), com sincronização em nuvem.

## v1.4.0 (07/10/2026)
- Navegação adaptativa: no PC (tela larga) o app mostra um menu lateral com as abas; no celular continua a barra inferior de sempre.
- Gráfico de rosca interativo: tocar (ou passar o mouse) numa fatia a destaca, aumenta e mostra nome, valor e porcentagem no centro.
- Nova dependência: `fl_chart` (gráficos).

## v1.3.0 (07/10/2026)
- Editar lançamentos: toque em qualquer transação da lista para editar valor, data, conta, categoria, observação e tipo (segurar continua excluindo).
- A edição viaja na sincronização (carimbo de atualização renovado por registro).

## v1.2.1 (07/10/2026)
- Ícone oficial do app em todas as plataformas (escudo sobre placa branca), gerado a partir da arte da logo.
- Nome exibido no celular corrigido para "Dindin Controller" (era `dindin_controller`).
- No PC: título da janela, ícone na barra de tarefas e atalho com ícone no menu de aplicativos.
- Pasta de arte do projeto (`assets/logo/`) + pipeline de preparação (`tool/logo_preparar.py`).

## v1.2.0 (07/10/2026)
- Tela de gerenciamento de categorias: remover categoria com aviso de quantos lançamentos usam ela (os lançamentos ficam sem categoria).
- Consolidação no git das Fases 2 a 4 já construídas (investimentos, sincronização, pesquisa de Open Finance).

## v1.1.0 (07/10/2026)
- Sincronização em nuvem (Supabase): controle PC ↔ celular com login por email; banco local v3 (identificadores de sincronização, exclusões suaves); tela de Sincronização.
- Correção: permissão de internet no Android (necessária para sincronização e cotações).

## v1.0.0 (06 e 07/10/2026)
- Primeira versão completa: resumo mensal com gráfico por categoria, transações, contas e transferências.
- Painel de Investimentos: carteira, proventos por mês, reserva de emergência, cotações ao vivo.
- Importações reais: histórico do app antigo (1.166 lançamentos), extratos do Mercado Pago (147) e dados do Investidor10.
- Modo escuro como padrão.
