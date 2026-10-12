# Icones dos menus (16x16) a partir de emojis Twemoji (CC-BY 4.0, Twitter/X)
# Baixa os PNG uma vez (cache em arte_fonte/emoji), reduz para 14x14, poe contorno
# escuro (16x16), reduz cores para 4 paletas de 15 cores e grava os tiles 4bpp.
# Saidas: gen/icon_tiles.bin (6 linhas de 16 tiles), gen/icon_pal.bin (4 paletas),
#         gen/preview/icones.png
import os, sys, urllib.request
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, 'arte_fonte', 'emoji')
GEN = os.path.join(ROOT, 'gen')
URL = 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/{}.png'

# ordem = itens da loja (S_0..S_19) e depois os dos menus (20..23); cabem 24
ICONES = [
    '1f4e6',  # ingredientes: caixa
    '1f373',  # fritadeira: frigideira
    '1fa91',  # balcao: cadeira
    '1f3f7',  # promocao: etiqueta
    '1f9d1-200d-1f373',  # atendente: cozinheiro
    '1f4e3',  # publicidade: megafone
    '1f3ea',  # nova loja
    '1f91d',  # franquia: aperto de mao
    '1f4bb',  # computador
    '1f6f5',  # motoboy: lambreta
    '2744',   # freezer: floco de neve
    '1f32c',  # ar-condicionado: vento
    '1f3b5',  # musica
    '1f455',  # uniforme: camiseta
    '1f528',  # reforma: martelo
    '1f4b0',  # preco: saco de dinheiro
    '1f5fa',  # mapa
    '1f3c6',  # trofeus
    '1f3e0',  # voltar ao menu: casa
    '2600',   # abrir a loja: sol (novo dia)
    # menus (titulo e opcoes): ICO_* em src/ui.s
    '2728',   # 20 novo jogo: brilhos
    '1f4be',  # 21 continuar: disquete
    '2699',   # 22 opcoes: engrenagem
    '1f525',  # 23 dificuldade: fogo
]
CONTORNO = (40, 20, 12)


def baixa(cod):
    os.makedirs(CACHE, exist_ok=True)
    arq = os.path.join(CACHE, cod + '.png')
    if not os.path.exists(arq):
        urllib.request.urlretrieve(URL.format(cod), arq)
    return arq


def snes(c):
    # 15 bits por cor (5 por canal)
    return tuple((v >> 3) << 3 for v in c)


def icone(cod):
    im = Image.open(baixa(cod)).convert('RGBA')
    # recorta a area util e reduz para caber em 14x14
    bb = im.getbbox(); im = im.crop(bb)
    lado = max(im.size)
    q = Image.new('RGBA', (lado, lado), (0, 0, 0, 0))
    q.paste(im, ((lado - im.width) // 2, (lado - im.height) // 2))
    pq = q.resize((14, 14), Image.LANCZOS)
    out = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    out.paste(pq, (1, 1))
    px = out.load()
    cheio = [[px[x, y][3] >= 110 for x in range(16)] for y in range(16)]
    res = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); r = res.load()
    for y in range(16):
        for x in range(16):
            if cheio[y][x]:
                c = px[x, y]; r[x, y] = (c[0], c[1], c[2], 255)
            elif any(0 <= x + dx < 16 and 0 <= y + dy < 16 and cheio[y + dy][x + dx]
                     for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                r[x, y] = CONTORNO + (255,)
    return res


def paleta_de(imgs):
    # junta os pixels opacos dos icones do grupo e reduz para 14 cores + contorno
    tira = Image.new('RGB', (16 * len(imgs), 16), CONTORNO)
    for i, im in enumerate(imgs):
        rgb = Image.new('RGB', (16, 16), CONTORNO); rgb.paste(im, (0, 0), im)
        tira.paste(rgb, (16 * i, 0))
    pq = tira.quantize(14, method=Image.MEDIANCUT)
    cores = [tuple(pq.getpalette()[i * 3:i * 3 + 3]) for i in range(14)]
    return [snes(CONTORNO)] + [snes(c) for c in cores]


def perto(c, pal):
    return min(range(len(pal)), key=lambda i: sum((a - b) ** 2 for a, b in zip(c, pal[i])))


def enc4(pix):
    # pix: 64 indices -> tile 4bpp do SNES (32 bytes)
    b = bytearray(32)
    for y in range(8):
        for x in range(8):
            v = pix[y * 8 + x]
            for p in range(4):
                if v >> p & 1:
                    b[(p >> 1) * 16 + y * 2 + (p & 1)] |= 0x80 >> x
    return bytes(b)


def main():
    imgs = [icone(c) for c in ICONES]
    # 4 grupos de icones com paleta propria (ordem fixa: o jogo usa i % 4... nao:
    # o grupo vai numa tabela gerada junto)
    grupos = [[], [], [], []]
    # distribui por cor dominante: agrupa icones parecidos
    def media(im):
        px = [im.getpixel((x, y)) for x in range(16) for y in range(16) if im.getpixel((x, y))[3]]
        return tuple(sum(p[k] for p in px) // len(px) for k in range(3))
    ordem = sorted(range(len(imgs)), key=lambda i: (lambda m: (max(m) - min(m) < 40, m[0] - m[2]))(media(imgs[i])))
    for j, i in enumerate(ordem):
        grupos[min(3, j * 4 // len(imgs))].append(i)
    pals, grupo_de = [], [0] * len(imgs)
    for g, idx in enumerate(grupos):
        pals.append(paleta_de([imgs[i] for i in idx]))
        for i in idx: grupo_de[i] = g
    # folha 128 x 48 (16 x 6 tiles): icone i em (i % 8)*16, (i // 8)*16
    folha = [[0] * 128 for _ in range(48)]
    prev = Image.new('RGBA', (128, 48), (232, 224, 200, 255))
    for i, im in enumerate(imgs):
        pal = pals[grupo_de[i]]
        ox, oy = (i % 8) * 16, (i // 8) * 16
        for y in range(16):
            for x in range(16):
                c = im.getpixel((x, y))
                if c[3]:
                    k = 1 if c[:3] == CONTORNO else 2 + perto(c[:3], pal[1:])
                    k = min(k, 15)
                    folha[oy + y][ox + x] = k
                    prev.putpixel((ox + x, oy + y), pal[k - 1] + (255,))
    tiles = bytearray()
    for ty in range(6):
        for tx in range(16):
            tiles += enc4([folha[ty * 8 + y][tx * 8 + x] for y in range(8) for x in range(8)])
    open(os.path.join(GEN, 'icon_tiles.bin'), 'wb').write(tiles)
    palb = bytearray()
    for pal in pals:
        cores = [(0, 0, 0)] + pal + [(0, 0, 0)] * (15 - len(pal))
        for c in cores[:16]:
            v = (c[0] >> 3) | ((c[1] >> 3) << 5) | ((c[2] >> 3) << 10)
            palb += bytes([v & 255, v >> 8])
    open(os.path.join(GEN, 'icon_pal.bin'), 'wb').write(palb)
    # tabela: paleta (3..6) de cada icone
    open(os.path.join(GEN, 'icon_pal.inc'), 'w').write(
        '; gerado por gerador/icones.py\nIconPalTab: .byte ' + ', '.join(str(3 + g) for g in grupo_de) + '\n')
    os.makedirs(os.path.join(GEN, 'preview'), exist_ok=True)
    prev.resize((512, 192), Image.NEAREST).save(os.path.join(GEN, 'preview', 'icones.png'))
    print('icones:', len(imgs), 'grupos', [len(g) for g in grupos])


if __name__ == '__main__':
    main()
