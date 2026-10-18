# Animacao grande de erro (melhoria 11): o pastel que abriu no minijogo cai na
# lixeira. 5 quadros-chave (abriu -> caindo -> sobre a lata -> entrando -> tampa
# fechada com poeirinha), referencia de composicao em
# arte_fonte/lixeira/gemini_referencia.png (gerada no Gemini).
# A arte (pastel aberto, lata e tampa) e pixel art desenhada aqui nas cores da
# paleta compartilhada (gerador/anim_comum.py); a poeira e o emoji 💨 (Twemoji).
# Cada quadro-chave e uma lista de camadas com posicao, angulo e escala: os
# intermediarios interpolam essas transformacoes (o pastel cai girando e a tampa
# fecha girando na dobradica), o que fica melhor que o morph por forma
# (gerador/morph.py) para um objeto que atravessa o quadro.
# Saida: gen/anim_lixeira.json (salva() de anim_comum.py).
from PIL import Image
from anim_comum import LARG, ALT, C, emoji, salva

INTER = 3                                   # quadros entre cada par de chaves


def desenha(linhas, mapa):
    h, w = len(linhas), max(len(l) for l in linhas)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y, l in enumerate(linhas):
        for x, ch in enumerate(l):
            if ch in mapa:
                im.putpixel((x, y), C(mapa[ch]))
    return im


