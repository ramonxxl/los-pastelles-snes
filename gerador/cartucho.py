# Gera a etiqueta do cartucho e o manual de instrucoes (PDF) do Los Pastelles.
# Uso: python gerador/cartucho.py   (fotos em teste/foto_*.png)
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'cartucho')
os.makedirs(OUT, exist_ok=True)
F = os.environ.get('FONTES', 'C:/Windows/Fonts/').rstrip('/\\') + '/'  # pasta das fontes (impact, arial...)
def fonte(nome, tam): return ImageFont.truetype(F + nome, tam)
CREME, LARANJA, LARANJA2, VERMELHO, MARROM, BRANCO = '#FDF1E0', '#FAA61E', '#E88607', '#DA4804', '#3A1A0C', '#FFFFFF'

logo_src = [f for f in os.listdir(ROOT) if f.lower().endswith('.png') and 'pastelles' in f.lower()][0]
LOGO = Image.open(os.path.join(ROOT, logo_src)).convert('RGBA')
# remove o fundo creme da logo (fica transparente)
px = LOGO.load(); bg = px[5, 5]
for y in range(LOGO.height):
    for x in range(LOGO.width):
        r, g, b, a = px[x, y]
        if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) < 30: px[x, y] = (r, g, b, 0)
LOGO = LOGO.crop(LOGO.getbbox())

def foto(nome, escala):
    im = Image.open(os.path.join(OUT, 'fotos', 'foto_' + nome + '.png')).convert('RGB')
    return im.resize((im.width * escala, im.height * escala), Image.NEAREST)

def moldura(im, cor=MARROM, b=6):
    o = Image.new('RGB', (im.width + 2 * b, im.height + 2 * b), cor); o.paste(im, (b, b)); return o

def centro(d, xy, texto, f, cor, larg):
    w = d.textlength(texto, font=f); d.text((xy[0] + (larg - w) / 2, xy[1]), texto, font=f, fill=cor)

# ------------------------------------------------------------------ capa avulsa em alta (para caixa/arte)
Image.open(os.path.join(OUT, 'arte', 'capa.png')).save(os.path.join(OUT, 'capa_jogo.png'), dpi=(600, 600))

# ------------------------------------------------------------------ manual (A5 a 150 dpi)
PW, PH = 874, 1240
FT = fonte('seguibl.ttf', 46); FS = fonte('segoeuib.ttf', 30); FB = fonte('segoeui.ttf', 24); FBB = fonte('segoeuib.ttf', 24)

def pagina(titulo, n):
    p = Image.new('RGB', (PW, PH), CREME); d = ImageDraw.Draw(p)
    d.rectangle([0, 0, PW, 110], fill=MARROM)
    d.text((40, 26), titulo, font=FT, fill=LARANJA)
    d.rectangle([0, PH - 50, PW, PH], fill=LARANJA)
    centro(d, (0, PH - 44), f'LOS PASTELLES: O IMPÉRIO DO PASTEL  —  {n}', fonte('segoeuib.ttf', 22), MARROM, PW)
    return p, d

def texto(d, x, y, linhas, larg=PW - 80, f=FB, cor=MARROM, esp=8):
    for ln in linhas:
        fnt = f
        if ln.startswith('**'): ln = ln[2:]; fnt = FBB
        if ln.startswith('# '):
            ln = ln[2:]; d.text((x, y), ln, font=FS, fill=VERMELHO); y += 44; continue
        palavras, linha = ln.split(' '), ''
        for w in palavras:
            teste = (linha + ' ' + w).strip()
            if d.textlength(teste, font=fnt) > larg:
                d.text((x, y), linha, font=fnt, fill=cor); y += fnt.size + esp; linha = w
            else: linha = teste
        d.text((x, y), linha, font=fnt, fill=cor); y += fnt.size + esp + (6 if ln == '' else 0)
    return y

