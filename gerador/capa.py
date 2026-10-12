# Ilustracao de capa estilo jogo (para a etiqueta do cartucho).
# Usa os personagens do jogo (gerador/exporta_arte.js) em pixel art ampliada.
import os, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTE = os.path.join(ROOT, 'cartucho', 'arte')
W, H = 1260, 1188          # area de arte da etiqueta (420x396 do modelo, 3x)
F = os.environ.get('FONTES', 'C:/Windows/Fonts/').rstrip('/\\') + '/'  # pasta das fontes (impact, arial...)
random.seed(7)

def spr(nome, escala):
    im = Image.open(os.path.join(ARTE, nome + '.png')).convert('RGBA')
    return im.resize((im.width * escala, im.height * escala), Image.NEAREST)

def contorno(im, cor=(28, 10, 4, 255), r=6):
    # contorno grosso em volta do sprite (estilo arte de capa)
    a = im.split()[3].filter(ImageFilter.MaxFilter(r * 2 + 1))
    base = Image.new('RGBA', im.size, cor); base.putalpha(a)
    base.alpha_composite(im)
    return base

capa = Image.new('RGBA', (W, H))
d = ImageDraw.Draw(capa)
# ---- raios de sol (fundo)
cx, cy = W // 2, 470
d.rectangle([0, 0, W, H], fill=(250, 166, 30, 255))
for k in range(28):
    a0 = 2 * math.pi * k / 28; a1 = a0 + math.pi / 28
    pts = [(cx, cy), (cx + 2000 * math.cos(a0), cy + 2000 * math.sin(a0)), (cx + 2000 * math.cos(a1), cy + 2000 * math.sin(a1))]
    d.polygon(pts, fill=(253, 200, 70, 255))
glow = Image.new('L', (W, H), 0); ImageDraw.Draw(glow).ellipse([cx - 330, cy - 330, cx + 330, cy + 330], fill=255)
glow = glow.filter(ImageFilter.GaussianBlur(90))
capa.paste(Image.new('RGBA', (W, H), (255, 244, 210, 255)), (0, 0), glow)

# ---- fachada da loja a noite (parte de baixo)
fach = Image.open(os.path.join(ARTE, 'fachada_noite.png')).convert('RGBA')
fach = fach.crop((0, 104, 256, 224))
fach = fach.resize((fach.width * 5, fach.height * 5), Image.NEAREST)
fach = fach.crop(((fach.width - W) // 2, 0, (fach.width - W) // 2 + W, fach.height))
m = Image.new('L', fach.size, 255); md = ImageDraw.Draw(m)
for y in range(80): md.line([(0, y), (W, y)], fill=int(255 * y / 80))
capa.paste(fach, (0, H - fach.height), m)
# escurece um pouco o fundo para os personagens saltarem
sombra = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ImageDraw.Draw(sombra).rectangle([0, H - fach.height, W, H], fill=(20, 8, 30, 70))
capa.alpha_composite(sombra)

# ---- moedas e pasteis voando
for nome, n, esc in [('moeda', 9, 6), ('pastel', 7, 7), ('estrela', 4, 5)]:
    for _ in range(n):
        im = contorno(spr(nome, esc), r=3).rotate(random.randint(-35, 35), Image.NEAREST, expand=True)
        x = random.randint(40, W - 140)
        y = random.randint(475, 700)
        if 420 < x < 780 and y > 450: x += 380 if x > 600 else -380
        capa.alpha_composite(im, (x, y))

# ---- personagens
def poe(nome, esc, x, y, flip=False):
    im = spr(nome, esc)
    if flip: im = im.transpose(Image.FLIP_LEFT_RIGHT)
    capa.alpha_composite(contorno(im, r=7), (x, y))

poe('mestre', 11, -20, H - 352, flip=False)
poe('cliente1', 11, W - 332, H - 352, flip=True)
poe('cliente2', 9, 250, H - 288)
poe('cliente0', 9, W - 540, H - 288, flip=True)
poe('fundador', 17, (W - 544) // 2, H - 544)
mas = contorno(spr('mascote', 9), r=7).rotate(-12, Image.NEAREST, expand=True)
capa.alpha_composite(mas, (W - 420, 560))
pst = contorno(spr('pastel', 12), r=6).rotate(18, Image.NEAREST, expand=True)
capa.alpha_composite(pst, (300, 560))

# ---- titulo 3D
def titulo(texto, tam, y, cor1, cor2, extr=18):
    f = ImageFont.truetype(F + 'impact.ttf', tam)
    tw = ImageDraw.Draw(capa).textlength(texto, font=f)
    x = (W - tw) / 2
    camada = Image.new('RGBA', (W, H)); dc = ImageDraw.Draw(camada)
    for k in range(extr, 0, -1):          # extrusao
        dc.text((x + k * 0.6, y + k), texto, font=f, fill=(120, 20, 0, 255), stroke_width=16, stroke_fill=(28, 10, 4, 255))
    dc.text((x, y), texto, font=f, fill=(0, 0, 0, 255), stroke_width=16, stroke_fill=(28, 10, 4, 255))
    capa.alpha_composite(camada)
    # preenchimento em degrade
    mask = Image.new('L', (W, H)); ImageDraw.Draw(mask).text((x, y), texto, font=f, fill=255)
    grad = Image.new('RGBA', (W, H))
    gd = ImageDraw.Draw(grad)
    bb = mask.getbbox()
    for yy in range(bb[1], bb[3] + 1):
        t = (yy - bb[1]) / max(1, bb[3] - bb[1])
        gd.line([(0, yy), (W, yy)], fill=tuple(int(a + (b - a) * t) for a, b in zip(cor1, cor2)) + (255,))
    capa.paste(grad, (0, 0), mask)
    # brilho
    hl = Image.new('L', (W, H)); ImageDraw.Draw(hl).text((x, y), texto, font=f, fill=110)
    hl2 = Image.new('L', (W, H)); ImageDraw.Draw(hl2).rectangle([0, bb[1], W, bb[1] + (bb[3] - bb[1]) // 3], fill=255)
    from PIL import ImageChops
    capa.paste(Image.new('RGBA', (W, H), (255, 255, 255, 255)), (0, 0), ImageChops.multiply(hl, hl2))

titulo('LOS', 150, 6, (255, 240, 140), (250, 150, 20), 12)
titulo('PASTELLES', 200, 128, (255, 236, 120), (232, 110, 10), 18)
# faixa "O IMPERIO DO PASTEL"
fy = 372
d = ImageDraw.Draw(capa)
d.polygon([(140, fy), (W - 140, fy), (W - 110, fy + 44), (W - 140, fy + 88), (140, fy + 88), (110, fy + 44)], fill=(218, 72, 4, 255), outline=(28, 10, 4, 255), width=8)
fr = ImageFont.truetype(F + 'impact.ttf', 66)
t = 'O IMPÉRIO DO PASTEL'
tw = d.textlength(t, font=fr)
d.text(((W - tw) / 2, fy + 6), t, font=fr, fill=(255, 248, 236, 255), stroke_width=5, stroke_fill=(28, 10, 4, 255))

capa.convert('RGB').save(os.path.join(ARTE, 'capa.png'))
print('capa ok')
