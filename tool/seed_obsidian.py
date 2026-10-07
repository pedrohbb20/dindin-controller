#!/usr/bin/env python3
"""Importa a carteira e os proventos do Mestre (Obsidian) para o Dindin Controller.

Dados de origem:
- Carteira: Obsidiana/Hermes/Carteira de Investimentos/03 - Relatorios/carteira-14-08-2026.md
- Proventos: Obsidiana/Hermes/Carteira de Investimentos/04 - Dividendos/historico-2026.md
- Reserva: controle.md (Mercado Pago, 14/08/2026)
"""
import os
import shutil
import sqlite3
import sys

db_path = os.path.expanduser(
    "~/.local/share/com.pedro.dindin_controller/dindin.db"
)

if not os.path.exists(db_path):
    sys.exit(f"Banco não encontrado: {db_path}")

shutil.copy(db_path, db_path + ".bak-antes-do-seed")
con = sqlite3.connect(db_path)
cur = con.cursor()

# Garante que as tabelas da versão 2 existem (espelha a migração do app)
cur.executescript(
    """
    CREATE TABLE IF NOT EXISTS investments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ticker TEXT NOT NULL,
      kind TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      avg_price_cents INTEGER NOT NULL DEFAULT 0,
      note TEXT
    );
    CREATE TABLE IF NOT EXISTS dividends(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      ticker TEXT,
      amount_cents INTEGER NOT NULL,
      note TEXT
    );
    CREATE TABLE IF NOT EXISTS settings(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    """
)
cur.execute("PRAGMA user_version = 2")
con.commit()

# ─── Posições da carteira (14/08/2026) ───
# (ticker, tipo, quantidade, preço médio em centavos, nota)
posicoes = [
    ("BTAL11", "fii", 6, 8025, "Foto de 14/08/2026"),
    ("TRXF11", "fii", 6, 8794, "Foto de 14/08/2026"),
    ("GCRI11", "fii", 7, 6747, "Foto de 14/08/2026"),
    ("MANA11", "fii", 39, 886, "Foto de 14/08/2026"),
    ("BTCI11", "fii", 23, 910, "Foto de 14/08/2026"),
    ("MXRF11", "fii", 18, 950, "Foto de 14/08/2026"),
    ("GARE11", "fii", 15, 872, "Foto de 14/08/2026"),
    ("ITSA4", "acao", 16, 1176, "Foto de 14/08/2026"),
    ("BBAS3", "acao", 1, 2099, "Foto de 14/08/2026"),
]

# ─── Proventos mensais (2025-2026) ───
# (data, ticker, valor em centavos)
proventos = [
    ("2025-08-31", None, 123),
    ("2025-09-30", None, 158),
    ("2025-10-31", None, 726),
    ("2025-11-30", None, 878),
    ("2025-12-31", None, 1408),
    ("2026-01-31", None, 1253),
    ("2026-02-28", None, 1320),
    ("2026-03-31", None, 1353),
    ("2026-04-30", None, 1857),
    ("2026-05-31", None, 1854),
    ("2026-06-30", None, 2256),
    ("2026-07-31", None, 2582),
    ("2026-08-14", None, 666),  # parcial até 14/08
]

# ─── Reserva de emergência (Mercado Pago, 14/08/2026) ───
reserva_cents = 186796  # R$ 1.867,96

cur.execute("SELECT COUNT(*) FROM investments")
if cur.fetchone()[0] > 0:
    print("AVISO: já existem posições no banco, pulando seed de posições.")
else:
    cur.executemany(
        "INSERT INTO investments (ticker, kind, quantity, avg_price_cents, note) "
        "VALUES (?, ?, ?, ?, ?)",
        posicoes,
    )
    print(f"posições inseridas: {len(posicoes)}")

cur.execute("SELECT COUNT(*) FROM dividends")
if cur.fetchone()[0] > 0:
    print("AVISO: já existem proventos no banco, pulando seed de proventos.")
else:
    cur.executemany(
        "INSERT INTO dividends (date, ticker, amount_cents, note) VALUES (?, ?, ?, NULL)",
        [(*p, ) for p in proventos],
    )
    print(f"proventos inseridos: {len(proventos)}")

cur.execute(
    "INSERT OR REPLACE INTO settings (key, value) VALUES ('reserve_cents', ?)",
    (str(reserva_cents),),
)
con.commit()

print("\n── Verificação ──")
for tabela in ("investments", "dividends", "settings"):
    cur.execute(f"SELECT COUNT(*) FROM {tabela}")
    print(f"{tabela}: {cur.fetchone()[0]} registros")
cur.execute("SELECT SUM(avg_price_cents * quantity) FROM investments")
print(f"total investido: R$ {cur.fetchone()[0] / 100:.2f}")
cur.execute("SELECT SUM(amount_cents) FROM dividends")
print(f"total proventos: R$ {cur.fetchone()[0] / 100:.2f}")
con.close()
print("\nSeed concluído ✓")
