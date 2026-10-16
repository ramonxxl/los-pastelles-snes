# Emojis do mapa da expansao (Twemoji, CC-BY 4.0): predios, obras, arvores.
# Cada um e reduzido para caber em lado x lado (com 1 px de contorno escuro, como
# os icones da loja) e gravado em RGBA; gerador/mapa.js compoe o mapa e reduz as
# cores para as paletas do BG.
# Saida: gen/emoji_mapa.json  { nome: { w, h, px: [r, g, b, a, ...] } }
import json, os
from PIL import Image
from icones import baixa, ROOT, CONTORNO

# nome -> (emoji, lado em pixels)
EMOJIS = {
    'casa':      ('1f3e1', 40),   # loja original (bairro inicial): casa com jardim
    'comercial': ('1f3ec', 36),   # centro comercial: loja de departamentos
    'residencial': ('1f3d8', 36), # regiao residencial: casas
    'faculdade': ('1f3eb', 26),   # area universitaria: escola
    'franquia':  ('1f3ea', 22),   # franquia em outra cidade: loja
    'placa':     ('1faa7', 14),   # franquia a venda
    'guindaste': ('1f3d7', 22),   # terreno em obra
    'cavalete':  ('1f6a7', 14),
    'trator':    ('1f69c', 16),
    'arvore':    ('1f333', 16),
    'pinheiro':  ('1f332', 16),
    'arvore_p':  ('1f333', 12),
}


def reduz(cod, lado):
    im = Image.open(baixa(cod)).convert('RGBA')
    im = im.crop(im.getbbox())
    f = (lado - 2) / max(im.size)
    w, h = max(1, round(im.width * f)), max(1, round(im.height * f))
    pq = im.resize((w, h), Image.LANCZOS)
    out = Image.new('RGBA', (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(pq, (1, 1))
    px = out.load()
    W, H = out.size
    cheio = [[px[x, y][3] >= 110 for x in range(W)] for y in range(H)]
    res = []
    for y in range(H):
        for x in range(W):
            if cheio[y][x]:
                c = px[x, y]; res += [c[0], c[1], c[2], 255]
            elif any(0 <= x + dx < W and 0 <= y + dy < H and cheio[y + dy][x + dx]
                     for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                res += list(CONTORNO) + [255]
            else:
                res += [0, 0, 0, 0]
    return {'w': W, 'h': H, 'px': res}


def main():
    saida = {nome: reduz(cod, lado) for nome, (cod, lado) in EMOJIS.items()}
    json.dump(saida, open(os.path.join(ROOT, 'gen', 'emoji_mapa.json'), 'w'))
    print('emojis do mapa:', len(saida))


if __name__ == '__main__':
    main()
