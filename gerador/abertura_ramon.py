"""Abertura "RAMON": homenagem as aberturas da Konami (ferramenta de uso unico).

Le o que gerador/abertura_extrai.lua gravou em gen/abertura_rom/ (a abertura do
Sunset Riders) e escreve arte_fonte/abertura/abertura.json, que o build usa
(gerador/abertura.js):
  - logo: o emblema trocado pelo R de arte_fonte/abertura/emblema_r.png (emblema_r,
    com o sombreamento das fitas originais) e, no lugar de KONAMI, RAMON na
    mesma fonte. A, M, O e N sao copiados das letras originais (com o contorno claro
    em volta); o R usa a haste e a perna do K com um bojo desenhado aqui (R_TOPO), no
    mesmo sombreamento por faixas de linha. Sem o (R) da marca registrada.
  - feixe/faiscas: a coluna de cores do laser e os 4 tiles 16x16 da faisca na ponta.
  - paletas: as cores 0..63 (paletas 0..3) a cada quadro em que mudam (q = quadros
    desde o 136 do original): contorno azul, enchimento com brilho, fundo branco e
    escurecimento.
Tambem grava arte_fonte/abertura/ramon.png (previa da logo pronta) e, com o
ffmpeg (libgme), sounds/abertura-ramon.mp3: o jingle tocado a partir do retrato do
SPC700 (jingle.spc) tirado logo depois de o jogo pedir a musica.
"""
import json, os, sys
from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ENT = os.path.join(RAIZ, 'gen', 'abertura_rom')
SAI = os.path.join(RAIZ, 'arte_fonte', 'abertura')
Q0 = 136            # primeiro quadro gravado em cg.bin
Q_LOGO = 400        # quadro da CGRAM usada na previa (logo pronta, fundo branco)
LETRAS = '.' + '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/'  # indice de cor 0..63

vram = {q: open(os.path.join(ENT, f'vram{q}.bin'), 'rb').read() for q in (150, 400)}
cg = open(os.path.join(ENT, 'cg.bin'), 'rb').read()


def px4(v, base, t, x, y):
    o = base + t * 32
    s = 7 - x
    b = (v[o + 2 * y], v[o + 2 * y + 1], v[o + 16 + 2 * y], v[o + 17 + 2 * y])
    return sum(((b[i] >> s) & 1) << i for i in range(4))


