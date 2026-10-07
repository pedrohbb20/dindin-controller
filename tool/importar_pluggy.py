#!/usr/bin/env python3
"""Importador automático do Dindin Controller via Pluggy (Open Finance).

Puxa as transações do Nubank e do Mercado Pago (Meu Pluggy pessoal) e importa
no banco local do app, com:
  - dedupe por id da Pluggy (tabela local pluggy_journal, fora da sincronização)
  - "pente fino": se já existir lançamento local de MESMO valor (e mesma
    direção) a até 3 dias de distância, marca como provável duplicata e PULA
    (o Mestre revisa depois)
  - categorização automática por regras
  - carimbo de sincronização (sync_id/updated_at), então o que entra aqui
    viaja para o celular na próxima sincronização do app

Arquivos externos (fora do repositório, com dados pessoais):
  ~/hermes_analise/pluggy/credentials.json  -> client_id/client_secret
  ~/hermes_analise/pluggy/contas.json       -> mapa das contas Pluggy

Uso:
  python3 tool/importar_pluggy.py                # ENSAIO (não grava nada)
  python3 tool/importar_pluggy.py --gravar       # importa de verdade
  python3 tool/importar_pluggy.py --desde 2026-10-01
"""
import json
import os
import shutil
import sqlite3
import sys
import uuid
from datetime import date, datetime, timedelta, timezone
from urllib.parse import parse_qs, urlparse

import requests

BASE_PLUGGY = 'https://api.pluggy.ai'
HOME = os.path.expanduser('~')
CREDENCIAIS = os.path.join(HOME, 'hermes_analise/pluggy/credentials.json')
CONTAS_JSON = os.path.join(HOME, 'hermes_analise/pluggy/contas.json')
BANCO = os.path.join(HOME, '.local/share/com.pedro.dindin_controller/dindin.db')

# Categorias da Pluggy que NÃO entram (transferências internas, rendimentos,
# pagamento de fatura do cartão e transferências entre contas da mesma pessoa).
EXCLUIR_CATEGORIAS = {
    'Proceeds interests and dividends',
    'Transfer - Internal',
    'Credit card payment',
    'Same person transfer',
}

# Mapa categoria da Pluggy -> nome da categoria no app (por sentido).
MAPA_CATEGORIAS = {
    ('Taxi and ride-hailing', 'expense'): 'Transporte',
    ('Eating out', 'expense'): 'Alimentação',
    ('Food delivery', 'expense'): 'Entregas',
    ('Groceries', 'expense'): 'Alimentação',
    ('Shopping', 'expense'): 'Compras',
    ('Online shopping', 'expense'): 'Compras',
    ('Pharmacy', 'expense'): 'Saúde',
    ('Telecommunications', 'expense'): 'Celular',
    ('School', 'expense'): 'Educação',
    ('Services', 'expense'): 'Contas e Serviços',
    ('Digital services', 'expense'): 'Contas e Serviços',
    ('Gambling', 'expense'): 'Loterias',
    ('Investments', 'expense'): 'investimentos',
    ('Investments', 'income'): 'Investimentos',
    ('Transfer - PIX', 'expense'): 'Outros',
    ('Transfer - PIX', 'income'): 'Outros',
    ('Transfers', 'expense'): 'Outros',
    ('Transfers', 'income'): 'Outros',
}

# Ajustes finos por descrição (aplicados por cima da categoria).
REGRAS_DESCRICAO = [
    (('99 TECNOLOGIA', 'DL*99', '99 RIDE', '99APP'), 'expense', 'Transporte'),
]


def agora_iso():
    return datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')


def autenticar():
    cred = json.load(open(CREDENCIAIS))
    app = cred['apps']['atual']
    r = requests.post(f'{BASE_PLUGGY}/auth', timeout=30, json={
        'clientId': app['client_id'],
        'clientSecret': app['client_secret'],
    })
    r.raise_for_status()
    return {'X-API-KEY': r.json()['apiKey']}


def cursor_do_next(nextv):
    """O campo `next` vem no formato '?accountId=...&after=<base64 url-encoded>'."""
    if not nextv:
        return None
    q = parse_qs(urlparse(nextv).query)
    return (q.get('after') or [None])[0]


