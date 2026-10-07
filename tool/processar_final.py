#!/usr/bin/env python3
"""Versão final: classifica (v2), deduplica com junho existente e gera a lista de inserção."""
import json
import os
import re
import sqlite3

BASE = "/home/pedro/hermes_analise/extratos"
dados = json.load(open(f"{BASE}/movimentos_extraidos.json"))

# ─── fixes manuais (descrições embaralhadas no layout, confirmadas na versão boa) ───
FIX_DESC = {
    "173824150016": "Pix enviado Pedro Henrique Brito Bezerra",   # -589,37
    "172899767171": "Dinheiro reservado Gastar com Alice",        # -513,71
}


def tem(d, *ws):
    du = d.upper()
    return all(w.upper() in du for w in ws)


def tem_alg(d, *ws):
    du = d.upper()
    return any(w.upper() in du for w in ws)


def nota_loja(d):
    for chave, nota in [
        ("bigmeck", "bigmeck"), ("fernandoperei", "fernandoperei"),
        ("casa noise", "casa noise"), ("Low Negocios", "Low Negocios"),
        ("Lojas americanas", "Lojas Americanas"), ("Lojas renner", "Renner"),
        ("Lojas riachuelo", "Riachuelo"), ("Shopee", "Shopee"), ("Sams", "Sam's Club"),
        ("Ingresso.com", "Ingresso.com"), ("INGRESSO.COM", "Ingresso.com"),
        ("Espetinho", "espetinho"), ("Galpao do sertao", "Galpão do Sertão"),
        ("R2 burguer", "R2 Burguer"), ("Hamburgueria", "vikings"),
        ("Brigaderia", "Brigaderia Belga"), ("Dark bebidas", "Dark Bebidas"),
        ("Mix mateus", "Mix Mateus"), ("paroquia", "Paróquia"),
        ("ARQUIDIOCESE", "Arquidiocese"), ("Nickfundiversoes", "Nick"),
        ("Jogos esportivos", "jogos esportivos"), ("Drogarias", "Drogarias São Paulo"),
        ("Shamar", "Shamar"), ("Milkymoo", "Milkymoo"), ("Agroterra", "Agroterra"),
        ("JOANE", "Joane"), ("ULISSES", "Ulisses"), ("CLEDYSTON", "Cledyston"),
    ]:
        if chave.upper() in d.upper():
            return nota
    return ""