def camada(v, mapa, chr_, largura, t16, x, y):
    """indice de cor (0..255, 0 = transparente) do pixel (x, y) do mapa de um BG 4bpp
    (mapa e chr_ em bytes; largura 1 ou 2 telas; t16 = tiles 16x16)"""
    ts = 16 if t16 else 8
    tx, ty = x // ts, y // ts
    e = mapa + ((tx // 32) % largura) * 2048 + ((ty % 32) * 32 + tx % 32) * 2
    w = v[e] | v[e + 1] << 8
    t, pal = w & 1023, (w >> 10) & 7
    px, py = x % ts, y % ts
    if w & 0x4000: px = ts - 1 - px
    if w & 0x8000: py = ts - 1 - py
    if t16: t += (px // 8) + (py // 8) * 16
    c = px4(v, chr_, t & 1023, px % 8, py % 8)
    return pal * 16 + c if c else 0


# ---------------------------------------------------------------- logo original (BG2)
# BG2 no original: mapa $1000 (palavras), tiles $2000, 64x32, tiles 8x8, VOFS = -1
W, H = 256, 224
img = [[camada(vram[400], 0x2000, 0x4000, 2, False, x, y) for x in range(W)] for y in range(H)]

# ---------------------------------------------------------------- letras
Y0, Y1 = 170, 210                   # faixa do texto (o emblema acaba antes)
corpo = {(x, y) for y in range(Y0, Y1) for x in range(W) if img[y][x] not in (0, 2)}   # 2 = contorno claro
comp, rot = [], {}
for p in sorted(corpo):
    if p in rot: continue
    c = len(comp); comp.append([]); pilha = [p]; rot[p] = c
    while pilha:
        q = pilha.pop(); comp[c].append(q); x, y = q
        for r in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if r in corpo and r not in rot: rot[r] = c; pilha.append(r)
comp.sort(key=lambda c: min(p[0] for p in c))
assert len(comp) >= 6, 'nao achei as 6 letras de KONAMI'


def letra(c):
    """{(x, y): indice} da letra, com o contorno claro vizinho"""
    d = {p: img[p[1]][p[0]] for p in c}
    for (x, y) in c:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q not in d and img[q[1]][q[0]] == 2: d[q] = 2
    return d


L = {n: letra(c) for n, c in zip('KONAMI', comp[:6])}

# R: do K ficam as linhas 187+ (haste, juncao e perna); as de cima sao o bojo.
# (x inicial, pixels: indices de cor em hexa; 2 = contorno claro, 5 = contorno escuro,
# 3/4 = brilho da borda, 6..E = faixas do degrade, espaco = transparente)
R_TOPO = {
    176: (67, "22222222222222222"),
    177: (67, "24333333333333332"),
    178: (67, "25eeeeeeeeeeeeeee32"),
    179: (66, "25eeeeeeeeeeeeeeeed32"),
    180: (66, "25ddddddddddddddddd32"),
    181: (66, "25ddddddddddddddddd32"),
    182: (65, "25cccccc22222225cccccc32"),
    183: (65, "25ccccc32    25cccccc32"),
    184: (64, "25bbbbbb2    25bbbbbb32"),
    185: (64, "25bbbbb322222225bbbbb32"),
    186: (64, "25aaaaaaaaaaaaaaaaa32"),
}
R = {p: v for p, v in L['K'].items() if p[1] >= 187}
for y, (x0, s) in R_TOPO.items():
    for i, ch in enumerate(s):
        if ch != ' ': R[(x0 + i, y)] = int(ch, 16)
L['R'] = R


def folga(a, b, dx):
    """menor distancia horizontal entre os corpos de a e de b (b deslocado dx)"""
    ca = {p for p, v in a.items() if v != 2}
    cb = {(x + dx, y) for (x, y), v in b.items() if v != 2}
    g = 999
    for y in range(Y0, Y1):
        xa = [x for (x, yy) in ca if yy == y]
        xb = [x for (x, yy) in cb if yy == y]
        if xa and xb: g = min(g, min(xb) - max(xa))
    return g


# o original tem folga 2 entre letras vizinhas (corpo, contorno claro, corpo)
FOLGA = min(folga(L[a], L[b], 0) for a, b in ('KO', 'ON', 'NA', 'AM'))
txt = {}
for n in 'RAMON':
    d = L[n]
    dx = 0
    if txt:
        dx = -100
        while folga(txt, d, dx) < FOLGA: dx += 1
    for (x, y), v in d.items():
        q = (x + dx, y)
        if v != 2: txt[q] = v
        elif q not in txt: txt[q] = 2

# centraliza no centro de KONAMI (sem o (R))
kx = [p[0] for c in comp[:6] for p in c]
rx = [p[0] for p in txt]
sh = round((min(kx) + max(kx)) / 2 - (min(rx) + max(rx)) / 2)
for y in range(Y0, Y1):
    img[y] = [0] * W
for (x, y), v in txt.items():
    img[y][x + sh] = v

# ---------------------------------------------------------------- emblema em R
# O emblema vira o R desenhado em arte_fonte/abertura/emblema_r.png: a parte amarela
# (haste e bojo) fica no BG2 com a paleta 1, a perna vermelha com a paleta 2 (o build
# a desenha com sprites, atras do BG2, porque ela encontra o amarelo numa curva e cada
# tile do BG so tem uma paleta). Da imagem so saem as mascaras; o sombreamento e o das
# fitas originais, por linha: chanfro escuro a esquerda de cada corrida, a cor da faixa
# da linha (a fita da mesma cor, esticada na altura) e borda clara a direita; realce
# nas bordas de cima e sombra nas de baixo. Assim o contorno azul e o brilho que anda
# pelas faixas na troca de paleta continuam certos.
EM_Y0, EM_H = 33, 134       # topo e altura do R na tela (o texto comeca na linha 176)
CHANFRO, BORDA = 4, 4       # larguras do chanfro escuro e da borda clara


def emblema_r(img):
    import colorsys
    from collections import deque
    fonte = Image.open(os.path.join(SAI, 'emblema_r.png')).convert('RGB')
    fx = [x for x in range(fonte.width) for y in range(0, fonte.height, 2) if min(fonte.getpixel((x, y))) < 200]
    fy = [y for y in range(fonte.height) for x in range(0, fonte.width, 2) if min(fonte.getpixel((x, y))) < 200]
    fonte = fonte.crop((min(fx), min(fy), max(fx) + 1, max(fy) + 1))
    lw = round(fonte.width * EM_H / fonte.height)
    pq = fonte.resize((lw, EM_H), Image.LANCZOS)
    # tinta (fora do branco do fundo) e sementes pela cor: vermelho = perna, amarelo = R
    tipo = {}
    for y in range(EM_H):
        for x in range(lw):
            r, g, b = pq.getpixel((x, y))
            if min(r, g, b) > 205: continue
            h, sat, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            h *= 360
            perna = (h < 22 or h > 330) and sat > 0.5 and y > EM_H * 0.45   # (o alto do bojo tem um traco avermelhado)
            tipo[(x, y)] = 'V' if perna else 'A' if h >= 38 else '?'
    # o laranja das bordas vai para a semente mais proxima (andando pela tinta)
    fila = deque(p for p, t in tipo.items() if t != '?')
    while fila:
        x, y = fila.popleft()
        for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if tipo.get(q) == '?': tipo[q] = tipo[(x, y)]; fila.append(q)
    # pontinhos soltos (menos de 6 pixels da mesma cor) somem
    vistos = set()
    for p in list(tipo):
        if p in vistos or p not in tipo: continue
        comp, pilha = [p], [p]
        vistos.add(p)
        while pilha:
            x, y = pilha.pop()
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q not in vistos and tipo.get(q) == tipo[p]: vistos.add(q); comp.append(q); pilha.append(q)
        if len(comp) < 6:
            for q in comp: del tipo[q]

    def faixas(p):
        """cor da faixa de cada linha da fita da paleta p (sem as linhas da borda)"""
        f = []
        for y in range(Y0):
            xs = [x for x in range(W) if img[y][x] and img[y][x] >> 4 == p]
            if xs: f.append(img[y][xs[len(xs) // 2]])
        return f[3:-3]

    fxs = {p: faixas(p) for p in (1, 2)}
    x0 = round(W / 2 - lw / 2)
    for y in range(Y0): img[y] = [0] * W
    for cor, p in (('A', 1), ('V', 2)):
        m = {q for q, t in tipo.items() if t == cor}
        fx_ = fxs[p]
        ys = [q[1] for q in m]
        ya, yb = min(ys), max(ys)
        base = p << 4
        for y in range(ya, yb + 1):
            meio = fx_[round((y - ya) * (len(fx_) - 1) / max(1, yb - ya))]
            xs = sorted(x for (x, yy) in m if yy == y)
            corridas, ini = [], None
            for i, x in enumerate(xs):
                if ini is None: ini = x
                if i + 1 == len(xs) or xs[i + 1] != x + 1: corridas.append((ini, x)); ini = None
            for a, b in corridas:
                n = b - a + 1
                ce = min(CHANFRO, n // 3)
                cd = min(BORDA, (n - ce) // 2)
                px = [base + 5] * ce + [meio] * (n - ce - cd) + [base + 2] * cd
                if ce: px[0] = base + 4
                if cd > 1: px[-1] = base + 3
                for i, v in enumerate(px):
                    x, yy = a + i, y
                    if (x, yy - 1) not in m: v = base + 2          # realce (borda de cima)
                    elif (x, yy - 2) not in m and v == meio: v = base + 3
                    elif (x, yy + 1) not in m: v = base + 5        # sombra (borda de baixo)
                    img[EM_Y0 + yy][x0 + x] = v
    assert EM_Y0 + EM_H <= Y0


emblema_r(img)

# ---------------------------------------------------------------- cortina (BG1)
# BG1 no original: mapa $0000, tiles $2000, tiles 16x16. Linhas 16..31 do mapa: o
# laser ate x = 255 e a faisca em x = 256..271; preto (cor 1) nas linhas 32..255.
# A faisca troca de tile a cada 2 quadros: 16x16 numeros 6, 8, $A e $C, paleta 3.
feixe = [camada(vram[150], 0, 0x4000, 2, True, 0, 16 + y) for y in range(16)]
faiscas = [[[(px4(vram[150], 0x4000, t + (x // 8) + (y // 8) * 16, x % 8, y % 8) or -48) + 48
             for x in range(16)] for y in range(16)] for t in (6, 8, 10, 12)]
assert all(camada(vram[150], 0, 0x4000, 2, True, x, y) == 1 for x in (0, 300, 511) for y in (32, 255))

# ---------------------------------------------------------------- paletas
n = len(cg) // 512
estados = []
for i in range(n):
    c = [cg[i * 512 + 2 * k] | cg[i * 512 + 2 * k + 1] << 8 for k in range(64)]
    c = ' '.join('%04x' % v for v in c)        # BGR555, 4 digitos hexa por cor
    if not estados or estados[-1]['cores'] != c:
        estados.append({'q': i, 'cores': c})

# ---------------------------------------------------------------- saida
ys = [y for y in range(H) if any(img[y])]
xs = [x for x in range(W) if any(img[y][x] for y in range(H))]
x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
os.makedirs(SAI, exist_ok=True)
saida = {
    'descricao': 'Abertura RAMON (homenagem a Konami): gerada por gerador/abertura_ramon.py',
    'logo': {'x': x0, 'y': y0,
             'linhas': [''.join(LETRAS[img[y][x]] for x in range(x0, x1 + 1)) for y in range(y0, y1 + 1)]},
    'feixe': ' '.join(LETRAS[v] for v in feixe),
    'faiscas': [[''.join(LETRAS[v] for v in linha) for linha in f] for f in faiscas],
    'paletas': estados,
}
with open(os.path.join(SAI, 'abertura.json'), 'w', encoding='utf-8') as f:
    json.dump(saida, f, indent=1)
    f.write('\n')

k = (Q_LOGO - Q0) * 512
def rgb(i):
    v = cg[k + 2 * i] | cg[k + 2 * i + 1] << 8
    return ((v & 31) * 255 // 31, ((v >> 5) & 31) * 255 // 31, ((v >> 10) & 31) * 255 // 31)
prev = Image.new('RGB', (W, H), rgb(0))
for y in range(H):
    for x in range(W):
        if img[y][x]: prev.putpixel((x, y), rgb(img[y][x]))
prev.save(os.path.join(SAI, 'ramon.png'))
# jingle: o retrato do SPC700 tocado pelo ffmpeg (libgme), sem o silencio do comeco
import subprocess
spc = os.path.join(ENT, 'jingle.spc')
mp3 = os.path.join(RAIZ, 'sounds', 'abertura-ramon.mp3')
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', spc, '-t', '4',
                '-af', 'silenceremove=start_periods=1:start_threshold=-60dB',
                '-c:a', 'libmp3lame', '-q:a', '0', mp3], check=True)
print(f'abertura: logo {x1 - x0 + 1}x{y1 - y0 + 1} em ({x0},{y0}), {len(estados)} estados de paleta')
