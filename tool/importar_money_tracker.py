#!/usr/bin/env python3
"""Importa TODO o histórico do Money Tracker (dump ~/mt-dump) para o Dindin Controller.

- Categorias: reusa as existentes no Dindin com mesmo nome+tipo; senão cria (traduzindo as chaves category_* para PT).
- Conta: cria 'Mercado Pago' ARQUIVADA (histórico; não polui o patrimônio das contas reais).
- Transações: todas as não-deletadas (type 1=receita, 2=despesa), data year/month/day, centavos.
- Idempotente: marca em settings; faz backup do banco do Dindin antes de tudo.
"""
import calendar
import os
import shutil
import sqlite3
import sys
from datetime import datetime

HOME = os.path.expanduser("~")
MT_DB = f"{HOME}/mt-dump/databases/my.db"
DD_DB = f"{HOME}/.local/share/com.pedro.dindin_controller/dindin.db"

stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
shutil.copy(DD_DB, f"{DD_DB}.bak-{stamp}")
print(f"backup: {DD_DB}.bak-{stamp}")

mt = sqlite3.connect(f"file:{MT_DB}?mode=ro", uri=True)
mt.row_factory = sqlite3.Row
dd = sqlite3.connect(DD_DB)
dd.row_factory = sqlite3.Row

if dd.execute("SELECT 1 FROM settings WHERE key='imported_money_tracker'").fetchone():
    print("!! Já existe 'imported_money_tracker' em settings. Nada a fazer (abortando).")
    sys.exit(0)

# ─── 1. Categorias do MT (dedup, preferindo a linha do usuário 1117627) ───
rows = mt.execute("""
    SELECT id,title,type,is_custom,user_id,icon,color_value
    FROM income_expenditure_category_new_1 WHERE is_deleted=0""").fetchall()
best = {}
for r in rows:
    cid = r["id"]
    if cid not in best or r["user_id"] == 1117627:
        best[cid] = r

TRAD = {
    "category_financial_management": "Gestão financeira",
    "category_gift_money": "Presentes em dinheiro",
    "category_other": "Outros",
    "category_part_time_job": "Trabalho extra",
    "category_salary": "Salário",
    "category_alcohol": "Bebidas",
    "category_car": "Carro",
    "category_cereals": "Cereais",
    "category_cigarette": "Cigarro",
    "category_clothing": "Roupas",
    "category_daily_necessities": "Necessidades diárias",
    "category_donation": "Doação",
    "category_education": "Educação",
    "category_entertainment": "Lazer",
    "category_express_delivery": "Entregas",
    "category_food": "Alimentação",
    "category_fruit": "Frutas",
    "category_furnish": "Mobília",
    "category_furniture": "Móveis",
    "category_gift": "Presentes",
    "category_hairdressing": "Cabeleireiro",
    "category_lottery": "Loterias",
    "category_medical": "Saúde",
    "category_mobile_phone": "Celular",
    "category_pet": "Pets",
    "category_shopping": "Compras",
    "category_snack": "Lanches",
    "category_sport": "Esporte",
    "category_tool": "Ferramentas",
    "category_transportation": "Transporte",
    "category_travel": "Viagem",
    "category_vegetable": "Vegetais",
}

ICONE_POR_ASSET = {
    "expenditure (1).png": "shopping_bag",
    "expenditure (2).png": "restaurant",
    "expenditure (3).png": "more_horiz",
    "expenditure (4).png": "sports_esports",
    "expenditure (5).png": "school",
    "expenditure (6).png": "more_horiz",
    "expenditure (7).png": "sports_esports",
    "expenditure (8).png": "shopping_bag",
    "expenditure (9).png": "directions_bus",
    "expenditure (10).png": "shopping_bag",
    "expenditure (11).png": "directions_bus",
    "expenditure (12).png": "restaurant",
    "expenditure (13).png": "more_horiz",
    "expenditure (14).png": "directions_bus",
    "expenditure (15).png": "favorite",
    "expenditure (16).png": "favorite",
    "expenditure (17).png": "favorite",
    "expenditure (18).png": "more_horiz",
    "expenditure (19).png": "home",
    "expenditure (20).png": "home",
    "expenditure (21).png": "card_giftcard",
    "expenditure (22).png": "card_giftcard",
    "expenditure (23).png": "attach_money",
    "expenditure (24).png": "restaurant",
    "expenditure (25).png": "restaurant",
    "expenditure (26).png": "restaurant",
    "expenditure (27).png": "restaurant",
    "income (1).png": "work",
    "income (2).png": "trending_up",
    "income (3).png": "trending_up",
    "income (4).png": "card_giftcard",
    "income (5).png": "more_horiz",
    "finance (2).png": "savings",
    "finance (3).png": "savings",
    "finance (7).png": "savings",
    "finance (8).png": "savings",
    "personal (5).png": "favorite",
    "education (12).png": "school",
    "education (13).png": "school",
    "entertainment (1).png": "sports_esports",
    "entertainment (7).png": "receipt_long",
    "food (7).png": "restaurant",
    "food (25).png": "card_giftcard",
    "life (5).png": "favorite",
    "office (12).png": "shopping_bag",
    "other (2).png": "favorite",
    "other (17).png": "home",
}