def classificar(m, ids_grupo):
    d = FIX_DESC.get(m["id"], m["desc"])
    v = m["valor"]
    mid = m["id"]

    # ─── exclusões ───
    if tem(d, "Rendimentos"):
        return ("EXCL", "rendimento")
    if abs(v + 0.10) < 0.001:
        return ("EXCL", "reservinha 0,10")
    if tem(d, "Reserva por gastos"):
        return ("EXCL", "cofrinho")
    if tem_alg(d, "Dinheiro reservado", "Dinheiro retirado", "Liberação de dinheiro"):
        return ("EXCL", "cofrinho interno")
    if mid in ids_grupo:
        return ("EXCL", "estorno (par)")
    if tem(d, "Reembolso de pagamento"):
        return ("EXCL", "estorno solto")

    # ─── transferências entre contas próprias ───
    if re.search(r"Pix (recebido|enviado)\s+PEDRO HENRIQUE BRITO", d.upper() if d.isupper() else d) or \
       re.search(r"(?i)pix (recebido|enviado) pedro henrique brito", d):
        if abs(v - 606.92) < 0.01:
            return ("Salário", "")
        return ("AMBIG", "transferência entre contas próprias")

    # ─── fatura de cartão ───
    if tem_alg(d, "Cartão de crédito", "Cartao de credito", "de fatura"):
        if v < 0:
            return ("Pagamento do cartão", "")
        return ("EXCL", "crédito de fatura")

    # ─── faculdade ───
    if tem_alg(d, "FACULDADE ANISIO", "Educação Securitizadora", "Principia"):
        if v < 0:
            return ("Educação", "faculdade")
        return ("EXCL", "estorno faculdade")

    # ─── gastos ───
    if v < 0:
        du = d.upper()
        if tem_alg(d, "Dl*99", "Dl *99", "99 l2l", "Pg *99", "Dl *uberrides", "Dl*uberrides",
                   "Pagamento Uber", "Uber *trip", "Pagamento 99"):
            return ("Transporte", "")
        if "IFOOD" in du:
            return ("Lanches", "ifood")
        if tem_alg(d, "Jim.com ts", "TS SALGADOS", "salgados ltda"):
            return ("Lanches", "salgados")
        if "SGPAY" in du:
            return ("Outros", "SGPAY")
        if "SECRETARIA DE ADMINISTRACAO" in du or "ADMINISTRACAO D" in du:
            return ("Outros", "Secretaria de Administração")
        if "ME INSTITUICAO" in du:
            return ("Outros", "Me (maquininha)")
        if "CAIXA LOTERIAS" in du:
            return ("Loterias", "")
        if "CONSELHO REGIONAL" in du:
            return ("Outros", "CRESS")
        if "DROGARIAS" in du:
            return ("Saúde", "Drogarias São Paulo")
        if tem_alg(d, "Lojas americanas", "Lojas renner", "Lojas riachuelo", "Shopee", "AliExpress",
                   "Mercado Livre", "Sams"):
            return ("Compras", nota_loja(d))
        if "MIX MATEUS" in du:
            return ("Alimentação", "Mix Mateus")
        if tem_alg(d, "Espetinho", "Galpao", "R2 burguer", "Hamburgueria", "Brigaderia",
                   "Dark bebidas", "Milkymoo", "burger"):
            return ("Lanches", nota_loja(d))
        if tem_alg(d, "Ingresso.com", "Nickfundiversoes"):
            return ("Lazer", nota_loja(d))
        if "ARQUIDIOCESE" in du:
            return ("Outros", "Arquidiocese")
        if "JOGOS ESPORTIVOS" in du:
            return ("Jogos", "")
        if "CASA NOISE" in du:
            return ("festas", "casa noise")
        if "FERNANDOPEREI" in du:
            return ("Necessidades diárias", "fernandoperei")
        if "ISABEL LEITE" in du:
            return ("Outros", "Isabel")
        if "PAULO SERGIO" in du:
            return ("Necessidades diárias", "Paulo Sergio")
        if "LOW NEGOCIOS" in du:
            return ("Compras", "Low Negocios")
        if "BIGMECK" in du:
            return ("Lanches", "bigmeck")
        if "PAROQUIA" in du:
            return ("Outros", "Paróquia Imaculada")
        if "ALICE" in du and ("PIX ENVIADO" in du or "ENVIADO ALICE" in du):
            return ("Alice", "")
        if "ELYVANIA" in du:
            return ("Necessidades diárias", "Elyvania")
        if "GIOVANNA" in du:
            return ("Outros", "Giovanna")
        for chave, nota in [("GABRIEL", "Gabriel"), ("AGROTERRA", "Agroterra"),
                            ("ADORNO", "Adorno"), ("SHAMAR", "Shamar"),
                            ("ULISSES", "Ulisses"), ("JOANE", "Joane"),
                            ("CLEDYSTON", "Cledyston")]:
            if chave in du:
                return ("Outros", nota)
        m2 = re.search(r"(?i)(pix enviado|transferência enviada|enviado)\s+([A-ZÀ-Ú][\wÀ-ú]+)", d)
        if m2:
            return ("Outros", m2.group(2).title())
        return ("Outros", "")

    # ─── receitas ───
    du = d.upper()
    if tem_alg(d, "HELBER", "ANTONIO"):
        return ("Outros", "de pai")
    if "ALICE" in du and "CAVALCANTE" in du:
        return ("Outros", "de Alice")
    if "HONORINA" in du:
        return ("Ajudinha de Vó❤️", "de vó Nora")
    if "ANTONIA DIVA" in du:
        return ("Ajudinha de Vó❤️", "de tia diva")
    if "ELYVANIA" in du:
        return ("Outros", "de Elyvania")
    if "TS SALGADOS" in du:
        return ("Outros", "TS Salgados")
    if "IVAN" in du:
        return ("Outros", "de Ivan")
    if "JAIRO" in du:
        return ("Outros", "de Jairo")
    if "LUAN" in du:
        return ("Outros", "de Luan")
    if "MEIRYDEAN" in du:
        return ("Outros", "de Meirydean")
    if "STEFANY" in du:
        return ("Outros", "de Stefany")
    if "SUELLEN" in du:
        return ("Outros", "de Suellen")
    if "VALERIA" in du:
        return ("Outros", "de Valéria")
    if "BRUNO" in du:
        return ("Outros", "de Bruno")
    if "VITOR" in du:
        return ("Outros", "de Vitor")
    if "SARAH" in du:
        return ("Outros", "de Sarah")
    if "RENATO" in du:
        return ("Outros", "de Renato")
    if "FLAVIO" in du:
        return ("Outros", "de Flávio")
    if "FELIPE" in du:
        return ("Outros", "de Felipe")
    if "ANDERSON" in du:
        return ("Outros", "de Anderson")
    if "LETICIA" in du:
        return ("Outros", "de Letícia")
    m3 = re.search(r"(?i)pix recebido\s+([A-ZÀ-Ú][\wÀ-ú]+)", d)
    if m3:
        return ("Outros", f"de {m3.group(1).title()}")
    return ("AMBIG", "receita não classificada")