def contorno(im):
    # contorno escuro de 1 px em volta (depois de girar: girado junto fica serrilhado)
    w, h = im.size
    out = Image.new('RGBA', (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(im, (1, 1))
    px = out.load()
    cheio = [[px[x, y][3] > 0 for x in range(w + 2)] for y in range(h + 2)]
    for y in range(h + 2):
        for x in range(w + 2):
            if not cheio[y][x] and any(0 <= x + dx < w + 2 and 0 <= y + dy < h + 2 and cheio[y + dy][x + dx]
                                       for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                px[x, y] = C(1)
    return out


# pastel aberto: meia-lua dourada com a borda de garfo; a massa rachou e o
# recheio aparece e vaza pela abertura
PASTEL = [
    '.......aaaaaaaaaa.......',
    '....aaabbbbbbbbbbaaa....',
    '..aabbbbbbbbbbbbbbbbaa..',
    '.abbbbbbbbbbbbbbbbbbbba.',
    'abbbbbbbbbbbbbbbbbbbbbba',
    'abbbbbbbbbrrrrbbbbbbbbba',
    'abbbbbbbrRRRRRRrbbbbbbba',
    'cbcbcbcrRRsRRsRRrcbcbcbc',
    '.cbcbcrRRRRRRRRRRrcbcbc.',
    '..ccc..rRRsRRRRRr..ccc..',
    '........rRRRRsRr........',
    '.........rRRRRr.........',
    '...........rr...........',
]
PASTEL_MAPA = {'a': 11, 'b': 12, 'c': 8, 'r': 9, 'R': 9, 's': 10}   # recheio marrom com pedacinhos vermelhos

# lata de lixo com frisos; a tampa e separada (gira na dobradica)
LATA = [
    'aaaaaaaaaaaaaaaaaaaa',
    'abcbbcbbcbbcbbcbbcba',
    '.bcbbcbbcbbcbbcbbcb.',
    '.bcbbcbbcbbcbbcbbcb.',
    '.bcbbcbbcbbcbbcbbcb.',
    '.bcbbcbbcbbcbbcbbcb.',
    '.bcbbcbbcbbcbbcbbcb.',
    '.bcbbcbbcbbcbbcbbcb.',
    '.bcbbcbbcbbcbbcbbcb.',
    '.bcbbcbbcbbcbbcbbcb.',
    '..cccccccccccccccc..',
]
LATA_MAPA = {'a': 15, 'b': 13, 'c': 14}
TAMPA = [
    '........aa........',
    '.......abba.......',
    '..aaaaaaaaaaaaaa..',
    'abbbbbbbbbbbbbbbba',
    'cccccccccccccccccc',
]
TAMPA_MAPA = {'a': 15, 'b': 13, 'c': 14}
FARELO = ['ab', 'b.']
FARELO_MAPA = {'a': 12, 'b': 9}


def camadas():
    return {
        'pastel': desenha(PASTEL, PASTEL_MAPA),
        'lata': desenha(LATA, LATA_MAPA),
        'tampa': desenha(TAMPA, TAMPA_MAPA),
        'farelo': desenha(FARELO, FARELO_MAPA),
        'poeira': emoji('1f4a8', 13),          # ja vem com contorno
    }


# lata embaixo, no meio; o que fica "atras" (o pastel entrando) some abaixo da
# boca da lata
LATA_XY = (34, 41)
BOCA = LATA_XY[1] - 6                       # primeira linha do corpo da lata
TAMPA_ABERTA = (21, 26, 80)                 # em pe na borda esquerda da lata
TAMPA_FECHADA = (34, 33, 0)


# camadas de cada quadro-chave: nome -> (x, y, angulo, escala, atras). Camada
# que nao aparece num quadro fica com escala 0 (troca na metade do caminho)
def q(pastel, tampa, farelo=(0, 0, 0, 0, 0), poeira=(0, 0, 0, 0, 0)):
    return {'pastel': pastel, 'tampa': tampa, 'farelo': farelo, 'poeira': poeira}


CHAVES = [
    q((18, 9, 0, 1, 0), TAMPA_ABERTA + (1, 0), farelo=(21, 20, 0, 1, 0)),           # abriu
    q((28, 13, -35, 1, 0), TAMPA_ABERTA + (1, 0), farelo=(19, 24, 0, 1, 0)),        # caindo
    q((35, 18, -110, 1, 0), TAMPA_ABERTA + (1, 0)),                                 # sobre a lata
    q((35, 32, -160, 1, 1), (26, 29, 35, 1, 0)),                                    # entrando
    q((35, 46, -180, 1, 1), TAMPA_FECHADA + (1, 0), poeira=(48, 22, 0, 1, 0)),      # tampa fechada
]


def transforma(im, ang, esc, nome):
    if esc != 1:
        im = im.resize((max(1, round(im.width * esc)), max(1, round(im.height * esc))), Image.NEAREST)
    if ang:
        im = im.rotate(ang, resample=Image.NEAREST, expand=True)   # sem borrar: so pixels inteiros
    return im if nome == 'poeira' else contorno(im)


def monta(quadro, cam):
    out = Image.new('RGBA', (LARG, ALT), (0, 0, 0, 0))

    def cola(nome, x, y, ang, esc, atras=0):
        if esc < 0.5:
            return
        im = transforma(cam[nome], ang, esc, nome)
        if atras:                            # dentro da lata: so o que esta acima da boca
            px = im.load()
            y0 = y - im.height // 2
            for yy in range(im.height):
                if y0 + yy >= BOCA:
                    for xx in range(im.width):
                        px[xx, yy] = (0, 0, 0, 0)
        out.alpha_composite(im, (x - im.width // 2, y - im.height // 2))
    for n, l in quadro.items():
        if l[4]:
            cola(n, *l)
    cola('lata', LATA_XY[0], LATA_XY[1], 0, 1)
    for n in ('farelo', 'pastel', 'tampa', 'poeira'):
        if not quadro[n][4]:
            cola(n, *quadro[n])
    return out


def mistura(a, b, t):
    # interpola as camadas de dois quadros-chave; a que so existe num deles
    # troca na metade (como as cores do morph)
    out = {}
    for n in a:
        la, lb = a[n], b[n]
        if la[3] == 0 or lb[3] == 0:
            out[n] = la if t < 0.5 else lb
            continue
        out[n] = tuple(round(la[i] + (lb[i] - la[i]) * t) for i in range(4)) + (la[4] if t < 0.5 else lb[4],)
    return out


def main():
    cam = camadas()
    quadros, idx = [], []
    for a, b in zip(CHAVES, CHAVES[1:] + [None]):
        idx.append(len(quadros))
        quadros.append(monta(a, cam))
        if b is None:
            break
        for i in range(1, INTER + 1):
            quadros.append(monta(mistura(a, b, i / (INTER + 1)), cam))
    salva('lixeira', quadros, idx, ponto=LATA_XY)


if __name__ == '__main__':
    main()