def puxar_transacoes(headers, account_id, desde):
    todas, after = [], None
    while True:
        params = {'accountId': account_id, 'dateFrom': desde}
        if after:
            params['after'] = after
        r = requests.get(f'{BASE_PLUGGY}/v2/transactions',
                         headers=headers, params=params, timeout=60)
        r.raise_for_status()
        j = r.json()
        res = j.get('results', [])
        todas.extend(res)
        after = cursor_do_next(j.get('next'))
        if not res or not after:
            break
    return todas


def escolher_categoria(cat_pluggy, direcao, descricao, categorias_por_nome):
    nome = None
    for (c, d), alvo in MAPA_CATEGORIAS.items():
        if c == cat_pluggy and d == direcao:
            nome = alvo
            break
    for termos, dir_regra, alvo in REGRAS_DESCRICAO:
        if dir_regra == direcao and any(t in descricao.upper() for t in termos):
            nome = alvo
            break
    if nome is None:
        nome = 'Outros'
    return categorias_por_nome.get((nome, direcao))


def carregar_contexto_banco(con):
    cur = con.cursor()
    contas = {}
    for cid, nome, tipo, archived in cur.execute(
            'SELECT id, name, type, archived FROM accounts WHERE deleted = 0'):
        contas.setdefault(nome, []).append((cid, tipo, archived))
    categorias = {}
    for cid, nome, tipo in cur.execute(
            'SELECT id, name, type FROM categories WHERE deleted = 0'):
        categorias[(nome, tipo)] = cid
    existentes = []  # (date, type, amount_cents)
    for d, t, a in cur.execute(
            'SELECT date, type, amount_cents FROM transactions WHERE deleted = 0'):
        existentes.append((d, t, a))
    return contas, categorias, existentes


def garantir_journal(con):
    con.execute('''CREATE TABLE IF NOT EXISTS pluggy_journal(
        pluggy_id TEXT PRIMARY KEY,
        tx_id INTEGER,
        conta_pluggy TEXT,
        importado_em TEXT
    )''')


def ids_ja_importados(con):
    try:
        return {r[0] for r in con.execute('SELECT pluggy_id FROM pluggy_journal')}
    except sqlite3.OperationalError:
        return set()


