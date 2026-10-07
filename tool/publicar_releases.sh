#!/bin/bash
# Publica as Releases do Dindin Controller no GitHub (v1.0.0 a v1.2.1),
# anexando os APKs de ~/apk e o pacote do PC Linux da v1.2.1.
# Uso: bash tool/publicar_releases.sh   (precisa do gh autenticado)
set -u
export PATH="$HOME/.local/bin:$PATH"
APK="$HOME/apk"
PROJ="/home/pedro/Documentos/Projetos/dindin_controller"
cd "$PROJ" || exit 1

# 1) pacote do PC (Linux) da v1.2.1, se ainda não existir
PACOTE="$APK/dindin-controller-v1.2.1-linux-x64.tar.gz"
if [ ! -f "$PACOTE" ]; then
  if [ -d build/linux/x64/release/bundle ]; then
    tar -C build/linux/x64/release -czf "$PACOTE" --transform 's,^bundle,dindin-controller-v1.2.1,' bundle
    echo "pacote do PC criado: $PACOTE"
  else
    echo "AVISO: bundle Linux release nao encontrado; sigo sem o pacote do PC"
    PACOTE=""
  fi
fi

# 2) notas de cada versão
cat > /tmp/notas-v1.0.0.md <<'EOF'
Primeira versão do app (registro histórico).
- Núcleo de gastos: resumo mensal com gráfico de rosca por categoria, transações (despesa, receita, transferência), contas
- Painel de Investimentos: carteira, proventos por mês, reserva de emergência, cotações ao vivo
- Dados reais importados: histórico do app antigo (1.166 lançamentos), extratos do Mercado Pago (147) e Investidor10
- Modo escuro como padrão
APK universal (todas as arquiteturas). Tag histórica (commit mais próximo do build).
EOF
cat > /tmp/notas-v1.1.0.md <<'EOF'
Sincronização em nuvem (Supabase).
- Banco local v3 com identificadores de sincronização e exclusões suaves
- Login por email; tela de Sincronização; envio e recebimento automáticos entre aparelhos
- Correção importante: permissão de internet no Android (sem ela, o release não sincronizava)
Anexos: APK universal + APK para celulares arm64.
EOF
cat > /tmp/notas-v1.2.0.md <<'EOF'
Gerenciar categorias.
- Nova tela para remover categorias, com aviso de quantos lançamentos usam cada uma (eles ficam sem categoria)
- A remoção viaja para os outros aparelhos pela sincronização
- Consolidação no repositório das fases 2 a 4 (investimentos, sincronização, pesquisa de Open Finance)
Anexo: APK arm64.
EOF
cat > /tmp/notas-v1.2.1.md <<'EOF'
Ícone e nome oficiais.
- Ícone novo do app (escudo sobre placa branca) no PC e no celular
- Nome exibido no celular agora é "Dindin Controller"
- No PC: título da janela, ícone na barra de tarefas e atalho no menu de aplicativos
Anexos: APK arm64 (Android) e pacote do PC Linux (extrair e rodar o binário de dentro).
EOF

# 3) cria as releases (1.0.0 primeiro; 1.2.1 como "latest")
gh release create v1.0.0 --target c3e4a1f --title "v1.0.0 - Primeira versao" --notes-file /tmp/notas-v1.0.0.md --latest=false "$APK/dindin-controller-v1.0.0.apk" || exit 2
gh release create v1.1.0 --target b86e3ba --title "v1.1.0 - Sincronizacao em nuvem" --notes-file /tmp/notas-v1.1.0.md --latest=false "$APK/dindin-controller-v1.1.0.apk" "$APK/dindin-controller-v1.1.0-arm64.apk" || exit 3
gh release create v1.2.0 --target b86e3ba --title "v1.2.0 - Gerenciar categorias" --notes-file /tmp/notas-v1.2.0.md --latest=false "$APK/dindin-controller-v1.2.0-arm64.apk" || exit 4
if [ -n "${PACOTE:-}" ]; then
  gh release create v1.2.1 --target main --title "v1.2.1 - Icone e nome oficiais" --notes-file /tmp/notas-v1.2.1.md --latest "$APK/dindin-controller-v1.2.1-arm64.apk" "$PACOTE" || exit 5
else
  gh release create v1.2.1 --target main --title "v1.2.1 - Icone e nome oficiais" --notes-file /tmp/notas-v1.2.1.md --latest "$APK/dindin-controller-v1.2.1-arm64.apk" || exit 5
fi

echo "===== RELEASES PUBLICADAS ====="
gh release list
