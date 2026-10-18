# Animacao grande da montagem do pastel (minijogo): 5 quadros-chave
# (massa -> recheio -> dobra -> fechamento com o garfo -> pastel pronto) com
# intermediarios por morph. O recheio de verdade e o emoji do sabor, desenhado
# por cima como sprite (MgaSprites em src/banco28.s); aqui fica so o monte.
# Saida: gen/anim_montagem.json (gerador/anim_comum.py).
from PIL import Image
from anim_comum import LARG, ALT, C, emoji, salva
from morph import sequencia

INTER = 2          # quadros entre cada par de chaves
# folha de massa e linha da dobra (o pastel fechado ocupa a metade de baixo)
X0, X1, Y0, Y1 = 6, 57, 4, 41
DOBRA = (Y0 + Y1 + 1) // 2


def tela():
    return Image.new('RGBA', (LARG, ALT), (0, 0, 0, 0))


def ret(im, x0, y0, x1, y1, cor, r=0):
    px = im.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = max(x0 + r - x, 0, x - (x1 - r))
            dy = max(y0 + r - y, 0, y - (y1 - r))
            if dx * dx + dy * dy <= r * r:
                px[x, y] = C(cor)


def contorno(im, cor=1):
    px = im.load()
    w, h = im.size
    cheio = [[px[x, y][3] >= 128 for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if not cheio[y][x] and any(0 <= x + dx < w and 0 <= y + dy < h and cheio[y + dy][x + dx]
                                       for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                px[x, y] = C(cor)


def cola(im, el, x, y):
    im.alpha_composite(el, (x, y))


def massa(im, x0, y0, x1, y1, r=3):
    # massa aberta: clara, sombra embaixo/direita e uns pontinhos de farinha
    ret(im, x0, y0, x1, y1, 7, r)
    ret(im, x0, y0, x1 - 2, y1 - 2, 6, r)
    px = im.load()
    for i, (fx, fy) in enumerate(((9, 7), (23, 11), (41, 6), (15, 25), (47, 21), (31, 31), (51, 33), (11, 35))):
        x, y = x0 + fx * (x1 - x0) // 52, y0 + fy * (y1 - y0) // 38
        if px[x, y][3]:
            px[x, y] = C(15 if i & 1 else 8)


def borda_garfo(im, x0, y0, x1, y1, lados):
    # marquinhas do garfo nas bordas abertas (esq, baixo, dir)
    px = im.load()
    if 'e' in lados:
        for y in range(y0 + 2, y1 - 1, 2):
            px[x0 + 1, y] = C(9); px[x0 + 2, y] = C(9)
    if 'd' in lados:
        for y in range(y0 + 2, y1 - 1, 2):
            px[x1 - 1, y] = C(9); px[x1 - 2, y] = C(9)
    if 'b' in lados:
        for x in range(x0 + 2, x1 - 1, 2):
            px[x, y1 - 1] = C(9); px[x, y1 - 2] = C(9)


def fechado(im, x0, y0, x1, y1, lados):
    # pastel fechado: estufado no meio, borda escura, brilho em cima
    ret(im, x0, y0, x1, y1, 8, 3)
    ret(im, x0 + 1, y0, x1 - 1, y1 - 1, 7, 3)
    ret(im, x0 + 3, y0 + 2, x1 - 3, y1 - 4, 6, 4)
    px = im.load()
    for x in range(x0 + 6, x1 - 8):
        px[x, y0 + 3] = C(15)
    borda_garfo(im, x0, y0, x1, y1, lados)


def monte(im, cx, cy):
    # monte de recheio (o emoji do sabor vai por cima)
    ret(im, cx - 11, cy - 6, cx + 11, cy + 6, 9, 6)
    ret(im, cx - 9, cy - 5, cx + 8, cy + 3, 12, 5)


def chaves():
    k = []
    # 0 massa aberta
    a = tela(); massa(a, X0, Y0, X1, Y1); contorno(a); k.append(a)
    # 1 recheio na metade de baixo
    b = tela(); massa(b, X0, Y0, X1, Y1); monte(b, 32, DOBRA + 9); contorno(b); k.append(b)
    # 2 dobra: a metade de cima levantada (vista por baixo, mais escura e em perspectiva)
    c = tela()
    massa(c, X0, DOBRA - 1, X1, Y1)
    monte(c, 32, DOBRA + 9)
    for i, y in enumerate(range(DOBRA - 12, DOBRA)):
        recuo = 3 - i // 4
        ret(c, X0 - recuo, y, X1 + recuo, y, 8 if i < 3 else 7)
    ret(c, X0 - 3, DOBRA - 12, X1 + 3, DOBRA - 12, 9)
    contorno(c); k.append(c)
    # 3 fechando com o garfo (marcas so na esquerda e embaixo ate o garfo)
    d = tela()
    fechado(d, X0, DOBRA, X1, Y1, 'e')
    px = d.load()
    for x in range(X0 + 2, X0 + 30, 2):
        px[x, Y1 - 1] = C(9); px[x, Y1 - 2] = C(9)
    contorno(d)
    garfo = emoji('1f374', 20).rotate(-30, expand=True)
    cola(d, garfo, 31, Y1 - 24)
    k.append(d)
    # 4 pronto: maior, no meio do cartao, todas as bordas marcadas e brilhos
    e = tela()
    fechado(e, X0 - 2, 12, X1 + 2, 37, 'ebd')
    contorno(e)
    brilho = emoji('2728', 11)
    cola(e, brilho, 49, 1)
    cola(e, emoji('2728', 8), 2, 33)
    k.append(e)
    return k


def main():
    quadros, idx = sequencia(chaves(), INTER, contorno=C(1))
    # extra = 1 nos quadros em que o monte de recheio aparece: o jogo desenha o
    # emoji do sabor por cima dele (ponto = centro do monte)
    cx, cy = 32, DOBRA + 9
    extra = [1 if q.getpixel((cx, cy)) == C(12) else 0 for q in quadros]
    salva('montagem', quadros, idx, extra, (cx, cy))


if __name__ == '__main__':
    main()
