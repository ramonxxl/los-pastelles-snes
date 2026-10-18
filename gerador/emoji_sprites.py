# Sprites do jogo trocados por emojis (Twemoji, CC-BY 4.0) quando existe um
# equivalente perfeito: sabores e icones do expediente (ou por uma pixel art
# propria em arte_fonte/, quando o emoji nao serve, como o requeijao cremoso). Cada um
# vira 16x16 com o mesmo recorte e contorno escuro dos icones da loja
# (gerador/icones.py), nas cores da paleta fixa do sprite (no expediente as
# paletas 3-7 sao dos clientes).
# Entrada: gen/spal.json (paletas de sprite, de build.js). Saida: gen/emoji_spr.json
import colorsys, json, math, os
from collections import Counter
from PIL import Image
from icones import icone, ROOT, CONTORNO

# nome do sprite em gerador/arte.js -> (emoji, paleta de sprite)
EMOJIS = {
    'carne':    ('1f969', 0),   # corte de carne
    'queijo':   ('1f9c0', 0),
    'frango':   ('1f357', 0),   # coxa de frango
    'requeijao': ('arte_fonte/requeijao_cremoso.png', 0),   # bisnaga (pixel art propria, nao e emoji)
    'bacon':    ('1f953', 0),
    'cadeado':  ('1f512', 0),
    'raiva':    ('1f4a2', 0),
    'coracao':  ('2764', 0),
    'moeda':    ('1fa99', 0),
    'xis':      ('274c', 0),
    'estrela':  ('2b50', 0),
    'telefone': ('260e', 0),
    'monitor':  ('1f5a5', 0),
    'moto':     ('1f6f5', 0),
    'brilho':   ('2728', 1),
    'fogo':     ('1f525', 1),
    'mao':      ('1faf4', 0),   # mao com a palma para cima (o que o jogador segura)
    'continuar': ('25b6', 0),   # pausa: continuar (play)
    'casa':     ('1f3e0', 0),   # pausa: sair para o titulo (casa, como na loja)
    'calendario': ('1f4c5', 0),  # HUD: dia
    'relogio':  ('23f0', 0),    # HUD: hora
    'alvo':     ('1f3af', 0),   # HUD: meta do dia (reduzido a 8x8)
    'ajuda':    ('2753', 0),    # pausa: ajuda (interrogacao)
    'controle': ('1f3ae', 0),   # ajuda: aba CONTROLES
    'livro':    ('1f4d8', 0),   # ajuda: aba COMO JOGAR (livro azul)
    'grafico':  ('1f4c8', 0),   # ajuda: aba EVOLUCAO (a aba NIVEIS usa a estrela)
}

GEN = os.path.join(ROOT, 'gen')


def pixel_art(arq):
    # pixel art pronta (PNG): reduz por um fator inteiro ate caber em 14x14, cada
    # bloco vira a cor mais comum (sem o contorno, sem borrar), e refaz o contorno
    im = Image.open(os.path.join(ROOT, arq)).convert('RGBA')
    im = im.crop(im.getbbox())
    f = math.ceil(max(im.size) / 14)
    w, h = math.ceil(im.width / f), math.ceil(im.height / f)
    px = im.load()
    escuro = lambda c: sum(c[:3]) < 120
    red = {}
    for y in range(h):
        for x in range(w):
            cs = [px[x * f + i, y * f + j] for j in range(f) for i in range(f)
                  if x * f + i < im.width and y * f + j < im.height]
            cs = [c for c in cs if c[3] >= 110]
            if len(cs) * 2 < f * f:
                continue
            claros = [c[:3] for c in cs if not escuro(c)]
            if claros:
                red[x, y] = Counter(claros).most_common(1)[0][0]
    x0, y0 = (16 - w) // 2, (16 - h) // 2
    out = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); r = out.load()
    for (x, y), c in red.items():
        r[x0 + x, y0 + y] = c + (255,)
    for y in range(16):
        for x in range(16):
            if r[x, y][3] == 0 and any((x + dx - x0, y + dy - y0) in red for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                r[x, y] = CONTORNO + (255,)
    return out
saturada = lambda c: max(c[:3]) - min(c[:3]) > 0.3 * max(max(c[:3]), 1)


def dmatiz(a, b):
    ha = colorsys.rgb_to_hsv(*(v / 255 for v in a[:3]))[0]
    hb = colorsys.rgb_to_hsv(*(v / 255 for v in b[:3]))[0]
    d = abs(ha - hb)
    return min(d, 1 - d)


hexrgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def main():
    pals = json.load(open(os.path.join(GEN, 'spal.json')))
    saida = {}
    for nome, (cod, p) in EMOJIS.items():
        pal = [None] + [hexrgb(c) for c in pals[p][1:]]
        propria = cod.endswith('.png')
        im = pixel_art(cod) if propria else icone(cod)
        idx = []
        for y in range(16):
            for x in range(16):
                c = im.getpixel((x, y))
                if c[3] == 0:
                    idx.append(0); continue
                cand, dist = range(1, 16), lambda i: sum((a - b) ** 2 for a, b in zip(c[:3], pal[i]))
                if propria:
                    # pixel art: cor viva so vira cor viva do mesmo matiz, e cinza so
                    # vira cinza (senao o azul-marinho do rotulo cai no cinza ou no verde)
                    viva = saturada(c)
                    cand = [i for i in cand if saturada(pal[i]) == viva] or cand
                    if viva:
                        rgb = dist
                        dist = lambda i: rgb(i) + 40000 * dmatiz(c, pal[i]) ** 2
                idx.append(min(cand, key=dist))
        saida[nome] = idx
    json.dump(saida, open(os.path.join(GEN, 'emoji_spr.json'), 'w'))
    print('sprites de emoji:', len(saida))

if __name__ == '__main__':
    main()
