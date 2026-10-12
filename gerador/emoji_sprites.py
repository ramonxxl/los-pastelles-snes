# Sprites do jogo trocados por emojis (Twemoji, CC-BY 4.0) quando existe um
# equivalente perfeito: sabores e icones do expediente. Cada emoji vira 16x16 com
# o mesmo recorte e contorno escuro dos icones da loja (gerador/icones.py), nas
# cores da paleta fixa do sprite (no expediente as paletas 3-7 sao dos clientes).
# Entrada: gen/spal.json (paletas de sprite, de build.js). Saida: gen/emoji_spr.json
import json, os
from icones import icone, ROOT

# nome do sprite em gerador/arte.js -> (emoji, paleta de sprite)
EMOJIS = {
    'carne':    ('1f969', 0),   # corte de carne
    'queijo':   ('1f9c0', 0),
    'frango':   ('1f357', 0),   # coxa de frango
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
}

GEN = os.path.join(ROOT, 'gen')
hexrgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def main():
    pals = json.load(open(os.path.join(GEN, 'spal.json')))
    saida = {}
    for nome, (cod, p) in EMOJIS.items():
        pal = [None] + [hexrgb(c) for c in pals[p][1:]]
        im = icone(cod)
        idx = []
        for y in range(16):
            for x in range(16):
                c = im.getpixel((x, y))
                if c[3] == 0:
                    idx.append(0); continue
                idx.append(min(range(1, 16), key=lambda i: sum((a - b) ** 2 for a, b in zip(c[:3], pal[i]))))
        saida[nome] = idx
    json.dump(saida, open(os.path.join(GEN, 'emoji_spr.json'), 'w'))
    print('sprites de emoji:', len(saida))

if __name__ == '__main__':
    main()
