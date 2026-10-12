# Tela de titulo: logo (PNG) reduzida no topo + cartao do menu embaixo, em imagem
# indexada 256x224 com 15 cores para o SNES. O fundo de fora do emblema e do cartao
# fica transparente (indice 0): por tras aparece o xadrez animado (BG2).
# Saida: gen/logo_idx.bin (256*224 bytes, indices 0..15) e gen/logo_pal.json
import json, os, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = [f for f in os.listdir(ROOT) if f.lower().endswith('.png') and 'pastelles' in f.lower()]
if not src:
    sys.exit('logo nao encontrada')
im = Image.open(os.path.join(ROOT, src[0])).convert('RGB')

# recorta pelo conteudo (tudo que difere do fundo creme)
bg = im.getpixel((5, 5))
W, H = im.size
px = im.load()
xs, ys = [], []
for y in range(0, H, 2):
    for x in range(0, W, 2):
        r, g, b = px[x, y]
        if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > 60:
            xs.append(x); ys.append(y)
box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
im = im.crop(box)

# logo menor, no topo (o menu fica num cartao embaixo)
ALT = 124
w = round(im.width * ALT / im.height)
im = im.resize((w, ALT), Image.LANCZOS)
canvas = Image.new('RGB', (256, 224), bg)
canvas.paste(im, ((256 - w) // 2, 3))

# achata tons proximos do fundo creme para nao gastar cores da paleta
cp = canvas.load()
perto = lambda c: abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) < 36
for y in range(224):
    for x in range(256):
        if perto(cp[x, y]):
            cp[x, y] = bg

# transparente = fundo creme ligado a borda (o creme de dentro do emblema fica)
fora = Image.new('L', (256, 224), 0)
fp = fora.load()
pilha = [(x, y) for x in range(256) for y in (0, 223)] + [(x, y) for y in range(224) for x in (0, 255)]
while pilha:
    x, y = pilha.pop()
    if 0 <= x < 256 and 0 <= y < 224 and not fp[x, y] and cp[x, y] == bg:
        fp[x, y] = 255
        pilha += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

# cartao do menu (mesmo visual das caixas: contorno escuro, moldura caramelo, filete)
CARTAO = (40, 133, 216, 219)          # x0, y0, x1, y1 (o jogo escreve o menu dentro)
ESCURO, CARAMELO, FILETE = (56, 24, 11), (153, 94, 18), (220, 190, 150)
d = ImageDraw.Draw(canvas)
x0, y0, x1, y1 = CARTAO
d.rounded_rectangle((x0 + 3, y0 + 3, x1 + 3, y1 + 3), 9, fill=ESCURO)        # sombra
d.rounded_rectangle((x0, y0, x1, y1), 9, fill=ESCURO)
d.rounded_rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), 8, fill=CARAMELO)
d.rounded_rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), 6, fill=FILETE)
d.rounded_rectangle((x0 + 4, y0 + 4, x1 - 4, y1 - 4), 5, fill=bg)
cartao = Image.new('L', (256, 224), 0)
ImageDraw.Draw(cartao).rounded_rectangle((x0, y0, x1 + 3, y1 + 3), 9, fill=255)

q = canvas.quantize(colors=15, method=Image.MEDIANCUT, kmeans=4, dither=Image.NONE)
pal = q.getpalette()[:45]
cores = ['#%02X%02X%02X' % tuple(pal[i * 3:i * 3 + 3]) for i in range(15)]
qi = q.tobytes()
cm = cartao.tobytes(); fm = fora.tobytes()
idx = bytes(0 if (fm[i] and not cm[i]) else qi[i] + 1 for i in range(256 * 224))
os.makedirs(os.path.join(ROOT, 'gen'), exist_ok=True)
open(os.path.join(ROOT, 'gen', 'logo_idx.bin'), 'wb').write(idx)
json.dump({'cores': cores, 'cartao': list(CARTAO)}, open(os.path.join(ROOT, 'gen', 'logo_pal.json'), 'w'))
print('logo:', w, 'x', ALT, 'cores', cores)
