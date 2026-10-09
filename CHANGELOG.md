# Registro de Atualizações (Changelog)

Aplicativo **Dindin Controller**: clone pessoal do Money Tracker (Flutter), para Linux (PC) e Android (celular), com sincronização em nuvem.

## v1.7.3 (09/10/2026)
- Correção de sincronização: quando os dois aparelhos sincronizavam ao mesmo tempo (um enviando muitas linhas novas enquanto o outro recebia), uma linha repetida podia travar o recebimento com erro de "código único". Agora o app pula repetidas da leitura e confere o banco antes de inserir; vale para transações, contas, categorias, investimentos e proventos.

## v1.7.2 (07/10/2026)
- **Aviso de atualização dentro do app**: o app confere sozinho (ao abrir e de tempo em tempo) se saiu versão nova no GitHub; quando sai, aparece um cartão no Resumo com o botão **Baixar** (link direto do arquivo) e uma notificação local avisa uma vez por versão. Dá para tocar em "depois" e dispensar.

## v1.7.1 (07/10/2026)
- **Sincronização automática**: o app sincroniza sozinho ao abrir, de hora em hora (enquanto está aberto) e ao voltar para ele, no PC e no celular. Não precisa mais apertar o botão; a opção pode ser desligada em Ajustes.

## v1.7.0 (07/10/2026)
- **Transações reformulada**: separada por mês (igual ao Resumo) com filtros de tipo, categorias, bancos, período personalizado (ex.: 05/10 a 10/10), busca por texto e faixa de valor; etiquetas do que está ativo (com X para tirar) e resumo com entradas/saídas do resultado.
- **Aba Ajustes (nova)**: modo claro/escuro/sistema, 13 cores predefinidas (verde neon, vinho, rosa, azul bebê, marinho...) e personalizado com cor principal + destaque (mescla), com prévia ao vivo. Fica salvo por aparelho.
- **Fila de revisão da importação**: o Resumo avisa quantos lançamentos os bancos trouxeram; a tela "Conferir importados" mostra cada um com botão para corrigir a categoria na hora e "marcar tudo como visto".
- **Evolução do patrimônio**: gráfico mensal na aba Investir (começa com jun/jul/out de 2026 e atualiza sozinho todo mês com as cotações).
- **Simulador do futuro**: aporte mensal + rendimento com duas curvas, o valor nominal e o poder de compra em dinheiro de hoje (descontando a inflação).
- **Contas previstas com lembretes**: cadastre contas fixas (nome, dia, valor) e receba uma notificação às 9h do dia de cada vencimento (Android e Linux); os próximos vencimentos também aparecem no Resumo.
- **Preço teto (Bazin)**: dividendos dos últimos 12 meses de cada ativo divididos pela taxa desejada (padrão 6%), com indicador verde para zona de compra.
- **Possíveis transferências entre contas**: quando uma saída e uma entrada de mesmo valor (até 2 dias de diferença) aparecem em contas diferentes, o Resumo avisa e a tela "Possíveis transferências" deixa casar os dois lados numa única transferência (ou dizer "não é transferência"); casar mantém os saldos das contas certos e tira a contagem dobrada.
- **Projeção de caixa no Resumo**: dentro do cartão de contas previstas, o saldo disponível de hoje (carteira e contas) menos as contas a vencer até o fim do mês, com a sobra projetada em verde ou vermelho.
- Preparação do Android para as notificações (permissões e reagendamento após reiniciar).

## v1.6.0 (07/10/2026)
- Metas de orçamento por categoria: defina um limite mensal de gasto para cada categoria (ex: R$ 500 de Alimentação) e acompanhe no Resumo uma barra de progresso (verde, laranja chegando perto e vermelha quando passa), com o gasto, o que resta e quanto passou.
- Tela nova "Metas de orçamento" (botão no Resumo): definir, mudar e remover limites com facilidade.
- As metas viajam na sincronização (PC ↔ celular) e se renovam sozinhas todo mês.

## v1.5.0 (07/10/2026)
- Título próprio por lançamento: campo novo no formulário (ex: "Gabryel"); na lista ele vira a linha principal do lançamento.
- Lista de transações reorganizada: título (ou a categoria, quando não há título) em cima; categoria · data · banco na linha do meio; observação numa linha discreta embaixo.
- Bancos antigos ganham a coluna nova automaticamente (migração v4); a sincronização leva o título para os outros aparelhos.

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
