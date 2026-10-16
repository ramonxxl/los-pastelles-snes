# Base das animacoes grandes do expediente (BG2, paleta BG 5): paleta fixa
# compartilhada, cartao creme em volta, emojis reduzidos e saida em JSON para o
# build.js (gerador/anim.js transforma em tiles). Cada animacao e um script
# gerador/anim_<nome>.py que desenha os quadros-chave (RGBA), gera os
# intermediarios com gerador/morph.py e chama salva().
import json, os
from PIL import Image
from icones import baixa, ROOT

GEN = os.path.join(ROOT, 'gen')
# a area que muda (64x48 = 8x6 tiles) fica dentro do cartao (80x64, borda de 1 tile)
LARG, ALT = 64, 48
CART_L, CART_A = LARG + 16, ALT + 16

hexrgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
PALETA = [None,
          '#1C0A04',  # 1 contorno
          '#8C4A08',  # 2 moldura caramelo
          '#C8A870',  # 3 filete / sombra do creme
          '#FFF8EC',  # 4 fundo creme
          '#F3DFC0',  # 5 creme escuro
          '#F8E8B8',  # 6 massa clara
          '#E8C888',  # 7 massa
          '#C89858',  # 8 massa escura
          '#A06830',  # 9 borda/recheio
          '#D83828',  # 10 vermelho
          '#F8D040',  # 11 amarelo (brilho)
          '#E89838',  # 12 dourado
          '#C0C0D0',  # 13 metal claro
          '#707088',  # 14 metal escuro
          '#FFFFFF']  # 15 branco
RGB = [None] + [hexrgb(c) for c in PALETA[1:]]
C = lambda i: RGB[i] + (255,)


def perto(c):
    # cor da paleta mais proxima (nunca as do cartao: 2 e 3 so na moldura)
    return min((i for i in range(1, 16) if i not in (2,)),
               key=lambda i: sum((a - b) ** 2 for a, b in zip(c[:3], RGB[i])))


def emoji(cod, lado):
    """emoji reduzido para caber em lado x lado, com contorno, em cores da paleta."""
    im = Image.open(baixa(cod)).convert('RGBA')
    im = im.crop(im.getbbox())
    f = lado / max(im.size)
    im = im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS)
    w, h = im.width + 2, im.height + 2
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px, po = im.load(), out.load()
    cheio = lambda x, y: 0 <= x < im.width and 0 <= y < im.height and px[x, y][3] >= 110
    for y in range(h):
        for x in range(w):
            if cheio(x - 1, y - 1):
                po[x, y] = C(perto(px[x - 1, y - 1]))
            elif any(cheio(x - 1 + dx, y - 1 + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                po[x, y] = C(1)
    return out


def indices(img, fundo=4):
    """RGBA (LARG x ALT) sobre o fundo creme -> lista de indices da paleta."""
    px = img.load()
    out = []
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            out.append(fundo if c[3] < 128 else perto(c))
    return out


def cartao():
    """cartao creme 80x64 (indices); o miolo 64x48 fica 4 (creme) e e trocado pelos quadros."""
    w, h = CART_L, CART_A
    m = [[0] * w for _ in range(h)]

    def rrect(x0, y0, ww, hh, r, cor):
        for y in range(y0, y0 + hh):
            for x in range(x0, x0 + ww):
                dx = max(x0 + r - x, 0, x - (x0 + ww - 1 - r))
                dy = max(y0 + r - y, 0, y - (y0 + hh - 1 - r))
                if dx * dx + dy * dy <= r * r + r:
                    m[y][x] = cor
    rrect(0, 0, w, h, 6, 1)
    rrect(1, 1, w - 2, h - 2, 5, 2)
    rrect(3, 3, w - 6, h - 6, 3, 3)
    rrect(4, 4, w - 8, h - 8, 2, 5)
    rrect(6, 6, w - 12, h - 12, 1, 4)
    return [c for linha in m for c in linha]


def salva(nome, quadros, chaves, extra=None, ponto=(0, 0)):
    """quadros: imagens RGBA LARG x ALT (frente; o fundo vira creme). extra: um byte
    por quadro para o jogo (tabela Anim<Nome>Extra), ponto: (x, y) no miolo que o
    jogo usa junto (ANIM_<NOME>_PX/PY), por exemplo onde desenhar um sprite."""
    for q in quadros:
        assert q.size == (LARG, ALT), q.size
    dados = {'pal': PALETA[1:], 'cartao': cartao(), 'quadros': [indices(q) for q in quadros], 'chaves': chaves,
             'extra': extra or [0] * len(quadros), 'ponto': list(ponto)}
    json.dump(dados, open(os.path.join(GEN, 'anim_%s.json' % nome), 'w'))
    print('animacao %s: %d quadros, chaves %s' % (nome, len(quadros), chaves))