def colar(p, nome, y):
    # cola a foto no maior tamanho que caiba entre y e o rodape
    im = moldura(foto(nome, 2))
    livre = PH - 70 - y
    if im.height > livre:
        k = livre / im.height
        im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
    p.paste(im, ((PW - im.width) // 2, y))
    return y + im.height

pags = []
# capa
p = Image.new('RGB', (PW, PH), LARANJA); d = ImageDraw.Draw(p)
d.ellipse([87, 140, 787, 840], fill=CREME)
lg = LOGO.copy(); lg.thumbnail((640, 640)); p.paste(lg, (87 + (700 - lg.width) // 2, 140 + (700 - lg.height) // 2), lg)
centro(d, (0, 880), 'O IMPÉRIO DO PASTEL', fonte('seguibl.ttf', 62), MARROM, PW)
centro(d, (0, 970), 'MANUAL DE INSTRUÇÕES', fonte('segoeuib.ttf', 40), CREME, PW)
d.rectangle([0, PH - 110, PW, PH], fill=MARROM)
centro(d, (0, PH - 82), 'PARA SUPER NINTENDO', fonte('seguibl.ttf', 44), LARANJA, PW)
pags.append(p)

# historia e controles
p, d = pagina('COMEÇANDO', 2)
y = texto(d, 40, 140, [
    '# A HISTÓRIA',
    'Tudo começa numa pequena lanchonete: pouco dinheiro, uma fritadeira simples e muita vontade. Sua missão é provar que o melhor pastel da cidade nasce ali, conquistar clientes, crescer e transformar a Los Pastelles numa rede de franquias por todo o país.',
    '',
    '# CONTROLES',
    '**Direcional: move o cursor (mesa, fritadeira e clientes).',
    '**A: escolher o sabor, tirar do óleo, entregar e confirmar.',
    '**B: jogar fora o pastel da mão / voltar nos menus.',
    '**X: pegar refrigerante para os combos (nível 7+).',
    '**Y: atender o telefone e mandar pastel para a entrega (nível 6+).',
    '**START: pausa (continuar ou sair para o título).',
    '',
    '# INICIANDO',
    'No título escolha NOVO JOGO ou CONTINUAR e um dos 3 espaços de jogo salvo. Em OPÇÕES: dificuldade (Fácil, Normal ou Difícil) e música. O jogo é salvo no cartucho sempre que você escolhe ABRIR A LOJA.'])
colar(p, 'titulo', y + 10)
pags.append(p)

# como jogar
p, d = pagina('COMO JOGAR', 3)
y = texto(d, 40, 140, [
    '1. Na mesa, escolha o sabor que o cliente pediu (ícone no balão) e aperte A.',
    '2. FECHE O PASTEL repetindo os botões que aparecem no topo: cruz direcional, A vermelho, B amarelo, X azul e Y verde. Os acertados ficam verdes e a barra embaixo mostra o tempo.',
    '3. No óleo, tire o pastel quando a barra ficar VERDE (ele brilha).',
    '4. O cursor vai sozinho até quem pediu aquele sabor: aperte A.'])
y = colar(p, 'minijogo', y + 6) + 10
texto(d, 40, y, ['Cru ou queimado, o cliente reclama. Barra de paciência vermelha piscando: ele vai embora!',
                 '**Cesto com X quebrou: aperte A nele e repita os botões para consertar.'])
pags.append(p)

# clientes
p, d = pagina('A CLIENTELA', 4)
y = texto(d, 40, 140, [
    '**Criança (boné): tem pressa e paga meia.',
    '**Idoso (óculos): espera mais e dá gorjeta boa.',
    '**Turista (chapéu de palha): pede o sabor mais caro e paga R$ 3 a mais.',
    '**Cliente Misterioso (chapéu e óculos escuros): dê um pastel PERFEITO e ganhe uma gorjeta enorme.',
    '',
    '**Balão com latinha = COMBO: aperte X para pegar o refri antes de entregar.',
    '**Balão com "2" = pedido duplo: entregue dois pastéis.'])
colar(p, 'jogo', y + 10)
pags.append(p)

# entregas
p, d = pagina('ENTREGAS', 5)
y = texto(d, 40, 140, [
    'A partir do nível 6 o TELEFONE toca na parede. Aperte Y para anotar: a comanda fica presa na parede com o sabor (e a quantidade). Frite o pastel e, com ele na mão, aperte Y de novo para pôr no saco. Comanda completa: o motoboy sai e você recebe os pastéis + taxa de entrega.',
    '**COMPUTADOR (nível 13): pedidos pelo aplicativo entram sozinhos, alguns com 2 ou 3 pastéis.',
    '**MOTOBOY EXTRA: mais prazo e taxa maior.',
    'Comanda vencida é cancelada e a reputação cai!'])
colar(p, 'entrega', y + 6)
pags.append(p)

# loja
p, d = pagina('FIM DO DIA E A LOJA', 6)
y = texto(d, 40, 140, [
    'Às 19h a loja fecha: vendas, entregas, gorjetas, custos, lucro e o gráfico dos últimos 7 dias. Depois vem a LOJA (a lista rola com ↑ ↓):',
    '**Ingredientes, Fritadeira, Balcão, Freezer: produza mais.',
    '**Atendente, Ar-condicionado, Música, Uniforme: clientes mais pacientes e pagando mais.',
    '**Reforma do Salão: vitrine no balcão e depois a Loja Premium.',
    '**Preço do pastel, Nova loja, Franquia, Mapa e Troféus.'])
colar(p, 'loja2', y + 6)
pags.append(p)

# expansao, desafios e trofeus
p, d = pagina('O IMPÉRIO CRESCE', 7)
y = texto(d, 40, 140, [
    '**Desafios de capítulo: Hora do Almoço, Desafio do Sabor, Cozinha em Crise e Expansão Nacional.',
    '**Duelo semanal: a cada 7 dias o Concorrente desafia você.',
    '**Bairros: com mais lojas, escolha onde trabalhar (Centro Comercial, Residencial, Universitária, Empresarial).',
    '**16 troféus para conquistar. Chegue a 10 unidades e construa o Império!'])
colar(p, 'trofeus', y + 6)
pags.append(p)

# personagens e dicas
p, d = pagina('PERSONAGENS E DICAS', 8)
texto(d, 40, 140, [
    '**O Fundador: você! Começa no balcão e sonha alto.',
    '**Mestre da Massa: ensina receitas novas.',
    '**A Gerente: ajuda a crescer a empresa.',
    '**O Concorrente: dono da pastelaria rival.',
    '',
    '# DICAS',
    '• Comece a fritar antes do cliente chegar ao balcão.',
    '• Pastel perfeito dá mais gorjeta, reputação e experiência.',
    '• Telefone tocando? Atenda logo: ligação perdida custa reputação.',
    '• Não deixe o estoque acabar: compre ingredientes na loja.',
    '• Achou difícil? Mude a dificuldade em OPÇÕES.',
    '',
    '# CUIDADOS COM O CARTUCHO',
    'Desligue o console antes de tirar ou colocar o cartucho. O jogo é salvo por uma bateria no cartucho.',
    '',
    'Uma produção Los Pastelles — 2026.'])
pags.append(p)

pdf = os.path.join(OUT, 'manual_los_pastelles.pdf')
pags[0].save(pdf, save_all=True, append_images=pags[1:], resolution=150)
for i, pg in enumerate(pags): pg.save(os.path.join(OUT, f'manual_pagina_{i + 1}.png'))
print('ok:', OUT)

# ------------------------------------------------------------------ etiqueta no formato classico (modelo 800x440 da pasta), escala 3x
S = 3
LW, LH = 800 * S, 440 * S
lab = Image.new('RGBA', (LW, LH), (0, 0, 0, 0))
d = ImageDraw.Draw(lab)
d.rounded_rectangle([0, 0, LW - 1, LH - 1], radius=22 * S, fill='#050505')
# coluna esquerda: selos da marca (no lugar dos selos de licenciamento)
d.text((24 * S, 78 * S), 'UMA PRODUÇÃO', font=fonte('arialbd.ttf', 10 * S), fill=BRANCO)
d.rounded_rectangle([20 * S, 94 * S, 112 * S, 118 * S], radius=12 * S, fill=VERMELHO, outline=BRANCO, width=2 * S)
centro(d, (20 * S, 99 * S), 'LOS PASTELLES', fonte('arialbd.ttf', 9 * S), BRANCO, 92 * S)
d.polygon([(32 * S, 142 * S), (62 * S, 142 * S), (47 * S, 157 * S)], fill='#9B5A8C')
cx, cy, r = 66 * S, 343 * S, 38 * S
import math
pts = []
for k in range(48):
    a = 2 * math.pi * k / 48; rr = r if k % 2 == 0 else r - 4 * S
    pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
d.polygon(pts, fill='#C9A55C')
d.ellipse([cx - r + 9 * S, cy - r + 9 * S, cx + r - 9 * S, cy + r - 9 * S], fill='#E8D6A8', outline='#8A6A2A', width=2 * S)
centro(d, (cx - r, cy - 14 * S), 'SELO DE', fonte('arialbd.ttf', 7 * S), '#5A3A10', 2 * r)
centro(d, (cx - r, cy - 4 * S), 'QUALIDADE', fonte('arialbd.ttf', 7 * S), '#5A3A10', 2 * r)
centro(d, (cx - r, cy + 6 * S), 'LOS PASTELLES', fonte('arialbd.ttf', 6 * S), '#5A3A10', 2 * r)
d.text((20 * S, 392 * S), 'LP-SNES-BRA', font=fonte('arialbd.ttf', 11 * S), fill=BRANCO)
d.text((20 * S, 406 * S), 'FEITO NO BRASIL', font=fonte('arialbd.ttf', 11 * S), fill=BRANCO)
# arte central: ilustracao de capa (gerador/capa.py)
ax0, ay0, ax1, ay1 = 128 * S, 22 * S, 548 * S, 418 * S
arte = Image.open(os.path.join(OUT, 'arte', 'capa.png')).convert('RGB').resize((ax1 - ax0, ay1 - ay0), Image.LANCZOS)
lab.paste(arte, (ax0, ay0))
# coluna direita: contracapa. Mantem o ritmo visual classico, mas usa conteudo
# proprio do jogo em vez do texto/selos de uma etiqueta licenciada.
d.rectangle([557 * S, 66 * S, 767 * S, 82 * S], fill='#E00000')
d.text((558 * S, 94 * S), 'A COZINHA NAO PARA!', font=fonte('arialbd.ttf', 11 * S), fill=BRANCO)
d.text((558 * S, 112 * S), 'Transforme uma pequena', font=fonte('arial.ttf', 8 * S), fill='#D8D8D8')
d.text((558 * S, 124 * S), 'pastelaria no imperio', font=fonte('arial.ttf', 8 * S), fill='#D8D8D8')
d.text((558 * S, 136 * S), 'mais crocante da cidade.', font=fonte('arial.ttf', 8 * S), fill='#D8D8D8')

recursos = [
    ('ATENDA', 'clientes e vença o relogio'),
    ('COZINHE', 'pasteis no ponto certo'),
    ('CRESCA', 'sua loja pelo bairro'),
    ('SALVE', 'sua jornada no cartucho'),
]
for k, (titulo, texto) in enumerate(recursos):
    y = (158 + k * 35) * S
    d.ellipse([558 * S, y, 570 * S, y + 12 * S], fill=LARANJA, outline=MARROM, width=S)
    centro(d, (558 * S, y - S), str(k + 1), fonte('arialbd.ttf', 7 * S), MARROM, 12 * S)
    d.text((576 * S, y - 2 * S), titulo, font=fonte('arialbd.ttf', 8 * S), fill=BRANCO)
    d.text((576 * S, y + 9 * S), texto, font=fonte('arial.ttf', 7 * S), fill='#BDBDBD')

# codigo decorativo da edicao: deixa a area inferior com acabamento de embalagem.
codigo = '789  LOS  2026  016'
larguras = [2, 1, 3, 1, 1, 2, 4, 1, 2, 1, 3, 2, 1, 4, 1, 2, 3, 1, 2, 4, 1, 1, 3, 2]
x = 558 * S
for n, w in enumerate(larguras):
    bw = w * S
    if n % 2 == 0: d.rectangle([x, 307 * S, x + bw, 337 * S], fill=BRANCO)
    x += bw + S
centro(d, (558 * S, 339 * S), codigo, fonte('arial.ttf', 6 * S), '#BDBDBD', 145 * S)
d.text((560 * S, 352 * S), 'PARA', font=fonte('arialbd.ttf', 14 * S), fill='#E00000')
d.text((556 * S, 366 * S), 'SUPER NINTENDO', font=fonte('impact.ttf', 26 * S), fill='#E00000')
lab.save(os.path.join(OUT, 'etiqueta_formato_classico.png'), dpi=(800, 800))
print('etiqueta classica ok')
