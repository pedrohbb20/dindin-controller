#!/usr/bin/env python3
"""
Prepara os ícones do Dindin Controller a partir da logo original (JPEG com
fundo xadrez "falso transparente").

Abordagem v2 (o xadrez aparece TAMBÉM dentro do escudo e nos buracos das
letras, então a limpeza é global por cor, não por preenchimento de borda):
1. Remove TODOS os pixels de fundo xadrez (claros e neutros), inclusive os
   internos.
2. Suaviza as bordas (blur leve no alfa).
3. Recorta o emblema (escudo) e a assinatura (texto) no primeiro vão largo.
4. Gera: logo horizontal limpa, emblema, e variações do ícone quadrado
   (transparente, placa branca, placa azul-marinho) + tamanhos Android/Linux.

Uso: python3 logo_preparar.py [--debug]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

BASE = "/home/pedro/Documentos/Projetos/dindin_controller/assets/logo"
ENTRADA_JPEG = os.path.join(BASE, "logo-original.jpg")
ENTRADA_TRANSPARENTE = os.path.join(BASE, "logo-mestre-v2.png")


def carregar_entrada(caminho):
    """Se a arte já tem transparência real, usa direto; senão, limpa o xadrez."""
    img = Image.open(caminho)
    if img.mode in ("RGBA", "LA"):
        a = img.getchannel("A")
        h = a.histogram()
        if h[0] > (img.width * img.height) * 0.05:
            print("arte com transparência real: limpeza dispensada")
            return img.convert("RGBA")
    return remover_fundo_xadrez(img)


def remover_fundo_xadrez(img: Image.Image) -> Image.Image:
    """RGBA com o fundo xadrez removido em TODA a imagem (interno e externo)."""
    img = img.convert("RGB")
    largura, altura = img.size
    px = img.load()
    alfa = Image.new("L", (largura, altura), 255)
    ap = alfa.load()
    for y in range(altura):
        for x in range(largura):
            r, g, b = px[x, y]
            maxc, minc = max(r, g, b), min(r, g, b)
            if (maxc - minc) <= 22 and minc >= 150:
                ap[x, y] = 0
    alfa = alfa.filter(ImageFilter.GaussianBlur(0.7))
    rgba = img.convert("RGBA")
    rgba.putalpha(alfa)
    return rgba


def bbox_conteudo(img: Image.Image):
    return img.getbbox()


def vaos_de_colunas(img: Image.Image):
    """Lista os vãos de colunas sem conteúdo (para achar emblema | texto)."""
    alfa = img.getchannel("A")
    largura, altura = img.size
    dados = alfa.load()
    vaos = []
    inicio = None
    for x in range(largura):
        tem = False
        for y in range(0, altura, 2):
            if dados[x, y] > 12:
                tem = True
                break
        if not tem and inicio is None:
            inicio = x
        elif tem and inicio is not None:
            vaos.append((inicio, x - 1))
            inicio = None
    if inicio is not None:
        vaos.append((inicio, largura - 1))
    return vaos


def separar_emblema_texto(img: Image.Image, debug=False):
    """Escolhe o primeiro vão largo (>=12px) na faixa central da imagem."""
    largura = img.width
    vaos = vaos_de_colunas(img)
    if debug:
        print("vãos de colunas:", vaos)
    # No nosso caso o vão emblema|texto é pequeno (o bico da seta chega perto
    # do "D"): aceita vãos de 4px ou mais e usa o PRIMEIRO da faixa central.
    faixa_min, faixa_max = int(largura * 0.30), int(largura * 0.60)
    candidatos = [v for v in vaos
                  if v[0] >= faixa_min and v[1] <= faixa_max
                  and (v[1] - v[0]) >= 4]
    if candidatos:
        escolhido = candidatos[0]
        if debug:
            print("vão escolhido:", escolhido)
        return escolhido
    # sem vão largo: usa o maior vão que encontrar na faixa
    meio = [v for v in vaos if v[0] >= faixa_min and v[1] <= faixa_max]
    if meio:
        escolhido = max(meio, key=lambda v: v[1] - v[0])
        if debug:
            print("vão de reserva:", escolhido)
        return escolhido
    if debug:
        print("nenhum vão; cortando no meio")
    return (largura // 2, largura // 2)


def recortar(img, caixa, margem=6):
    x0, y0, x1, y1 = caixa
    x0 = max(0, x0 - margem)
    y0 = max(0, y0 - margem)
    x1 = min(img.width, x1 + margem)
    y1 = min(img.height, y1 + margem)
    return img.crop((x0, y0, x1, y1))


def quadrado(master: int, emblema: Image.Image, fundo, raio_frac, ocupacao):
    tela = Image.new("RGBA", (master, master), (0, 0, 0, 0))
    if fundo is not None:
        d = ImageDraw.Draw(tela)
        raio = int(master * raio_frac)
        d.rounded_rectangle([0, 0, master - 1, master - 1], radius=raio, fill=fundo)
    lado = int(master * ocupacao)
    proporcao = emblema.width / emblema.height
    if proporcao >= 1:
        w, h = lado, int(lado / proporcao)
    else:
        h, w = lado, int(lado * proporcao)
    e = emblema.resize((w, h), Image.Resampling.LANCZOS)
    pos = ((master - w) // 2, (master - h) // 2)
    tela.paste(e, pos, e)
    return tela


def main():
    debug = "--debug" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        entrada = args[0]
    elif os.path.exists(ENTRADA_TRANSPARENTE):
        entrada = ENTRADA_TRANSPARENTE
    else:
        entrada = ENTRADA_JPEG
    original = Image.open(entrada)
    print("entrada:", entrada, original.size, original.mode)

    limpa = carregar_entrada(entrada)
    caixa = bbox_conteudo(limpa)
    print("caixa do conteúdo:", caixa)
    limpa = recortar(limpa, caixa, margem=10)
    limpa.save(os.path.join(BASE, "logo-horizontal.png"))
    print("logo-horizontal.png:", limpa.size)

    corte = separar_emblema_texto(limpa, debug=debug)
    print("corte emblema|texto:", corte)
    emblema = limpa.crop((0, 0, corte[0], limpa.height))
    emblema = recortar(emblema, bbox_conteudo(emblema), margem=4)
    emblema.save(os.path.join(BASE, "emblema.png"))
    print("emblema.png:", emblema.size)

    # Variações do ícone quadrado (1024 de base)
    marinho = (11, 37, 69, 255)  # azul-marinho do logo
    variacoes = {
        "icone-a-transparente.png": quadrado(1024, emblema, None, 0.0, 0.88),
        "icone-b-branco.png": quadrado(1024, emblema, (255, 255, 255, 255), 0.23, 0.70),
        "icone-c-marinho.png": quadrado(1024, emblema, marinho, 0.23, 0.70),
    }
    for nome, im in variacoes.items():
        im.save(os.path.join(BASE, nome))
        print(nome, im.size)

    for nome in variacoes:
        raiz = nome.replace("icone-", "tam-").replace(".png", "")
        for tam in (48, 72, 96, 144, 192, 256, 512):
            im = Image.open(os.path.join(BASE, nome)).resize(
                (tam, tam), Image.Resampling.LANCZOS)
            im.save(os.path.join(BASE, f"{raiz}-{tam}.png"))
    print("tamanhos exportados")


if __name__ == "__main__":
    main()
