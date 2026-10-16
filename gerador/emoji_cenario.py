# Elementos do cenario da loja feitos a partir de emojis (Twemoji, CC-BY 4.0):
# janela, vaso de planta, quadro, cidade, sacolas, livros, pasteis da vitrine
# e flores. Cada um e reduzido ao tamanho pedido, ganha o contorno escuro
# do cenario e e quantizado na paleta do bairro (gerador/arte.js: shopPal).
# Entrada: gen/shoppal.json (paletas dos 5 bairros, de build.js).
# Saida: gen/emoji_cen.json  { "nome_bairro": [w, h, [indices...]] }
import colorsys, json, os
from PIL import Image
from icones import baixa, ROOT

# nome -> (emoji, largura, altura, modo). modo 'fit' mantem a proporcao (centrado)
# e 'fill' recorta para preencher a caixa inteira
ELEMENTOS = {
    'janela':   ('1fa9f', 44, 40, 'fill'),   # janela (bairro inicial)
    'vitrine':  ('1fa9f', 52, 48, 'fill'),   # janela grande (centro comercial)
    'planta':   ('1fab4', 18, 18, 'fit'),    # vaso de planta no peitoril
    'sacolas':  ('1f6cd', 20, 20, 'fit'),    # sacolas de compras (centro comercial)
    'quadro':   ('1f5bc', 44, 36, 'fill'),   # quadro (residencial)
    'livros':   ('1f4da', 18, 18, 'fit'),    # livros (universitaria)
    'cidade':   ('1f3d9', 52, 42, 'fill'),   # vista da cidade na janela (empresarial)
    'pastel':   ('1f95f', 12, 8, 'fit'),     # pastel na vitrine do balcao (reforma 1)
    'flores':   ('1f33b', 18, 22, 'fit'),    # girassol nos vasos (reforma 2)
}
CONTORNO = 1                # cor 1 do cenario (quase preto)
PROIBIDAS = {12}            # cor 12 pisca no jogo (oleo da fritadeira)
# so estes podem usar as cores do bairro (6 = parede, 15 = detalhe); os outros
# ficariam com cores diferentes em cada bairro
COM_BAIRRO = {'vitrine', 'planta', 'quadro', 'cidade'}

GEN = os.path.join(ROOT, 'gen')
hexrgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
saturada = lambda c: max(c) - min(c) > 0.3 * max(max(c), 1)


def matiz(c):
    return colorsys.rgb_to_hsv(*(v / 255 for v in c))[0]


def reduz(cod, w, h, modo):
    im = Image.open(baixa(cod)).convert('RGBA')
    im = im.crop(im.getbbox())
    iw, ih = w - 2, h - 2       # 1 px de contorno em volta
    if modo == 'fill':
        # recorta o centro na proporcao da caixa
        r = iw / ih
        if im.width / im.height > r:
            nw = round(im.height * r); x0 = (im.width - nw) // 2
            im = im.crop((x0, 0, x0 + nw, im.height))
        else:
            nh = round(im.width / r); y0 = (im.height - nh) // 2
            im = im.crop((0, y0, im.width, y0 + nh))
        im = im.resize((iw, ih), Image.LANCZOS)
        out = Image.new('RGBA', (w, h), (0, 0, 0, 0)); out.paste(im, (1, 1))
    else:
        f = min(iw / im.width, ih / im.height)
        nw, nh = max(1, round(im.width * f)), max(1, round(im.height * f))
        im = im.resize((nw, nh), Image.LANCZOS)
        out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        out.paste(im, ((w - nw) // 2, h - 1 - nh))      # apoiado embaixo
    return out


def quantiza(im, pal, bairro):
    w, h = im.size
    px = im.load()
    cheio = [[px[x, y][3] >= 110 for x in range(w)] for y in range(h)]
    cand = [i for i in range(1, 16) if i not in PROIBIDAS and (bairro or i not in (6, 15))]
    idx = [0] * (w * h)
    for y in range(h):
        for x in range(w):
            if cheio[y][x]:
                c = px[x, y][:3]
                viva = saturada(c)
                def dist(i):
                    d = sum((a - b) ** 2 for a, b in zip(c, pal[i]))
                    if viva and saturada(pal[i]):
                        dm = abs(matiz(c) - matiz(pal[i])); dm = min(dm, 1 - dm)
                        d += 80000 * dm * dm
                    elif viva != saturada(pal[i]):
                        d += 9000
                    return d
                idx[y * w + x] = min(cand, key=dist)
            elif any(0 <= x + dx < w and 0 <= y + dy < h and cheio[y + dy][x + dx]
                     for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                idx[y * w + x] = CONTORNO
    return idx


def main():
    pals = json.load(open(os.path.join(GEN, 'shoppal.json')))
    saida = {}
    for nome, (cod, w, h, modo) in ELEMENTOS.items():
        im = reduz(cod, w, h, modo)
        for v, p in enumerate(pals):
            pal = [None] + [hexrgb(c) for c in p[1:]]
            saida[f'{nome}_{v}'] = [w, h, quantiza(im, pal, nome in COM_BAIRRO)]
    json.dump(saida, open(os.path.join(GEN, 'emoji_cen.json'), 'w'))
    print('elementos de emoji no cenario:', len(ELEMENTOS))


if __name__ == '__main__':
    main()