PALETA = [0xFFEF6C00, 0xFF1976D2, 0xFF6D4C41, 0xFFE53935, 0xFF3949AB, 0xFF8E24AA,
          0xFFD81B60, 0xFF546E7A, 0xFF00897B, 0xFF43A047]

dd_cats = dd.execute("SELECT id,name,type FROM categories").fetchall()
by_key = {(c["name"].strip().lower(), c["type"]): c["id"] for c in dd_cats}

cat_map = {}
criadas = 0
for i, r in enumerate(best.values()):
    title = r["title"]
    tipo = "income" if r["type"] == 1 else "expense"
    nome = TRAD.get(title, title)
    key = (nome.strip().lower(), tipo)
    if key in by_key:
        cat_map[r["id"]] = by_key[key]
        continue
    cor = r["color_value"] or 0
    if not cor:
        cor = PALETA[i % len(PALETA)]
    asset = (r["icon"] or "").split("/")[-1]
    icone = ICONE_POR_ASSET.get(asset, "more_horiz")
    cur = dd.execute(
        "INSERT INTO categories(name,type,icon,color_value,archived) VALUES(?,?,?,?,0)",
        (nome, tipo, icone, cor))
    cat_map[r["id"]] = cur.lastrowid
    criadas += 1
print(f"categorias do MT: {len(best)} | novas: {criadas} | reusadas: {len(best)-criadas}")

# ─── 2. Conta arquivada 'Mercado Pago' para o histórico ───
cur = dd.execute(
    "INSERT INTO accounts(name,type,initial_balance_cents,color_value,archived) "
    "VALUES(?,?,?,?,?)",
    ("Mercado Pago", "bank", 0, 0xFF1565C0, 1))
conta_id = cur.lastrowid
print(f"conta criada: Mercado Pago (id {conta_id}, arquivada)")

# ─── 3. Transações ───
rows = mt.execute("""
    SELECT id,type,year,month,day,amount,remark,income_expenditure_category_id
    FROM income_expenditure WHERE is_deleted=0
    ORDER BY year,month,day""").fetchall()

inseridas = 0
sem_cat = 0
for r in rows:
    tipo = "income" if r["type"] == 1 else "expense"
    y, m, d = r["year"], r["month"], r["day"]
    dmax = calendar.monthrange(y, m)[1]
    d = max(1, min(d, dmax))
    date = f"{y:04d}-{m:02d}-{d:02d}"
    cents = round(r["amount"] * 100)
    cat = cat_map.get(r["income_expenditure_category_id"])
    if cat is None:
        sem_cat += 1
        cat = by_key.get(("outros", tipo))
    note = (r["remark"] or "").strip() or None
    dd.execute(
        "INSERT INTO transactions(type,amount_cents,date,account_id,to_account_id,category_id,note) "
        "VALUES(?,?,?,?,NULL,?,?)",
        (tipo, cents, date, conta_id, cat, note))
    inseridas += 1

dd.execute("INSERT INTO settings(key,value) VALUES('imported_money_tracker', ?)",
           (f"{stamp}:{inseridas}",))
dd.commit()
print(f"transações inseridas: {inseridas} (sem categoria conhecida: {sem_cat})")

# ─── 4. Conferência ───
print()
print("== conferência no Dindin ==")
for r in dd.execute(
        "SELECT type, COUNT(*), ROUND(SUM(amount_cents)/100.0,2) FROM transactions GROUP BY type"):
    print(f"   {r[0]}: {r[1]} lançamentos | R$ {r[2]}")
for r in dd.execute(
        "SELECT substr(date,1,4) y, COUNT(*) FROM transactions GROUP BY y ORDER BY y"):
    print(f"   ano {r[0]}: {r[1]}")
print()
print("esperado do MT: receita 256 (R$ 32568.88) | despesa 910 (R$ 26453.96)")
print("anos: 2024=101, 2025=637, 2026=428")