# ─── grupos de estorno ───
ids_grupo = set()
for mes, info in dados.items():
    por_id = {}
    for m in info["movs"]:
        por_id.setdefault(m["id"], []).append(m)
    for mid, grupo in por_id.items():
        if len(grupo) >= 2 and abs(sum(g["valor"] for g in grupo)) < 0.011:
            ids_grupo.add(mid)

# ─── dedupe junho: lançamentos manuais já existentes no Dindin ───
dd = sqlite3.connect("file:" + os.path.expanduser(
    "~/.local/share/com.pedro.dindin_controller/dindin.db") + "?mode=ro", uri=True)
manuais = []
for r in dd.execute("SELECT date, type, amount_cents FROM transactions WHERE date LIKE '2026-06%'"):
    manuais.append({"date": r[0], "tipo": "income" if r[1] == "income" else "expense",
                    "cents": r[2]})
dd.close()
print(f"manuais de junho no Dindin: {len(manuais)}")


def dia(s):
    y, m, d = s.split("-")
    return int(y) * 372 + int(m) * 31 + int(d)


# ─── processar tudo ───
lista_final = []
resumo = {"EXCL": 0, "AMBIG": 0, "CASADO": 0, "OK": 0}
casados = []
ambigs = []
excl_por_motivo = {}

for mes in ("junho", "julho", "agosto"):
    ano, mo = {"junho": (2026, 6), "julho": (2026, 7), "agosto": (2026, 8)}[mes]
    for m in dados[mes]["movs"]:
        dec = classificar(m, ids_grupo)
        if dec[0] == "EXCL":
            resumo["EXCL"] += 1
            excl_por_motivo[dec[1]] = excl_por_motivo.get(dec[1], 0) + 1
            continue
        if dec[0] == "AMBIG":
            resumo["AMBIG"] += 1
            ambigs.append({"mes": mes, "data": m["data"], "valor": m["valor"], "desc": m["desc"]})
            continue
        # monta item
        d2, m2_, a2 = m["data"].split("-")
        iso = f"{a2}-{m2_}-{d2}"
        tipo = "income" if m["valor"] > 0 else "expense"
        cents = round(abs(m["valor"]) * 100)
        item = {"mes": mes, "date": iso, "tipo": tipo, "categoria": dec[0],
                "nota": dec[1], "cents": cents, "desc_orig": m["desc"], "id": m["id"]}
        # dedupe junho
        if mes == "junho":
            casou = False
            for man in manuais:
                if man["tipo"] == tipo and man["cents"] == cents and abs(dia(man["date"]) - dia(iso)) <= 1:
                    casou = True
                    casados.append({"extrato": item, "manual": man})
                    break
            if casou:
                resumo["CASADO"] += 1
                continue
        resumo["OK"] += 1
        lista_final.append(item)

json.dump(lista_final, open(f"{BASE}/lista_final.json", "w"), ensure_ascii=False, indent=1)

print("\n===== RESUMO GERAL =====")
for k, v in resumo.items():
    print(f"  {k}: {v}")
print("\nexclusões por motivo:")
for k, v in sorted(excl_por_motivo.items(), key=lambda x: -x[1]):
    print(f"  {k}: {v}")

print(f"\n===== CASADOS (extrato pulado, manual mantido) [{len(casados)}] =====")
for c in casados:
    e = c["extrato"]
    print(f"  {e['date']} R$ {e['cents']/100:>8.2f} {e['tipo'][:3]} <-> manual {c['manual']['date']} "
          f"R$ {c['manual']['cents']/100:>8.2f}")

print(f"\n===== AMBÍGUOS (não lançados) [{len(ambigs)}] =====")
for a in ambigs:
    print(f"  {a['mes']} {a['data']} R$ {a['valor']:>9.2f} {a['desc'][:70]!r}")

print(f"\n===== LISTA FINAL PARA INSERÇÃO [{len(lista_final)}] =====")
tot = {"junho": 0, "julho": 0, "agosto": 0}
for it in lista_final:
    tot[it["mes"]] += 1
    nota = f" | {it['nota']}" if it["nota"] else ""
    print(f"  {it['date']} {it['tipo'][:3]} R$ {it['cents']/100:>8.2f} {it['categoria']}{nota}")
print(f"\npor mês: {tot}")