def main():
    gravar = '--gravar' in sys.argv
    desde = '2026-10-01'
    if '--desde' in sys.argv:
        desde = sys.argv[sys.argv.index('--desde') + 1]

    h = autenticar()
    mapa = json.load(open(CONTAS_JSON))['contas']
    hoje = date.today().isoformat()

    con = sqlite3.connect(BANCO)
    contas_app, categorias_app, existentes = carregar_contexto_banco(con)
    ja_importados = ids_ja_importados(con)

    plano = []          # (conta_pluggy, cfg, transação, motivo)
    resumo = {}
    for acc_id, cfg in mapa.items():
        txs = puxar_transacoes(h, acc_id, desde)
        linhas, excluidas, dups, ja = [], 0, [], 0
        for t in txs:
            if t.get('status') not in ('POSTED', 'PENDING'):
                excluidas += 1
                continue
            if t['date'][:10] > hoje:
                excluidas += 1
                continue
            if (t.get('category') or '') in EXCLUIR_CATEGORIAS:
                excluidas += 1
                continue
            if not t.get('amount') or abs(t['amount']) < 0.01:
                excluidas += 1
                continue
            if t['id'] in ja_importados:
                ja += 1
                continue
            direcao = 'expense' if t.get('type') == 'DEBIT' else 'income'
            cents = round(abs(t['amount']) * 100)
            d = t['date'][:10]
            # pente fino contra o que já existe (manual ou de outras fontes)
            dup = None
            for (de, te, ae) in existentes:
                if te == direcao and ae == cents and abs(
                        (date.fromisoformat(de) - date.fromisoformat(d)).days) <= 3:
                    dup = de
                    break
            if dup is not None:
                dups.append((d, t.get('description', ''), cents, dup))
                continue
            linhas.append((t, direcao, cents, d))
        resumo[acc_id] = {'cfg': cfg, 'linhas': linhas, 'excluidas': excluidas,
                          'dups': dups, 'ja': ja, 'total_pluggy': len(txs)}
        plano.extend([(acc_id, cfg, l) for l in linhas])

    # ─── Relatório (sempre) ───
    print(f'=== IMPORTAÇÃO PLUGGY {"(GRAVANDO)" if gravar else "(ENSAIO — nada será gravado)"} ===')
    print(f'Janela: desde {desde} · hoje {hoje}\n')
    total_imp = 0
    for acc_id, r in resumo.items():
        cfg = r['cfg']
        soma = sum(1 for l in r['linhas'])
        valor = sum(l[2] for l in r['linhas'])
        print(f"--- {cfg['banco']} · {cfg['apelido_app']}: {r['total_pluggy']} puxadas | "
              f"{r['excluidas']} excluídas por regra | {r['ja']} já importadas | "
              f"{len(r['dups'])} prováveis duplicatas | {soma} a importar (R$ {valor/100:.2f})")
        for (d, desc, cents, dup) in r['dups']:
            print(f"      [dup] {d} | {desc[:48]!r} | R$ {cents/100:.2f} (bate com {dup})")
        limite = 999 if '--ver-tudo' in sys.argv else 6
        for l in r['linhas'][:limite]:
            t, direcao, cents, d = l
            print(f"      [nova] {d} | {direcao:7} | R$ {cents/100:>8.2f} | "
                  f"{t.get('description','')[:44]!r} | {t.get('category')} | {t.get('status')}")
        total_imp += r['total_pluggy']

    print()
    print('Ações nas contas do app:')
    for acc_id, r in resumo.items():
        nome = r['cfg']['apelido_app']
        reg = contas_app.get(nome)
        if not reg:
            print(f"   + criar conta '{nome}' ({r['cfg']['tipo_app']})")
        elif reg[0][2] == 1:
            print(f"   ! conta '{nome}' existe ARQUIVADA (id {reg[0][0]}) — "
                  f"{'desarquivar e usar' if not gravar else 'desarquivando'}")
        else:
            print(f"   = usar conta '{nome}' existente (id {reg[0][0]})")

    if not gravar:
        print('\n(ENSAIO: nada foi gravado. Rode com --gravar para importar.)')
        return

    # ─── Gravação ───
    backup = f'{BANCO}.bak-pluggy-{datetime.now():%Y%m%d-%H%M}'
    shutil.copy2(BANCO, backup)
    print(f'\nbackup criado: {backup}')

    garantir_journal(con)
    agora = agora_iso()
    criadas, desarquivadas, inseridas = 0, 0, 0
    for acc_id, r in resumo.items():
        cfg = r['cfg']
        nome = cfg['apelido_app']
        reg = contas_app.get(nome)
        if reg is None:
            cur = con.execute(
                'INSERT INTO accounts(name, type, initial_balance_cents, color_value,'
                ' archived, sync_id, updated_at, deleted) VALUES(?,?,?,?,0,?,?,0)',
                (nome, cfg['tipo_app'], 0, 0xFF546E7A, str(uuid.uuid4()), agora))
            conta_app_id = cur.lastrowid
            contas_app[nome] = [(conta_app_id, cfg['tipo_app'], 0)]
            criadas += 1
        else:
            conta_app_id, _tipo, archived = reg[0]
            if archived == 1:
                con.execute('UPDATE accounts SET archived = 0, updated_at = ? WHERE id = ?',
                            (agora, conta_app_id))
                desarquivadas += 1
        for (t, direcao, cents, d) in r['linhas']:
            nota = t.get('description', '')
            if t.get('status') == 'PENDING':
                nota = f'{nota} (na fatura)'
            cat_id = escolher_categoria(t.get('category') or '', direcao, nota, categorias_app)
            cur = con.execute(
                'INSERT INTO transactions(type, amount_cents, date, account_id,'
                ' to_account_id, category_id, note, sync_id, updated_at, deleted)'
                ' VALUES(?,?,?,?,NULL,?,?,?,?,0)',
                (direcao, cents, d, conta_app_id, cat_id, nota,
                 str(uuid.uuid4()), agora))
            con.execute('INSERT INTO pluggy_journal(pluggy_id, tx_id, conta_pluggy,'
                        ' importado_em) VALUES(?,?,?,?)',
                        (t['id'], cur.lastrowid, acc_id, agora))
            inseridas += 1
    con.commit()
    con.close()
    print(f'RESULTADO: {inseridas} lançamentos importados | {criadas} contas criadas | '
          f'{desarquivadas} conta(s) desarquivada(s).')
    print('Próximo passo: abrir o app e sincronizar (o lançamento vai para o celular).')


if __name__ == '__main__':
    main()
