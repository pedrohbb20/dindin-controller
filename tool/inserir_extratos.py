#!/usr/bin/env python3
"""Insere no Dindin Controller os lançamentos extraídos dos extratos do
Mercado Pago (junho, julho e agosto de 2026).

Uso: python3 inserir_extratos.py
- Idempotente: marcador 'importado_extratos_2026' em settings.
- Backup automático antes de escrever.
- Todos os lançamentos entram na conta 3 (Mercado Pago).
"""
import json
import os
import shutil
import sqlite3
import time

DB = os.path.expanduser("~/.local/share/com.pedro.dindin_controller/dindin.db")
LISTA = "/home/pedro/hermes_analise/extratos/lista_final.json"

lista = json.load(open(LISTA))
conn = sqlite3.connect(DB)
cur = conn.cursor()

# ─── idempotência ───
if cur.execute("SELECT value FROM settings WHERE key='importado_extratos_2026'").fetchone():
    print("JÁ IMPORTADO (marcador presente). Abortando para não duplicar.")
    raise SystemExit(1)

# ─── backup ───
bkp = DB + ".bak-extratos-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy(DB, bkp)
print("backup:", bkp)

# ─── mapa de categorias (name, type) -> id ───
cats = {}
for cid, name, ctype in cur.execute("SELECT id, name, type FROM categories"):
    cats[(name, ctype)] = cid

faltando = {(i["categoria"], i["tipo"]) for i in lista
            if (i["categoria"], i["tipo"]) not in cats}
if faltando:
    print("CATEGORIAS FALTANDO:", faltando)
    raise SystemExit(2)

# ─── inserir ───
n = 0
for it in lista:
    cid = cats[(it["categoria"], it["tipo"])]
    cur.execute(
        "INSERT INTO transactions (type, amount_cents, date, account_id, to_account_id, "
        "category_id, note) VALUES (?, ?, ?, 3, NULL, ?, ?)",
        (it["tipo"], it["cents"], it["date"], cid, it["nota"] or None))
    n += 1

stamp = time.strftime("%Y%m%d-%H%M%S")
cur.execute("INSERT INTO settings (key, value) VALUES ('importado_extratos_2026', ?)",
            (f"{stamp}:{n}",))
conn.commit()
print(f"INSERIDOS: {n}")

# ─── conferência: banco x lista ───
print("\nconferência (banco x lista):")
for mes, pat, esperado in [("junho", "2026-06", [i for i in lista if i["mes"] == "junho"]),
                           ("julho", "2026-07", [i for i in lista if i["mes"] == "julho"]),
                           ("agosto", "2026-08", [i for i in lista if i["mes"] == "agosto"])]:
    cnt = cur.execute("SELECT COUNT(*) FROM transactions WHERE date LIKE ? || '%'", (pat,)).fetchone()[0]
    soma = cur.execute("SELECT COALESCE(SUM(amount_cents),0) FROM transactions WHERE date LIKE ? || '%'",
                       (pat,)).fetchone()[0]
    soma_l = sum(i["cents"] for i in esperado)
    status = "OK" if cnt >= len(esperado) and soma >= soma_l else "DIVERGE"
    print(f"  {mes}: banco {cnt} (soma {soma}) | lista {len(esperado)} (soma {soma_l}) [{status}]")

conn.close()
