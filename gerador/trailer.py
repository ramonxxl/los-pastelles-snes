# Monta o trailer de lancamento (MP4 1920x1080) com cenas reais do jogo,
# musica sintetizada do jogo e narracao.
# Antes: gravar quadros (teste/grava_*.lua), python gerador/trailer_musica.py e trailer_voz.py
import os, math, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import imageio_ffmpeg

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, 'trailer')
Q = os.path.join(TR, 'quadros2')
AU = os.path.join(TR, 'audio')
FF = imageio_ffmpeg.get_ffmpeg_exe()
W, H, FPS, RATE = 1920, 1080, 30, 32000
F = os.environ.get('FONTES', 'C:/Windows/Fonts/').rstrip('/\\') + '/'  # pasta das fontes (impact, arial...)
LARANJA, CREME, MARROM, VERMELHO = (250, 166, 30), (253, 241, 224), (58, 26, 12), (218, 72, 4)

def fonte(n, t): return ImageFont.truetype(F + n, t)

# ------------------------------------------------------------------ quadros gravados
def indice(nome):
    out = []
    for ln in open(os.path.join(Q, nome + '.txt')):
        n, ef, st, t, dv, moto, ring, mg = map(int, ln.split()); out.append((n, st, t, dv, moto))
    return out
IA, IB = indice('a'), indice('b')
def sel(idx, nome, cond, maxn=None):
    fs = [os.path.join(Q, f'{nome}_{n:05d}.png') for (n, st, t, dv, moto) in idx if cond(st, t, dv, moto)]
    return fs[:maxn] if maxn else fs

CLIPES = {
    'rua':      sel(IA, 'a', lambda st, t, dv, mo: st == 1),
    'dia1':     sel(IA, 'a', lambda st, t, dv, mo: st == 4 and 150 < t),
    'lotado':   sel(IB, 'b', lambda st, t, dv, mo: st == 4 and t > 300),
    'entregas': sel(IB, 'b', lambda st, t, dv, mo: st == 4 and t > 900)[100:],
    'reforma':  sel(IB, 'b', lambda st, t, dv, mo: st == 9)[:55] + sel(IB, 'b', lambda st, t, dv, mo: st == 4 and t > 2400),
    'gestao':   sel(IB, 'b', lambda st, t, dv, mo: st == 5)[20:] + sel(IB, 'b', lambda st, t, dv, mo: st == 6)[:110]
                + sel(IB, 'b', lambda st, t, dv, mo: st == 12),
}

def dur_mp3(arq):
    p = subprocess.run([FF, '-i', arq], capture_output=True, text=True)
    for ln in p.stderr.splitlines():
        if 'Duration' in ln:
            h, m, s = ln.split('Duration:')[1].split(',')[0].strip().split(':'); return int(h) * 3600 + int(m) * 60 + float(s)
    return 3.0

# ------------------------------------------------------------------ elementos visuais
def fundo(t, escuro=False):
    im = Image.new('RGB', (W, H), (232, 134, 7) if not escuro else (30, 12, 6))
    d = ImageDraw.Draw(im)
    cx, cy = W // 2, H // 2
    a0 = t * 0.15
    cor = (250, 176, 50) if not escuro else (60, 26, 10)
    for k in range(24):
        a = a0 + 2 * math.pi * k / 24; b = a + math.pi / 24
        d.polygon([(cx, cy), (cx + 2400 * math.cos(a), cy + 2400 * math.sin(a)), (cx + 2400 * math.cos(b), cy + 2400 * math.sin(b))], fill=cor)
    return im

def tela_jogo(arq, escala=4):
    g = Image.open(arq).convert('RGB').resize((256 * escala, 224 * escala), Image.NEAREST)
    b = 10
    q = Image.new('RGB', (g.width + 2 * b, g.height + 2 * b), CREME); q.paste(g, (b, b))
    q2 = Image.new('RGB', (q.width + 8, q.height + 8), MARROM); q2.paste(q, (4, 4))
    return q2

