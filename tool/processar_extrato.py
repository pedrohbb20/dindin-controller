#!/usr/bin/env python3
"""Parser dos extratos do Mercado Pago (texto do pdftotext -layout).

Valida a extração pela CADEIA DE SALDOS: cada movimento deve fechar com o anterior.
Saída: JSON com os movimentos de cada mês + relatório de validação.
"""
import json
import re
import sys

BASE = "/home/pedro/hermes_analise/extratos"

MESES = {"junho": "junho2026.txt", "julho": "julho2026.txt", "agosto": "agosto2026.txt"}

# linha de movimento: data, desc(opcional), id, valor, saldo
RE_MOV = re.compile(
    r"^\s*(\d{2}-\d{2}-\d{4})\s+(.*?)\s*(\d{10,16})\s+R\$ (-?[\d.,]+)\s+R\$ (-?[\d.,]+)\s*$")

RE_CABECALHO = re.compile(r"Data\s+De?sc?ri?[çc][ãa]o.*Saldo|DDaattaa")
RE_PAGINA = re.compile(r"^\s*\d+/\d+\s*$")
RE_INUTIL = re.compile(
    r"EXTRATO DE CONTA|CPF/CNPJ|Agência|Periodo|Entradas:|Saldo inicial:|Saidas:|"
    r"DETALHE DOS MOVIMENTOS|Data de geração|dúvida|Mercado Pago Institui|"
    r"CNPJ n|Nossos canais|código de atendimento|0800")


def num(s):
    return float(s.replace(".", "").replace(",", "."))


def parse_arquivo(path):
    with open(path, encoding="utf-8") as fh:
        raw = fh.read()
    linhas = raw.replace("\f", "\n").split("\n")

    saldo_ini = None
    for ln in linhas:
        m = re.search(r"Saldo inicial: R\$ (-?[\d.,]+)", ln)
        if m:
            saldo_ini = num(m.group(1))
            break

    movs = []
    frags = []  # fragmentos pendentes (descrições soltas)
    for ln in linhas:
        if not ln.strip():
            continue
        if RE_PAGINA.match(ln) or RE_CABECALHO.search(ln) or RE_INUTIL.search(ln):
            continue
        m = RE_MOV.match(ln)
        if m:
            data, desc_linha, oid, v, s = m.groups()
            movs.append({
                "data": data, "desc_linha": desc_linha.strip(),
                "id": oid, "valor": num(v), "saldo": num(s), "frags": frags,
            })
            frags = []
        else:
            frags.append(ln.strip())
    # fragmentos finais não pertencem a ninguém
    return saldo_ini, movs


def associar_descricoes(movs):
    """Atribui fragmentos ao movimento de menor distância (nº de fragmentos no meio)."""
    descs = {i: [] for i in range(len(movs))}
    # fragmentos "entre" movs estão em movs[i]['frags'] (os que vieram DEPOIS do mov i-1
    # e antes do mov i).
    # Para cada bloco de fragmentos entre mov(i-1) e mov(i): distribuir.
    for i in range(1, len(movs)):
        bloco = movs[i]["frags"]
        n = len(bloco)
        if n == 0:
            continue
        # blocos entre o movimento anterior (i-1) e este (i):
        # os primeiros pertencem ao anterior (continuação), os últimos a este (início)
        corte = (n + 1) // 2  # ceil(n/2) para o de cima
        for f in bloco[:n - corte]:
            descs[i - 1].append(f)
        for f in bloco[n - corte:]:
            descs[i].append(f)
    # fragmentos antes do primeiro movimento: do primeiro
    if movs and movs[0]["frags"]:
        descs[0] = movs[0]["frags"][:]
    # montar desc final
    for i, m in enumerate(movs):
        partes = []
        if m["desc_linha"]:
            partes.append(m["desc_linha"])
        partes.extend(descs[i])
        m["desc"] = " ".join(partes).strip()
    return movs


def validar(movs, saldo_ini, nome):
    print(f"\n=== {nome}: {len(movs)} movimentos ===")
    print(f"saldo inicial: {saldo_ini}")
    s = saldo_ini
    quebras = 0
    for i, m in enumerate(movs):
        esperado = round(s + m["valor"], 2)
        if abs(esperado - m["saldo"]) > 0.011:
            quebras += 1
            if quebras <= 10:
                print(f"  QUEBRA na linha {i}: {m['data']} {m['desc'][:50]!r} "
                      f"valor={m['valor']} saldo={m['saldo']} (esperado {esperado})")
        s = m["saldo"]
    print(f"saldo final calculado: {s}")
    print(f"quebras na cadeia: {quebras}")
    return quebras


todos = {}
for nome, arq in MESES.items():
    saldo_ini, movs = parse_arquivo(f"{BASE}/{arq}")
    movs = associar_descricoes(movs)
    q = validar(movs, saldo_ini, nome)
    todos[nome] = {"saldo_inicial": saldo_ini, "movs": movs, "quebras": q}

json.dump(todos, open(f"{BASE}/movimentos_extraidos.json", "w"),
          ensure_ascii=False, indent=1)
print("\nsalvo em movimentos_extraidos.json")

# amostra de descrições
print("\n=== amostra de descrições (julho, 12 primeiros) ===")
for m in todos["julho"]["movs"][:12]:
    print(f"  {m['data']} | {m['valor']:>9} | {m['desc']!r}")
