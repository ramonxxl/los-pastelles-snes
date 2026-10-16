# Morph entre quadros-chave de pixel art (reutilizavel pelas animacoes grandes:
# montagem do pastel, pastel indo para a lixeira...).
#
# Cada quadro e uma imagem PIL RGBA (frente sobre fundo transparente), todas do
# mesmo tamanho. morph(a, b, n) devolve os n quadros intermediarios de a ate b:
#  - forma: interpola o campo de distancia com sinal das duas silhuetas (alfa >=
#    128), entao a silhueta "derrete" de uma para a outra em vez de piscar;
#  - cor: vem de a ate a metade do caminho e de b depois (pontilhado=True mistura
#    as duas com a matriz de Bayer 4x4, na proporcao t); se o quadro escolhido
#    nao cobre o pixel, usa o pixel mais proximo dentro da silhueta dele.
#  - contorno: se os quadros tem um contorno de cor unica (contorno=(r,g,b,a)),
#    ele nao e copiado para dentro (a silhueta que cresce puxaria a cor do
#    contorno): a cor vem do pixel mais proximo que nao e contorno, e a borda da
#    silhueta nova e redesenhada com o contorno.
# Sem numpy (as imagens sao pequenas): distancias por chanfro 3-4 em duas passadas.
from PIL import Image

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
INF = 1 << 30


def _chanfro(w, h, semente):
    # distancia (chanfro 3-4) ate o pixel-semente mais proximo e quem ele e
    d = [INF] * (w * h)
    q = [None] * (w * h)
    for i in range(w * h):
        if semente[i]:
            d[i] = 0
            q[i] = (i % w, i // w)
    viz1 = ((-1, -1, 4), (0, -1, 3), (1, -1, 4), (-1, 0, 3))
    viz2 = ((1, 1, 4), (0, 1, 3), (-1, 1, 4), (1, 0, 3))
    for viz, ys, xs in ((viz1, range(h), range(w)), (viz2, range(h - 1, -1, -1), range(w - 1, -1, -1))):
        for y in ys:
            for x in xs:
                i = y * w + x
                for dx, dy, c in viz:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if d[j] + c < d[i]:
                            d[i] = d[j] + c
                            q[i] = q[j]
    return d, q


def _campo(img, contorno):
    w, h = img.size
    px = img.load()
    dentro = [px[i % w, i // w][3] >= 128 for i in range(w * h)]
    cor = [dentro[i] and px[i % w, i // w] != contorno for i in range(w * h)]
    d_in, _ = _chanfro(w, h, dentro)                 # fora: distancia ate a silhueta
    d_out, _ = _chanfro(w, h, [not v for v in dentro])
    _, perto = _chanfro(w, h, cor)                   # pixel de cor (nao contorno) mais proximo
    sdf = [-d_out[i] if dentro[i] else d_in[i] for i in range(w * h)]
    return cor, sdf, perto


def morph(a, b, n, pontilhado=False, contorno=None):
    """n quadros entre a e b (sem incluir a nem b)."""
    w, h = a.size
    assert b.size == a.size
    pa, pb = a.load(), b.load()
    ina, sa, na = _campo(a, contorno)
    inb, sb, nb = _campo(b, contorno)
    out = []
    for k in range(1, n + 1):
        t = k / (n + 1)
        im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        po = im.load()
        for y in range(h):
            for x in range(w):
                i = y * w + x
                if (1 - t) * sa[i] + t * sb[i] > 0:
                    continue
                usa_b = (t * 16 > BAYER[y & 3][x & 3]) if pontilhado else t >= 0.5
                if usa_b and nb[i] is None:
                    usa_b = False
                if not usa_b and na[i] is None:
                    usa_b = True
                if usa_b:
                    sx, sy = (x, y) if inb[i] else nb[i]
                    po[x, y] = pb[sx, sy]
                else:
                    sx, sy = (x, y) if ina[i] else na[i]
                    po[x, y] = pa[sx, sy]
        if contorno is not None:
            cheio = [[po[x, y][3] >= 128 for x in range(w)] for y in range(h)]
            for y in range(h):
                for x in range(w):
                    if cheio[y][x] and any(not (0 <= x + dx < w and 0 <= y + dy < h) or not cheio[y + dy][x + dx]
                                           for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                        po[x, y] = contorno
        out.append(im)
    return out


def sequencia(chaves, n, pontilhado=False, contorno=None):
    """Quadros-chave com n intermediarios entre cada par. Devolve (quadros, indices
    dos quadros-chave na lista)."""
    quadros, idx = [chaves[0]], [0]
    for a, b in zip(chaves, chaves[1:]):
        quadros += morph(a, b, n, pontilhado, contorno)
        quadros.append(b)
        idx.append(len(quadros) - 1)
    return quadros, idx