def sombra(base, im, xy, r=18):
    s = Image.new('RGBA', (im.width + 80, im.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(s).rectangle([40, 40, 40 + im.width, 40 + im.height], fill=(0, 0, 0, 140))
    s = s.filter(ImageFilter.GaussianBlur(r))
    base.paste(s, (xy[0] - 40 + 14, xy[1] - 40 + 18), s)
    base.paste(im, xy)

def texto_capa(d, xy, txt, tam, cor=(255, 230, 110), larg=None, borda=10, centro=False):
    f = fonte('impact.ttf', tam)
    x, y = xy
    if centro:
        x = (larg or W) / 2 - d.textlength(txt, font=f) / 2 + (xy[0] if larg else 0)
    for k in range(8, 0, -1):
        d.text((x + k * 0.6, y + k), txt, font=f, fill=(120, 20, 0), stroke_width=borda, stroke_fill=(28, 10, 4))
    d.text((x, y), txt, font=f, fill=cor, stroke_width=borda, stroke_fill=(28, 10, 4))

def entra(t, dur=0.35):
    # 0..1 suave
    x = max(0.0, min(1.0, t / dur)); return 1 - (1 - x) ** 3

CAPA = Image.open(os.path.join(ROOT, 'cartucho', 'arte', 'capa.png')).convert('RGB')
ETIQ = Image.open(os.path.join(ROOT, 'cartucho', 'etiqueta_formato_classico.png')).convert('RGBA')
MASC = Image.open(os.path.join(ROOT, 'cartucho', 'arte', 'mascote.png')).convert('RGBA')
MASC = MASC.resize((MASC.width * 8, MASC.height * 8), Image.NEAREST)

def cartucho(larg=900):
    # cartucho cinza estilo SNES com a etiqueta
    h = int(larg * 0.72)
    c = Image.new('RGBA', (larg, h), (0, 0, 0, 0)); d = ImageDraw.Draw(c)
    d.rounded_rectangle([0, 0, larg - 1, h - 1], radius=40, fill=(150, 150, 156), outline=(70, 70, 76), width=6)
    for k in range(6):
        y = h - 70 + k * 10
        d.line([(60, y), (larg - 60, y)], fill=(110, 110, 116), width=4)
    e = ETIQ.copy(); e.thumbnail((int(larg * 0.84), int(h * 0.72)))
    c.alpha_composite(e, ((larg - e.width) // 2, 40))
    return c

# ------------------------------------------------------------------ cenas
def cena_jogo(clipe, legenda, sub=None, inicio=0):
    fs = CLIPES[clipe]
    def quadro(i, t):
        im = fundo(t)
        g = tela_jogo(fs[(inicio + i) % len(fs)], 4)
        sombra(im, g, (70, (H - g.height) // 2))
        d = ImageDraw.Draw(im)
        k = entra(t)
        x0 = int(1150 + (1 - k) * 600)
        y = 300
        for ln in legenda.split('\n'):
            texto_capa(d, (x0, y), ln, 96)
            y += 120
        if sub:
            d.text((x0 + 6, y + 20), sub, font=fonte('seguibl.ttf', 40), fill=CREME, stroke_width=4, stroke_fill=MARROM)
        m = MASC.rotate(math.sin(t * 6) * 6, Image.NEAREST, expand=True)
        im.paste(m, (W - m.width - 40, H - m.height - 20 + int(abs(math.sin(t * 5)) * -20)), m)
        return im
    return quadro

def cena_rua():
    fs = CLIPES['rua']
    def quadro(i, t):
        im = Image.new('RGB', (W, H), (8, 8, 20))
        g = Image.open(fs[min(i, len(fs) - 1)]).convert('RGB').resize((1152, 1008), Image.NEAREST)
        im.paste(g, ((W - 1152) // 2, 36))
        # vinheta escura nas bordas
        return im
    return quadro

def cena_capa():
    def quadro(i, t):
        im = fundo(t)
        k = entra(t, 0.6)
        esc = 1.25 - 0.25 * k
        alt = int(980 * esc)
        cap = CAPA.resize((int(CAPA.width * alt / CAPA.height), alt), Image.LANCZOS)
        q = Image.new('RGB', (cap.width + 16, cap.height + 16), CREME); q.paste(cap, (8, 8))
        sombra(im, q, ((W - q.width) // 2, (H - q.height) // 2))
        if t > 1.2:
            d = ImageDraw.Draw(im)
            f = fonte('seguibl.ttf', 46)
            txt = 'NOVO JOGO PARA SUPER NINTENDO'
            tw = d.textlength(txt, font=f)
            d.rounded_rectangle([(W - tw) / 2 - 30, H - 120, (W + tw) / 2 + 30, H - 40], radius=20, fill=VERMELHO, outline=MARROM, width=6)
            d.text(((W - tw) / 2, H - 112), txt, font=f, fill=CREME)
        return im
    return quadro

def cena_recursos():
    itens = ['CARTUCHO DE VERDADE', 'SALVA COM BATERIA', '3 JOGOS SALVOS', 'MÚSICA 16 BITS', 'PARA SUPER NINTENDO']
    cart = cartucho(820)
    def quadro(i, t):
        im = fundo(t, escuro=True)
        y0 = int(130 + math.sin(t * 2) * 12)
        im.paste(cart, (80, y0), cart)
        d = ImageDraw.Draw(im)
        for k, it in enumerate(itens):
            tt = t - 0.35 * k
            if tt <= 0: continue
            x = int(1000 + (1 - entra(tt)) * 500)
            y = 200 + k * 140
            d.ellipse([x, y + 18, x + 50, y + 68], fill=LARANJA, outline=CREME, width=4)
            texto_capa(d, (x + 80, y), it, 72, cor=CREME, borda=6)
        return im
    return quadro

def cena_final():
    cart = cartucho(760)
    def quadro(i, t):
        im = fundo(t)
        d = ImageDraw.Draw(im)
        cap = CAPA.resize((int(CAPA.width * 620 / CAPA.height), 620), Image.LANCZOS)
        q = Image.new('RGB', (cap.width + 14, cap.height + 14), CREME); q.paste(cap, (7, 7))
        sombra(im, q, (110, 90))
        im.paste(cart, (W - cart.width - 90, 150 + int(math.sin(t * 2.2) * 14)), cart)
        k = entra(t - 0.3, 0.5)
        if t > 0.3:
            esc = 0.6 + 0.4 * k
            texto_capa(d, (0, 760), 'GARANTA JÁ O SEU!', int(130 * esc), centro=True)
            if t > 1.0:
                f = fonte('seguibl.ttf', 52)
                txt = 'lospastelles.com.br'
                tw = d.textlength(txt, font=f)
                d.rounded_rectangle([(W - tw) / 2 - 40, 935, (W + tw) / 2 + 40, 1020], radius=24, fill=MARROM)
                d.text(((W - tw) / 2, 942), txt, font=f, fill=LARANJA)
        return im
    return quadro

ROTEIRO = [
    ('v1', cena_rua(), 0.8),
    ('v2', cena_capa(), 0.8),
    ('v3', cena_jogo('dia1', 'FECHE, FRITE\nE ENTREGUE!', 'tire o pastel no ponto verde'), 0.6),
    ('v4', cena_jogo('lotado', 'CLIENTES DE\nTODO TIPO!', 'crianças, idosos, turistas e misteriosos'), 0.5),
    ('v5', cena_jogo('entregas', 'ENTREGAS:\nTELEFONE E APP!', 'o motoboy sai buzinando'), 0.5),
    ('v6', cena_jogo('reforma', 'REFORME E\nEXPANDA!', '5 bairros e franquias'), 0.5),
    ('v7', cena_jogo('gestao', '16 TROFÉUS E\nMUITO MAIS!', 'loja, equipamentos e lucro'), 0.5),
    ('v8', cena_recursos(), 0.6),
    ('v9', cena_final(), 2.5),
]

def mp3_para_np(arq):
    raw = subprocess.run([FF, '-i', arq, '-f', 's16le', '-ac', '1', '-ar', str(RATE), '-'], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768

def wav_np(arq):
    with wave.open(arq) as w: return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768

def main():
    # duracoes
    cenas = []
    for voz, fn, extra in ROTEIRO:
        dv = dur_mp3(os.path.join(AU, voz + '.mp3'))
        cenas.append((voz, fn, dv + extra))
    total = sum(c[2] for c in cenas)
    n_total = int(total * FPS)
    # ----- audio
    a = np.zeros(int(total * RATE) + RATE)
    musA, musB, fim = wav_np(os.path.join(AU, 'titulo.wav')), wav_np(os.path.join(AU, 'dia.wav')), wav_np(os.path.join(AU, 'vitoria.wav'))
    t_capa_fim = cenas[0][2] + cenas[1][2]
    nA = int(t_capa_fim * RATE)
    a[:nA] += musA[:nA] * 0.30
    t_final = total - cenas[-1][2]
    nB0, nB1 = nA, int(t_final * RATE)
    seg = np.tile(musB, 3)[: nB1 - nB0]
    rampa = np.minimum(1, np.arange(len(seg)) / (0.4 * RATE))
    a[nB0:nB1] += seg * 0.26 * rampa
    a[nB1:nB1 + len(fim)] += fim[: len(a) - nB1] * 0.32
    tt = 0.0
    for voz, fn, d in cenas:
        v = mp3_para_np(os.path.join(AU, voz + '.mp3'))
        i0 = int((tt + 0.25) * RATE)
        a[i0:i0 + len(v)] += v[: len(a) - i0] * 1.0
        # abaixa a musica enquanto a voz fala (ducking simples)
        tt += d
    a = a[: int(total * RATE)]
    a = a / max(1.0, np.max(np.abs(a)) / 0.95)
    wav_out = os.path.join(TR, 'audio_mix.wav')
    with wave.open(wav_out, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes((a * 32767).astype(np.int16).tobytes())
    # ----- video
    mp4 = os.path.join(TR, 'trailer_los_pastelles.mp4')
    cmd = [FF, '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
           '-i', wav_out, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-preset', 'medium',
           '-c:a', 'aac', '-b:a', '192k', '-shortest', mp4]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for voz, fn, d in cenas:
        nf = int(d * FPS)
        for i in range(nf):
            t = i / FPS
            im = fn(i, t)
            # transicao: escurece rapido no inicio e no fim de cada cena
            k = min(1.0, t / 0.18, (d - t) / 0.18)
            if k < 1:
                im = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), im, max(0.0, k))
            p.stdin.write(im.tobytes())
    p.stdin.close(); p.wait()
    print('trailer:', mp4, f'{total:.1f}s')

if __name__ == '__main__':
    main()
