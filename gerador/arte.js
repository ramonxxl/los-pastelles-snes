// Arte do jogo: cenarios (BG1) e folha de sprites
'use strict';
const { Img, sceneToBG, enc4, tilePixels, palBytes } = require('./gfx');
const { GLYPHS, BOTOES } = require('./fonte');
const HUD = require('./hud');

// ---------------------------------------------------------------- texto grande nos cenarios
function drawText(I, s, x, y, col, scale = 1) {
  for (const ch of s) {
    const g = GLYPHS[ch] || GLYPHS[' '];
    for (let j = 0; j < 7; j++) for (let i = 0; i < 5; i++) if (g[j][i] === '#') I.rect(x + (i + 1) * scale, y + j * scale, scale, scale, col);
    x += 7 * scale;
  }
}
function textWidth(s, scale = 1) { return s.length * 7 * scale; }

// =================================================================== CENARIO: LOJA (jogo)
// cores da marca (logo): creme, laranja, vermelho-alaranjado e marrom escuro, mais
// verde (11, folhas) e azul (14, ceu/vidro) para os elementos feitos de emoji.
// A cor 12 pisca no jogo (oleo da fritadeira, OilColor em game.s)
const PAL_SHOP = [null, '#1C0A04', '#3A1A0C', '#FFF8EC', '#C8D0D8', '#7C8494', '#FDE9C4', '#FAA61E',
  '#A85C28', '#5C3018', '#DA4804', '#5C9C3C', '#E89A1C', '#7C5010', '#58A8E8', '#48A048'];
// pastelzinho do letreiro (12x14)
function miniPastel(I, x, y, A, a, K) {
  for (let j = 0; j < 14; j++) for (let i = 0; i < 12; i++) {
    if ((i === 0 || i === 11) && (j === 0 || j === 13)) continue;
    const edge = i === 0 || i === 11 || j === 0 || j === 13;
    I.set(x + i, y + j, edge ? (((i + j) & 1) ? a : A) : A);
  }
  I.set(x + 3, y + 5, K); I.set(x + 4, y + 4, K); I.set(x + 5, y + 5, K);   // piscando
  I.rect(x + 7, y + 4, 2, 2, K);
  I.set(x + 3, y + 8, K); I.hline(x + 4, y + 9, 4, K); I.set(x + 8, y + 8, K);
}
// variacoes por bairro: trocam so as cores 6 (parede) e 15 (detalhe)
const SHOP_VAR = [
  { 6: '#FDE9C4', 15: '#98D068' },   // 0 bairro inicial (15: folhas claras)
  { 6: '#D8E0E8', 15: '#78C8E8' },   // 1 centro comercial
  { 6: '#E8F0D0', 15: '#68A048' },   // 2 residencial
  { 6: '#E8C8A0', 15: '#2E5034' },   // 3 universitaria
  { 6: '#C8B8A8', 15: '#5878A8' },   // 4 empresarial
];
function shopPal(v) { const p = PAL_SHOP.slice(); for (const k in SHOP_VAR[v]) p[k] = SHOP_VAR[v][k]; return p; }

// elementos do cenario feitos de emoji (gerador/emoji_cenario.py -> gen/emoji_cen.json),
// ja quantizados na paleta de cada bairro. build.js gera o arquivo antes dos cenarios
let EMO_CEN = null;
function emojiCenario(nome, v) {
  if (!EMO_CEN) {
    const arq = require('path').join(__dirname, '..', 'gen', 'emoji_cen.json');
    EMO_CEN = JSON.parse(require('fs').readFileSync(arq, 'utf8'));
  }
  const e = EMO_CEN[`${nome}_${v}`];
  if (!e) throw new Error('emoji do cenario nao gerado: ' + nome + ' (rode node build.js)');
  return e;
}
// cola o emoji com o canto superior esquerdo em (x, y); cor 0 = transparente
function colaEmoji(I, nome, v, x, y) {
  const [w, h, p] = emojiCenario(nome, v);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (p[j * w + i]) I.set(x + i, y + j, p[j * w + i]);
}

function shopScene(v = 0, ref = 0) {
  const K = 1, N = 2, W = 3, L = 4, G = 5, Y = 6, O = 7, B = 8, D = 9, R = 10, A = 12, a = 13, g = 15;
  const I = new Img(256, 224);
  const emo = (nome, x, y) => colaEmoji(I, nome, v, x, y);
  // faixa superior (HUD)
  I.rect(0, 0, 256, 26, N); I.hline(0, 26, 256, D); I.hline(0, 27, 256, K);
  if (v === 0) {
  // parede do salao: amarela com azulejos
    I.rect(0, 28, 256, 56, Y);
    for (let y = 28; y < 84; y += 8) for (let x = 0; x < 256; x += 8) { I.set(x + 3, y + 3, O); I.set(x + 4, y + 4, O); I.set(x + 4, y + 3, O); I.set(x + 3, y + 4, O); }
    // rodape de madeira (lambri) laranja
    I.hline(0, 82, 256, B); I.hline(0, 83, 256, D);
    I.rect(0, 84, 256, 20, O);
    for (let x = 0; x < 256; x += 16) I.vline(x, 84, 20, B);
    // janelas 🪟 com vaso de planta 🪴 no peitoril
    for (const wx of [10, 202]) {
      emo('janela', wx, 33);
      I.rect(wx - 2, 73, 48, 3, B); I.hline(wx - 2, 76, 48, D);
      emo('planta', wx + 13, 56);
    }
  } else if (v === 1) {
    // centro comercial: placas de porcelanato, vitrines 🪟 e sacolas 🛍️
    I.rect(0, 28, 256, 56, Y);
    for (let y = 28; y < 84; y += 16) I.hline(0, y, 256, L);
    for (let x = 0; x < 256; x += 16) I.vline(x, 28, 56, L);
    for (let x = 4; x < 256; x += 24) { I.rect(x, 29, 6, 2, W); }
    for (const wx of [8, 196]) {
      emo('vitrine', wx, 31);
      emo('sacolas', wx + (wx < 128 ? 34 : -2), 63);
    }
    I.hline(0, 82, 256, G); I.hline(0, 83, 256, K);
    I.rect(0, 84, 256, 20, L); for (let x = 0; x < 256; x += 32) I.vline(x, 84, 20, G); I.hline(0, 94, 256, G);
  } else if (v === 2) {
    // residencial: papel de parede listrado e quadros 🖼️
    I.rect(0, 28, 256, 56, Y);
    for (let x = 0; x < 256; x += 12) { I.vline(x, 28, 56, g); I.vline(x + 1, 28, 56, g); }
    for (const fx of [10, 202]) emo('quadro', fx, 35);
    I.hline(0, 82, 256, B); I.hline(0, 83, 256, D);
    I.rect(0, 84, 256, 20, B); for (let x = 0; x < 256; x += 8) I.vline(x, 84, 20, D);
  } else if (v === 3) {
    // universitaria: parede de tijolos, lousa com o cardapio, livros 📚 e bandeirinhas
    I.rect(0, 28, 256, 56, Y);
    for (let y = 28; y < 84; y += 6) { I.hline(0, y, 256, O); for (let x = ((y / 6) & 1) * 8; x < 256; x += 16) I.vline(x, y, 6, O); }
    for (const bx of [8, 196]) {
      I.rect(bx, 34, 52, 42, B); I.rect(bx + 3, 37, 46, 36, g);
      drawText(I, 'MENU', bx + 9, 40, W);
      for (let k = 0; k < 3; k++) { I.hline(bx + 7, 52 + k * 7, 20, W); I.hline(bx + 32, 52 + k * 7, 10, A); }
      I.rect(bx - 2, 76, 56, 2, D);                                   // aparador da lousa
      emo('livros', bx + (bx < 128 ? 36 : -2), 61);
    }
    for (let x = 0; x < 256; x += 10) { for (let k = 0; k < 4; k++) I.hline(x + k, 29 + k, 8 - k * 2, (x / 10) & 1 ? R : O); }
    I.hline(0, 82, 256, B); I.hline(0, 83, 256, D);
    I.rect(0, 84, 256, 20, O); for (let x = 0; x < 256; x += 16) I.vline(x, 84, 20, B);
  } else {
    // empresarial: lambri escuro e janelas com a cidade 🏙️
    I.rect(0, 28, 256, 56, Y);
    for (let x = 0; x < 256; x += 32) { I.rect(x + 2, 30, 28, 52, B); I.frame(x + 2, 30, 28, 52, D); }
    for (const wx of [6, 194]) {
      I.rect(wx, 32, 56, 46, K);
      emo('cidade', wx + 2, 34);
      I.vline(wx + 28, 34, 42, K);
    }
    I.hline(0, 82, 256, D); I.hline(0, 83, 256, K);
    I.rect(0, 84, 256, 20, D); for (let x = 0; x < 256; x += 16) I.vline(x, 84, 20, K); I.hline(0, 93, 256, B);
  }
  // letreiro LOS PASTELLES
  const sx = 66, sy = 31, sw = 124, sh = 28;
  I.rect(sx - 2, sy - 2, sw + 4, sh + 4, K); I.rect(sx, sy, sw, sh, W); I.frame(sx + 1, sy + 1, sw - 2, sh - 2, N); I.frame(sx + 3, sy + 3, sw - 6, sh - 6, O);
  const t1 = 'LOS', t2 = 'PASTELLES';
  drawText(I, t1, sx + ((sw - textWidth(t1)) >> 1), sy + 5, O); drawText(I, t1, sx + ((sw - textWidth(t1)) >> 1) - 1, sy + 4, R);
  drawText(I, t2, sx + ((sw - textWidth(t2)) >> 1), sy + 16, O); drawText(I, t2, sx + ((sw - textWidth(t2)) >> 1) - 1, sy + 15, N);
  miniPastel(I, sx + 8, sy + 7, A, a, K); miniPastel(I, sx + sw - 20, sy + 7, A, a, K);
  // balcao
  I.rect(0, 104, 256, 6, L); I.hline(0, 104, 256, W); I.hline(0, 109, 256, G); I.hline(0, 110, 256, K);
  I.rect(0, 111, 256, 17, B); I.hline(0, 119, 256, D);
  for (let x = 8; x < 256; x += 32) { I.vline(x, 111, 17, D); }
  I.hline(0, 127, 256, K);
  // ---------- reforma nivel 2: vitrine de vidro com pasteis 🥟 no balcao
  if (ref >= 1) {
    I.rect(0, 111, 256, 16, D);
    for (let x = 3; x < 250; x += 63) {
      I.rect(x, 112, 59, 14, L); I.frame(x, 112, 59, 14, K);
      I.hline(x + 1, 116, 57, G);
      for (let k = 0; k < 4; k++) emo('pastel', x + 2 + k * 14, 117);
      for (let k = 0; k < 4; k++) { I.set(x + 6 + k, 113 + k, W); I.set(x + 30 + k, 113 + k, W); }
    }
  }
  // ---------- reforma nivel 3: bandeirinhas, flores 💐 e letreiro dourado
  if (ref >= 2) {
    // varal de bandeirinhas de festa
    for (let x = 0; x < 256; x++) I.set(x, 30 + Math.round(Math.sin(x / 40) * 2), K);
    for (let x = 0, k = 0; x < 256; x += 11, k++) {
      if (x > 54 && x < 194) continue;
      const cor = [R, O, Y][k % 3], y0 = 31 + Math.round(Math.sin(x / 40) * 2);
      for (let t = 0; t < 7; t++) I.hline(x + Math.floor(t / 2), y0 + t, 9 - t, cor);
    }
    // letreiro com moldura dourada
    I.frame(sx - 3, sy - 3, sw + 6, sh + 6, A); I.frame(sx - 4, sy - 4, sw + 8, sh + 8, a);
    // vasos de flores nas pontas do balcao
    for (const fx of [0, 238]) {
      emo('flores', fx, 73);
      I.rect(fx + 3, 93, 13, 11, B); I.hline(fx + 3, 93, 13, D); I.frame(fx + 3, 93, 13, 11, K);
    }
  }
  // cozinha: azulejos brancos
  I.rect(0, 128, 256, 56, W);
  for (let y = 128; y < 184; y += 8) I.hline(0, y, 256, L);
  for (let x = 0; x < 256; x += 8) I.vline(x, 128, 56, L);
  // mesa dos ingredientes
  I.rect(0, 168, 130, 3, L); I.hline(0, 168, 130, W); I.rect(0, 171, 130, 3, G); I.hline(0, 174, 130, K);
  I.rect(4, 175, 4, 9, G); I.rect(122, 175, 4, 9, G);
  for (let i = 0; i < 6; i++) {
    const x0 = 4 + i * 20;
    // tigela: desenhada a parte para o contorno (outline so pinta pixels vazios, e
    // aqui a parede ja preencheu tudo; sem ele a tigela branca sumia nos azulejos)
    const tg = new Img(20, 19);
    tg.ell(1, 2, 18, 17, W, (x, y) => y >= 8);
    tg.rect(1, 7, 18, 2, L);
    tg.ell(1, 2, 18, 17, G, (x, y) => y >= 14);
    tg.outline(K);
    for (let y = 0; y < 19; y++) for (let x = 0; x < 20; x++) if (tg.get(x, y)) I.set(x0 + x, 150 + y, tg.get(x, y));
  }
  // fritadeira
  const fx = 134, fy = 134;
  I.rect(fx, fy, 120, 50, K); I.rect(fx + 1, fy + 1, 118, 48, L); I.hline(fx + 1, fy + 1, 118, W);
  I.rect(fx + 1, fy + 30, 118, 19, G); I.hline(fx + 1, fy + 30, 118, K);
  for (let j = 0; j < 4; j++) {
    const bx = 138 + j * 28;
    I.rect(bx, 142, 24, 22, K); I.rect(bx + 1, 143, 22, 20, a);
    I.rect(bx + 2, 150, 20, 12, A);
    for (let k = 0; k < 20; k += 4) { I.set(bx + 3 + k, 150, Y); I.set(bx + 4 + k, 151, Y); }
    // botao/luz de cada cesto
    I.rect(bx + 9, 168, 6, 6, K); I.rect(bx + 10, 169, 4, 4, R); I.set(bx + 10, 169, Y);
  }
  // chao xadrez
  for (let y = 184; y < 200; y += 8) for (let x = 0; x < 256; x += 8) I.rect(x, y, 8, 8, ((x + y) >> 3) & 1 ? R : W);
  I.hline(0, 184, 256, K);
  // caixa termica de refrigerante
  I.rect(2, 180, 18, 18, K); I.rect(3, 181, 16, 16, R); I.rect(3, 181, 16, 4, W); I.rect(3, 189, 16, 2, W);
  I.rect(7, 192, 8, 3, N);
  // faixa inferior
  I.rect(0, 199, 256, 25, N); I.hline(0, 199, 256, D);
  hudBaloes(I);
  return I;
}

// HUD (gerador/hud.js): pilulas creme no topo e painel creme no rodape, no estilo
// do balao do tutorial (contorno escuro, filete caramelo embaixo); o texto (BG3,
// paletas 4-7) e os emojis (sprites) ficam por cima
function hudBaloes(I) {
  const K = 1, W = 3, B = 8;
  const { y, h } = HUD.PILULA;
  for (const k in HUD.TOPO) {
    const [x0, x1] = HUD.pilulaX(HUD.TOPO[k]), w = x1 - x0 + 1;
    roundRect(I, x0, y + 1, w, h, 7, K);                          // sombra
    roundRect(I, x0, y, w, h, 7, K);
    roundRect(I, x0 + 1, y + 1, w - 2, h - 2, 6, (px, py) => (py >= y + h - 3 ? B : W));
  }
  const p = HUD.PAINEL;
  roundRect(I, p.x, p.y, p.w, p.h, 6, K);
  roundRect(I, p.x + 1, p.y + 1, p.w - 2, p.h - 2, 5, (px, py) => (py >= p.y + p.h - 3 ? B : W));
}

// =================================================================== CENARIO: TITULO / NOITE
const PAL_TITLE = [null, '#0C0C18', '#141C40', '#202C60', '#3C3C78', '#F8F8F8', '#F8D848', '#241C2C',
  '#3C3448', '#DA4804', '#7C2804', '#908898', '#585060', '#FAA61E', '#504858', '#402830'];
// cores 14/15 = letreiro (animadas no jogo)
function titleScene() {
  const K = 1, n1 = 2, n2 = 3, n3 = 4, W = 5, Y = 6, bk = 7, bm = 8, R = 9, r = 10, S = 11, s = 12, O = 13, L1 = 14, L2 = 15;
  const I = new Img(256, 224);
  // ceu em faixas com pontilhado
  for (let y = 0; y < 200; y++) for (let x = 0; x < 256; x++) {
    let c = n1;
    if (y > 70) c = n2; if (y > 120) c = n3;
    if (y > 60 && y <= 70 && ((x + y) & 1)) c = n2;
    if (y > 112 && y <= 120 && ((x + y) & 1)) c = n3;
    I.set(x, y, c);
  }
  // estrelas
  let seed = 7; const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  for (let k = 0; k < 40; k++) { const x = (rnd() * 256) | 0, y = (rnd() * 60) | 0; I.set(x, y, W); if (rnd() < 0.2) { I.set(x + 1, y, n3); I.set(x - 1, y, n3); I.set(x, y + 1, n3); I.set(x, y - 1, n3); } }
  // lua
  I.ell(206, 14, 225, 33, W); I.ell(212, 12, 231, 31, n1);
  // predios
  const bld = [[0, 96, 34], [30, 80, 28], [56, 104, 20], [180, 100, 24], [202, 84, 30], [230, 92, 26]];
  for (const [x, top, w] of bld) {
    I.rect(x, top, w, 200 - top, bk); I.vline(x + w - 1, top, 200 - top, bm);
    for (let y = top + 6; y < 186; y += 10) for (let xx = x + 4; xx < x + w - 5; xx += 7) if (rnd() < 0.55) I.rect(xx, y, 3, 4, Y);
  }
  // fachada da loja
  const fx = 40, fw = 176;
  I.rect(fx, 108, fw, 84, R);
  for (let y = 110; y < 192; y += 6) for (let x = fx; x < fx + fw; x += 12) I.rect(x + ((y / 6) & 1 ? 6 : 0), y, 1, 6, r);
  for (let y = 108; y < 192; y += 6) I.hline(fx, y, fw, r);
  // letreiro grande
  I.rect(14, 56, 228, 44, K); I.rect(16, 58, 224, 40, bk); I.frame(18, 60, 220, 36, L2);
  const big = 'LOS PASTELLES', bw = textWidth(big, 2);
  const bx = 16 + ((224 - bw) >> 1);
  drawText(I, big, bx + 1, 72, L2, 2); drawText(I, big, bx, 71, L1, 2);
  I.rect(56, 100, 4, 8, bm); I.rect(196, 100, 4, 8, bm);
  // toldo listrado
  for (let x = fx - 6; x < fx + fw + 6; x++) for (let y = 110; y < 122; y++) I.set(x, y, ((x - fx + 6) >> 3) & 1 ? W : R);
  for (let x = fx - 6; x < fx + fw + 6; x += 8) { I.ell(x, 119, x + 7, 125, ((x - fx + 6) >> 3) & 1 ? W : R, (xx, yy) => yy >= 122); }
  I.hline(fx - 6, 109, fw + 12, K);
  // vitrines e porta
  for (const wx of [fx + 10, fx + 118]) { I.rect(wx, 132, 48, 40, K); I.rect(wx + 2, 134, 44, 36, O); I.rect(wx + 2, 160, 44, 10, Y); I.vline(wx + 24, 134, 36, K);
    for (let k = 0; k < 6; k++) I.ell(wx + 4 + k * 7, 156, wx + 9 + k * 7, 160, Y); }
  I.rect(fx + 70, 128, 36, 64, K); I.rect(fx + 72, 130, 32, 62, O); I.rect(fx + 74, 132, 28, 26, Y); I.rect(fx + 96, 162, 3, 3, K);
  // calcada e rua
  I.rect(0, 192, 256, 12, S); for (let x = 0; x < 256; x += 16) I.vline(x, 192, 12, s); I.hline(0, 192, 256, W);
  I.rect(0, 204, 256, 20, s); I.hline(0, 204, 256, K);
  for (let x = 4; x < 256; x += 32) I.rect(x, 213, 16, 2, Y);
  // poste
  I.rect(8, 120, 3, 72, K); I.rect(4, 116, 11, 5, K); I.rect(5, 117, 9, 3, Y);
  I.rect(245, 120, 3, 72, K); I.rect(241, 116, 11, 5, K); I.rect(242, 117, 9, 3, Y);
  return I;
}

// =================================================================== CENARIO: MENU (toalha xadrez + painel)
const PAL_MENU = [null, '#1C0A04', '#FFF8EC', '#F3DFC0', '#C8A870', '#E88607', '#FDF1E0', '#8C4A08',
  '#A85C28', '#5C3018', '#F8D068', '#283058', '#48A048', '#7C8494', '#E89038', '#C8D0D8'];
function menuScene() {
  const K = 1, C1 = 2, C2 = 3, C3 = 4, R = 5, W = 6, r = 7, B = 8, D = 9, Y = 10;
  const I = new Img(256, 224);
  // fundo transparente: o xadrez fica no BG2 (menuChecker), que rola sozinho
  // painel
  I.rect(10, 10, 240, 206, r);            // sombra
  I.rect(6, 6, 240, 206, K);
  I.rect(8, 8, 236, 202, D); I.rect(10, 10, 232, 198, B); I.rect(12, 12, 228, 194, C2); I.rect(13, 13, 226, 192, C1);
  // cantos decorados
  for (const [x, y] of [[14, 14], [234, 14], [14, 200], [234, 200]]) { I.rect(x, y, 6, 6, Y); I.frame(x, y, 6, 6, C3); }
  return I;
}

// xadrez do fundo dos menus (BG2): 3 tiles (creme, laranja, pontilhado) e mapa 32x32
// que se repete a cada 4 tiles, para rolar na horizontal sem emenda.
// tileBase = indice do 1o tile na VRAM; paleta 3 (PAL_MENU carregada la: ChkPal)
function menuChecker(tileBase) {
  const R = 5, W = 6;
  const solid = (c) => new Array(64).fill(c);
  const dither = Array.from({ length: 64 }, (_, k) => (((k & 7) + (k >> 3)) & 1) ? R : W);
  const tiles = Buffer.concat([solid(W), solid(R), dither].map(enc4));
  const map = Buffer.alloc(2048);
  for (let ty = 0; ty < 32; ty++) for (let tx = 0; tx < 32; tx++) {
    const a = (tx >> 1) & 1, b = (ty >> 1) & 1;
    const t = a && b ? 1 : (a || b ? 2 : 0);
    map.writeUInt16LE((tileBase + t) | (3 << 10), (ty * 32 + tx) * 2);   // paleta 3 (a 2 e do cenario)
  }
  return { tiles, map };
}

// ----- retangulo arredondado e degrade pontilhado (balao do tutorial, pilula dos rodapes)
const BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
function roundRect(I, x0, y0, w, h, r, cor) {
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
    const cx = Math.max(x0 + r, Math.min(x0 + w - 1 - r, x)), cy = Math.max(y0 + r, Math.min(y0 + h - 1 - r, y));
    const dx = x - cx, dy = y - cy;
    if (dx * dx + dy * dy <= r * r + r * 0.6) I.set(x, y, typeof cor === 'function' ? cor(x, y) : cor);
  }
}
// cor ao longo de t (0..1) entre os tons de 'tons', com pontilhado ordenado nas passagens
const degrade = (tons, t, x, y) => {
  const v = Math.max(0, Math.min(1, t)) * (tons.length - 1);
  const i = Math.floor(v), f = v - i;
  return tons[Math.min(tons.length - 1, i + (f * 16 > BAYER[y & 3][x & 3] ? 1 : 0))];
};

// balao do tutorial (BG2, so no expediente): paleta propria, mesmo visual das caixas
const PAL_TUT = [null, '#1C0A04', '#8C4A08', '#A85C28', '#C8A870', '#FFFBF2', '#FFF8EC', '#FBF0DC', '#F7E8CE', '#F3DFC0',
  '#EDD4AE', '#000000', '#000000', '#000000', '#000000', '#000000'];
const TUT_BOX = { x: 16, y: 64, w: 224, h: 88 };
function tutBalloon() {
  const I = new Img(256, 224);
  const { x, y, w, h } = TUT_BOX;
  roundRect(I, x, y, w, h, 6, 1);                 // contorno escuro
  roundRect(I, x + 1, y + 1, w - 2, h - 2, 5, 3); // moldura caramelo
  for (let i = x + 4; i < x + w - 4; i++) I.set(i, y + 1, 2);
  roundRect(I, x + 3, y + 3, w - 6, h - 6, 3, 4); // filete claro (borda suave)
  roundRect(I, x + 4, y + 4, w - 8, h - 8, 2, (px, py) => degrade([5, 6, 7, 8, 9, 10], (py - y - 4) / (h - 9), px, py));
  return I;
}

// balao da ajuda (BG2, aberto pela pausa): mesmo visual do balao do tutorial, quase a
// tela toda; o interior e liso em cima (o controle desenhado na paleta 4 assenta nele)
// e ganha o degrade so embaixo
const AJ_BOX = { x: 8, y: 24, w: 240, h: 168 };
const AJ_LISO = 6;                 // cor do interior liso (PAL_TUT 6 = PAL_CTRL 15)
function ajudaBalloon() {
  const I = new Img(256, 224);
  const { x, y, w, h } = AJ_BOX;
  roundRect(I, x, y, w, h, 6, 1);
  roundRect(I, x + 1, y + 1, w - 2, h - 2, 5, 3);
  for (let i = x + 4; i < x + w - 4; i++) I.set(i, y + 1, 2);
  roundRect(I, x + 3, y + 3, w - 6, h - 6, 3, 4);
  const y0 = 128;                  // abaixo do desenho do controle
  roundRect(I, x + 4, y + 4, w - 8, h - 8, 2, (px, py) => (py < y0 ? AJ_LISO : degrade([6, 7, 8, 9], (py - y0) / (y + h - 5 - y0), px, py)));
  return I;
}

// controle do Super Famicom para a aba CONTROLES da ajuda (BG paleta 4; 15 = fundo liso)
const PAL_CTRL = [null, '#1C0A04', '#ECECF2', '#C8C8D4', '#9898AC', '#383844', '#686878', '#E03030', '#981818',
  '#F8D838', '#C08818', '#4878E8', '#2848A0', '#40C040', '#207828', '#FFF8EC'];
const CTRL_POS = { x: 48, y: 64 };  // canto do desenho na tela (alinhado aos tiles)
function controleSFC() {
  const I = new Img(160, 56, 15);
  const C = new Img(160, 56);
  const corpo = (img, dy, c) => {
    img.ell(10, 7 + dy, 58, 53 + dy, c); img.ell(102, 7 + dy, 150, 53 + dy, c);
    roundRect(img, 34, 10 + dy, 92, 40, 4, c);
  };
  // L e R (atras do corpo)
  roundRect(C, 12, 1, 38, 14, 5, 4); roundRect(C, 110, 1, 38, 14, 5, 4);
  C.outline(1);
  // corpo: sombra embaixo (3), luz por cima (2) e contorno
  const B = new Img(160, 56);
  corpo(B, 0, 3); corpo(B, -2, 2);
  for (let i = 0; i < B.p.length; i++) if (B.p[i]) C.p[i] = B.p[i];
  const so = new Img(160, 56); corpo(so, 0, 1); so.outline(9);
  for (let i = 0; i < so.p.length; i++) if (so.p[i] === 9) C.p[i] = 1;
  // letras dos ombros
  const L3 = { L: ['#..', '#..', '#..', '#..', '###'], R: ['##.', '#.#', '##.', '#.#', '#.#'] };
  const letra = (img, l, x, y, c) => L3[l].forEach((r, j) => { for (let i = 0; i < 3; i++) if (r[i] === '#') img.set(x + i, y + j, c); });
  letra(C, 'L', 22, 2, 5); letra(C, 'R', 136, 2, 5);
  // cruz direcional num rebaixo
  C.ell(19, 17, 49, 46, 3);
  C.rect(29, 19, 10, 26, 5); C.rect(21, 27, 26, 10, 5);
  C.hline(30, 20, 8, 6); C.vline(30, 20, 7, 6); C.hline(22, 28, 7, 6); C.vline(22, 28, 8, 6);
  C.rect(32, 30, 4, 4, 6);
  // SELECT e START, e as quatro cores do logo
  roundRect(C, 63, 36, 13, 6, 3, 5); roundRect(C, 84, 36, 13, 6, 3, 5);
  [[70, 7], [76, 9], [82, 11], [88, 13]].forEach(([x, c]) => C.rect(x - 1, 21, 3, 3, c));
  // botoes: X em cima, A a direita, B embaixo, Y a esquerda
  const LT = { A: ['.#.', '#.#', '###', '#.#', '#.#'], B: ['##.', '#.#', '##.', '#.#', '##.'],
    X: ['#.#', '#.#', '.#.', '#.#', '#.#'], Y: ['#.#', '#.#', '.#.', '.#.', '.#.'] };
  C.ell(105, 11, 147, 51, 3);
  for (const [l, cx, cy, c, e] of [['X', 126, 18, 11, 12], ['A', 140, 32, 7, 8], ['B', 126, 46, 9, 10], ['Y', 112, 32, 13, 14]]) {
    const b = new Img(160, 56);
    b.ell(cx - 6, cy - 6, cx + 6, cy + 6, e); b.ell(cx - 6, cy - 6, cx + 5, cy + 5, c);
    b.set(cx - 3, cy - 4, 15); b.set(cx - 4, cy - 3, 15);
    LT[l].forEach((r, j) => { for (let i = 0; i < 3; i++) if (r[i] === '#') b.set(cx - 1 + i, cy - 2 + j, l === 'B' ? 1 : 15); });
    b.outline(1);
    for (let i = 0; i < b.p.length; i++) if (b.p[i]) C.p[i] = b.p[i];
  }
  I.paste(C, 0, 0);
  return I;
}

// tecla escolhida no teclado do password: fundo amarelo com borda escura, brilho
// em cima e sombra laranja embaixo (sprite 16x16, paleta 0; a letra, BG3, fica por cima)
function teclaSenha() {
  const I = new Img(16, 16);
  roundRect(I, 0, 0, 16, 16, 3, 1);
  roundRect(I, 1, 1, 14, 14, 2, (x, y) => (y <= 2 ? 14 : y >= 12 ? 6 : 5));
  return I;
}

// pilula dos botoes de acao (rodape das caixas): sprites 16x16 na paleta 1
// (creme F8F0C8 -> E8D098, brilho F8F8F8, borda C8A868, sombra 805030)
function pilula() {
  const I = new Img(48, 16);
  roundRect(I, 0, 1, 48, 15, 7, 8);                // sombra (1 px abaixo)
  roundRect(I, 0, 0, 48, 15, 7, 4);                // borda suave
  roundRect(I, 1, 1, 46, 13, 6, (px, py) => degrade([13, 2, 2, 3], (py - 1) / 12, px, py));
  return { esq: I.sub(0, 0, 16, 16), meio: I.sub(16, 0, 16, 16), dir: I.sub(32, 0, 16, 16) };
}

// =================================================================== SPRITES
// paletas de sprite (OBJ 0..7)
const SPAL = [
  // 0: interface/icones
  [null, '#181018', '#F8F8F8', '#B8B8C8', '#686878', '#F8D838', '#E88820', '#A05020', '#603010', '#E03030', '#901818', '#40C040', '#207020', '#F898A0', '#F8E8B0', '#4878E8'],
  // 1: pasteis (cru/dourado/queimado) + fumaca/brilho
  [null, '#181010', '#F8F0C8', '#E8D098', '#C8A868', '#F8D060', '#E8A030', '#B87018', '#805030', '#503018', '#281808', '#E0E0E8', '#A0A0B0', '#F8F8F8', '#F8F040', '#F86020'],
  // 2: fundador (costas)
  [null, '#181018', '#F8F8F8', '#B8B8C8', '#F0C090', '#C89060', '#704020', '#402810', '#D83828', '#901818', '#3858B0', '#203070', '#603010', '#F8D838', '#000000', '#000000'],
];
// papeis de cor dos clientes: k s S h H c C w m p x X g
const CUST_PALS = [
  ['#181018', '#F0C090', '#C89060', '#604020', '#402810', '#3870D8', '#2048A0', '#F8F8F8', '#C83030', '#F89090', '#E0E0E0', '#A0A0A0', '#B8B8C8'],
  ['#181018', '#E8B080', '#C08050', '#282028', '#100810', '#D83850', '#982030', '#F8F8F8', '#B02020', '#F89090', '#F8D838', '#C09020', '#B8B8C8'],
  ['#181018', '#A86838', '#804820', '#201010', '#100808', '#38A848', '#207028', '#F8F8F8', '#902020', '#D87060', '#F08020', '#B05010', '#B8B8C8'],
  ['#181018', '#F8D0A8', '#D0A078', '#C8C8D0', '#909098', '#8848C0', '#582890', '#F8F8F8', '#C03030', '#F8A0A0', '#303040', '#707080', '#B8B8C8'],
  ['#181018', '#F0C090', '#C89060', '#402818', '#201008', '#806848', '#584830', '#F8F8F8', '#B02020', '#F09090', '#383040', '#201820', '#B8B8C8'],
];
// paletas de retrato (carregadas na OBJ 7 nas cartas)
const PORT_PALS = [
  // fundador: avental branco, camisa vermelha
  ['#181018', '#F0C090', '#C89060', '#704020', '#402810', '#D83828', '#901818', '#F8F8F8', '#B02020', '#F89090', '#F8F8F8', '#B8B8C8', '#B8B8C8'],
  // mestre da massa: chapeu de chef, bigode grisalho
  ['#181018', '#F0B888', '#C08860', '#D8D8E0', '#9898A8', '#F8F8F8', '#B8B8C8', '#F8F8F8', '#B02020', '#F09090', '#F8F8F8', '#C0C0D0', '#B8B8C8'],
  // gerente: coque, oculos, blazer azul
  ['#181018', '#C88858', '#986038', '#5C2C18', '#341408', '#2858A8', '#183878', '#F8F8F8', '#C02040', '#F08090', '#E83860', '#901830', '#B8B8C8'],
  // concorrente: bigode, roupa verde escura
  ['#181018', '#E8B888', '#B88858', '#181818', '#000000', '#3C6828', '#204018', '#F8F8F8', '#902020', '#E08070', '#D8B030', '#906810', '#B8B8C8'],
];
const toPal = (roles) => [null, ...roles, '#000000', '#000000'].slice(0, 16);

// gera um personagem 32x32 (busto) por especificacao
// spec: {hair, glasses, sunglasses, mustache, coat, earrings, expr}
function person(spec) {
  const K = 1, s = 2, S = 3, h = 4, H = 5, c = 6, C = 7, w = 8, m = 9, p = 10, x = 11, X = 12;
  const I = new Img(32, 32);
  const hair = spec.hair;
  if (hair === 'long') I.ell(6, 5, 25, 30, h);
  if (hair === 'bun') { I.ell(11, 0, 20, 7, h); }
  // corpo
  I.ell(3, 21, 28, 42, c);
  if (spec.coat) { // lapelas
    for (let k = 0; k < 7; k++) { I.set(13 - k, 22 + k, C); I.set(18 + k, 22 + k, C); }
    I.ell(13, 20, 18, 27, w);
  } else if (spec.apron) {
    I.rect(10, 25, 12, 7, w); I.hline(10, 25, 12, X); I.vline(11, 21, 4, w); I.vline(20, 21, 4, w);
  } else {
    I.set(14, 21, w); I.set(15, 22, w); I.set(17, 21, w); I.set(16, 22, w); // golinha
  }
  // pescoco
  I.rect(13, 18, 6, 4, s); I.hline(13, 21, 6, S);
  // cabeca
  I.ell(9, 4, 22, 20, s);
  I.set(8, 11, s); I.set(8, 12, s); I.set(23, 11, s); I.set(23, 12, s);
  // cabelo / chapeus
  const inHead = (px, py) => true;
  if (hair === 'short' || hair === 'long' || hair === 'bun') {
    I.ell(8, 2, 23, 13, h, (px, py) => py <= 7 || ((px <= 10 || px >= 21) && py <= 11));
    if (hair === 'long') { for (let k = 11; k <= 20; k += 2) I.set(k, 8, h); }
  }
  if (hair === 'cap') {
    I.ell(8, 4, 23, 13, h, (px, py) => (px <= 10 || px >= 21) && py >= 8 && py <= 11);
    I.ell(8, 1, 23, 12, x, (px, py) => py <= 7);
    I.rect(15, 7, 13, 2, x); I.hline(15, 8, 13, X); I.hline(9, 6, 14, X);
  }
  if (hair === 'bald') {
    I.ell(8, 4, 23, 15, h, (px, py) => (px <= 10 || px >= 21) && py >= 6 && py <= 12);
    I.set(13, 6, w); I.set(14, 6, w);
  }
  if (hair === 'palha') {
    I.ell(8, 2, 23, 13, h, (px, py) => py <= 7 || ((px <= 10 || px >= 21) && py <= 11));
    I.ell(10, 0, 21, 8, x, (px, py) => py <= 6); I.hline(10, 5, 12, X);
    I.rect(4, 7, 24, 2, x); I.hline(4, 8, 24, X);
  }
  if (hair === 'fedora') {
    I.ell(10, 0, 21, 9, x, (px, py) => py <= 6); I.rect(10, 5, 12, 2, X);
    I.rect(5, 7, 22, 2, x); I.hline(5, 8, 22, X);
    I.ell(8, 4, 23, 13, h, (px, py) => (px <= 9 || px >= 22) && py >= 9 && py <= 12);
  }
  if (hair === 'chef') {
    I.ell(8, 4, 23, 13, h, (px, py) => (px <= 10 || px >= 21) && py >= 8 && py <= 11);
    I.ell(8, 0, 15, 6, x); I.ell(13, -1, 21, 5, x); I.ell(17, 0, 24, 6, x); I.rect(9, 4, 14, 5, x); I.hline(9, 8, 14, X);
  }
  if (hair === 'slick') { // concorrente: cabelo lambido
    I.ell(8, 2, 23, 12, h, (px, py) => py <= 6 || ((px <= 10 || px >= 21) && py <= 10));
    I.set(12, 7, h); I.set(13, 7, h); I.set(14, 7, h);
  }
  if (spec.earrings) { I.set(8, 14, x); I.set(23, 14, x); }
  if (spec.havaiana) { [[7, 25], [12, 28], [18, 26], [23, 29], [9, 30], [21, 23], [15, 24]].forEach(([fx, fy]) => { if (I.get(fx, fy) === c) { I.set(fx, fy, x); I.set(fx + 1, fy, x); } }); }
  // sombreamento
  I.shadeRight(c, C, 3); I.shadeRight(s, S, 2); I.shadeRight(h, H, 2);
  // contorno
  I.outline(K);
  // rosto
  const e = spec.expr || 0;
  if (spec.sunglasses) {
    I.rect(11, 11, 4, 2, K); I.rect(17, 11, 4, 2, K); I.hline(15, 11, 2, K); I.set(12, 11, X); I.set(18, 11, X);
  } else {
    if (e === 1) { I.set(12, 13, K); I.set(13, 12, K); I.set(14, 13, K); I.set(17, 13, K); I.set(18, 12, K); I.set(19, 13, K); }
    else { I.rect(13, 12, 1, 2, K); I.rect(18, 12, 1, 2, K); I.set(12, 12, w); I.set(19, 12, w); }
    if (e === 2) { I.set(11, 10, K); I.set(12, 10, K); I.set(13, 11, K); I.set(14, 11, K); I.set(17, 11, K); I.set(18, 11, K); I.set(19, 10, K); I.set(20, 10, K); }
    if (spec.glasses) { I.frame(11, 11, 5, 4, x); I.frame(16, 11, 5, 4, x); I.set(15, 11, x); I.set(16, 11, x); }
  }
  if (spec.mustache) { I.hline(13, 15, 6, H); I.set(12, 16, H); I.set(19, 16, H); }
  if (e === 1) { I.set(13, 16, K); I.hline(14, 16, 4, m); I.set(18, 16, K); I.hline(14, 17, 4, K); I.set(11, 14, p); I.set(12, 14, p); I.set(19, 14, p); I.set(20, 14, p); }
  else if (e === 2) { I.hline(14, 16, 4, K); I.set(13, 17, K); I.set(18, 17, K); }
  else { I.hline(15, 17, 2, K); I.set(14, 16, spec.mustache ? H : s); }
  if (spec.blush) { I.set(11, 14, p); I.set(20, 14, p); }
  return I;
}

const CUST_SPECS = [
  { hair: 'short' },
  { hair: 'long', earrings: true },
  { hair: 'cap' },
  { hair: 'bald', glasses: true, mustache: true },
  { hair: 'fedora', sunglasses: true, coat: true },
];
const PORT_SPECS = [
  { hair: 'short', apron: true, blush: true, expr: 1 },
  { hair: 'chef', mustache: true, apron: true, expr: 1 },
  { hair: 'bun', glasses: true, coat: true, earrings: true },
  { hair: 'slick', mustache: true, coat: true, expr: 0 },
];

function founderBack(frame) {
  const K = 1, W = 2, g = 3, s = 4, S = 5, h = 6, H = 7, c = 8, C = 9, b = 10, B = 11, o = 12;
  const I = new Img(32, 32);
  // (1 px abaixo do topo do sprite: o contorno do chapeu precisa da linha de cima;
  // o jogo desenha o fundador 1 px mais alto para compensar)
  const bob = frame ? 2 : 1;
  // corpo
  I.ell(6, 17 + bob, 25, 40, c);
  // bracos
  I.rect(4, 20 + bob, 4, 9 - (frame ? 2 : 0), c); I.rect(24, 20 + bob, 4, 9 - (frame ? 0 : 2), c);
  I.rect(4, 28 + bob - (frame ? 2 : 0), 4, 3, s); I.rect(24, 28 + bob - (frame ? 0 : 2), 4, 3, s);
  // cabeca (cabelo de costas)
  I.ell(10, 7 + bob, 21, 18 + bob, h);
  I.set(9, 12 + bob, s); I.set(22, 12 + bob, s);
  I.rect(14, 17 + bob, 4, 2, s);
  // chapeu de cozinheiro
  I.ell(9, 0 + bob, 16, 6 + bob, W); I.ell(15, 0 + bob, 22, 6 + bob, W); I.rect(10, 4 + bob, 12, 5, W);
  // lacos do avental
  I.hline(6, 25 + bob, 20, W); I.set(15, 26 + bob, W); I.set(16, 26 + bob, W); I.set(14, 27 + bob, W); I.set(17, 27 + bob, W);
  I.shadeRight(c, C, 3); I.shadeRight(h, H, 2); I.shadeRight(W, g, 1);
  I.outline(K);
  return I;
}

// pastel retangular com borda "garfada"
function pastel(state) {
  const cols = [[2, 3, 4], [5, 6, 7], [8, 9, 10]][state];
  const [c1, c2, c3] = cols;
  const I = new Img(16, 16);
  for (let y = 4; y <= 12; y++) for (let x = 1; x <= 14; x++) {
    if ((x === 1 || x === 14) && (y === 4 || y === 12)) continue;
    const edge = x <= 2 || x >= 13 || y <= 5 || y >= 11;
    I.set(x, y, edge ? (((x + y) & 1) ? c3 : c2) : c1);
  }
  I.set(5, 7, c2); I.set(6, 7, c2); I.set(10, 8, c2); I.set(8, 9, c2); I.hline(3, 10, 10, c2);
  if (state === 0) { I.hline(4, 6, 4, 13); }
  if (state === 1) { I.hline(4, 6, 3, 14); }
  I.outline(1);
  return I;
}

function icon(name) {
  const k = 1, w = 2, g = 3, G = 4, y = 5, o = 6, b = 7, B = 8, r = 9, R = 10, n = 11, N = 12, p = 13, c = 14, u = 15;
  const I = new Img(16, 16);
  switch (name) {
    case 'carne':
      I.ell(2, 2, 13, 11, b); I.ell(9, 4, 12, 8, R, () => false);
      [[5, 4], [9, 5], [6, 8], [10, 9], [4, 6], [8, 7]].forEach(([x, yy]) => I.set(x, yy, B));
      I.ell(3, 3, 7, 5, r); I.ell(4, 3, 6, 4, p);
      I.shadeRight(b, B, 1); I.outline(k); break;
    case 'queijo':
      for (let yy = 2; yy <= 6; yy++) I.hline(13 - (yy - 2) * 2 - 2, yy, (yy - 2) * 2 + 2 + 0, y);
      I.rect(2, 7, 12, 5, o); I.hline(2, 6, 12, y);
      [[4, 8], [9, 9], [11, 7], [6, 10]].forEach(([x, yy]) => { I.set(x, yy, b); });
      I.outline(k); break;
    case 'frango':
      I.ell(2, 1, 10, 9, o); I.ell(3, 2, 6, 4, y);
      for (let t = 0; t < 4; t++) { I.set(9 + t, 8 + t, w); I.set(10 + t, 8 + t, w); }
      I.ell(11, 10, 13, 12, w); I.ell(12, 9, 14, 11, w);
      I.shadeRight(o, b, 1); I.outline(k); break;
    case 'calabresa':
      I.ell(1, 3, 9, 11, R); I.ell(2, 4, 8, 10, r); [[4, 6], [6, 8], [5, 9]].forEach(([x, yy]) => I.set(x, yy, p));
      I.ell(7, 2, 14, 9, R); I.ell(8, 3, 13, 8, r); [[10, 4], [11, 6], [9, 6]].forEach(([x, yy]) => I.set(x, yy, p));
      I.outline(k); break;
    case 'requeijao':
      I.ell(2, 8, 13, 12, w); I.ell(4, 5, 11, 9, w); I.ell(6, 2, 9, 6, w);
      I.hline(3, 11, 10, g); I.hline(5, 8, 6, g); I.set(7, 5, g);
      I.outline(k); break;
    case 'bacon':
      for (let x = 1; x <= 14; x++) { const off = Math.round(Math.sin(x / 2) * 1.2);
        I.set(x, 3 + off, R); I.set(x, 4 + off, c); I.set(x, 5 + off, r); I.set(x, 6 + off, R);
        I.set(x, 8 + off, R); I.set(x, 9 + off, c); I.set(x, 10 + off, r); I.set(x, 11 + off, R); }
      I.outline(k); break;
    case 'cadeado':
      I.frame(5, 1, 6, 7, G); I.frame(6, 2, 4, 5, G); I.rect(6, 3, 4, 4, 0);
      I.rect(3, 6, 10, 8, g); I.rect(3, 12, 10, 2, G); I.rect(7, 8, 2, 3, k);
      I.outline(k); break;
    case 'balao':
      I.rect(1, 1, 14, 11, w); I.set(1, 1, 0); I.set(14, 1, 0); I.set(1, 11, 0); I.set(14, 11, 0);
      I.rect(6, 12, 4, 1, w); I.rect(7, 13, 2, 1, w);
      I.outline(k); break;
    case 'mao':
      I.ell(1, 6, 14, 12, y); I.rect(2, 3, 3, 5, y); I.outline(k); break;
    case 'cursor':
      I.rect(5, 1, 6, 5, y); for (let t = 0; t < 5; t++) I.hline(2 + t, 6 + t, 12 - t * 2, y);
      I.vline(6, 1, 6, w); I.outline(k); break;
    case 'raiva':
      for (const [dx, dy, fx, fy] of [[2, 2, 1, 1], [9, 2, -1, 1], [2, 9, 1, -1], [9, 9, -1, -1]]) {
        const cx = fx > 0 ? dx : dx + 4, cy = fy > 0 ? dy : dy + 4;
        I.rect(cx, cy + fy * 2, 1, 3, r); I.rect(cx + fx * 1, cy + fy * 3, 3, 1, r);
      }
      I.outline(R); break;
    case 'coracao':
      I.ell(2, 2, 7, 7, r); I.ell(8, 2, 13, 7, r); for (let t = 0; t < 6; t++) I.hline(2 + t, 7 + t, 12 - t * 2, r);
      I.set(4, 4, p); I.set(5, 3, p); I.outline(k); break;
    case 'moeda':
      I.ell(2, 2, 13, 13, y); I.ell(4, 4, 11, 11, o); I.ell(5, 5, 10, 10, y);
      I.vline(7, 5, 6, b); I.vline(8, 5, 6, b); I.outline(k); break;
    case 'xis':
      for (let t = 0; t < 10; t++) { I.rect(3 + t, 3 + t, 2, 2, r); I.rect(12 - t, 3 + t, 2, 2, r); }
      I.outline(k); break;
    case 'loja':
    case 'franquia': {
      const roof = name === 'loja' ? r : u, roof2 = name === 'loja' ? R : u;
      I.rect(3, 7, 10, 7, c); I.rect(7, 10, 3, 4, b); I.rect(4, 9, 2, 2, u);
      for (let t = 0; t < 6; t++) I.hline(7 - t, 1 + t, 2 + t * 2, roof);
      I.hline(2, 6, 12, roof2);
      I.outline(k); break; }
    case 'estrela':
      I.vline(7, 1, 14, y); I.vline(8, 1, 14, y); I.hline(1, 7, 14, y); I.hline(1, 8, 14, y);
      I.rect(5, 5, 6, 6, y); I.rect(6, 6, 4, 4, w); I.outline(o); break;
    case 'refri':
      I.rect(5, 3, 6, 11, r); I.rect(6, 1, 4, 2, g); I.hline(5, 7, 6, w); I.outline(k); break;
  }
  return I;
}
function pastelFx(name) {
  const I = new Img(16, 16);
  if (name === 'fumaca') { I.ell(2, 6, 8, 12, 11); I.ell(6, 2, 12, 8, 11); I.ell(8, 7, 14, 13, 12); I.ell(3, 7, 6, 9, 13); }
  if (name === 'brilho') { I.vline(7, 2, 11, 14); I.hline(2, 7, 11, 14); I.set(7, 7, 13); I.set(6, 7, 13); I.set(8, 7, 13); I.set(7, 6, 13); I.set(7, 8, 13); I.set(3, 3, 14); I.set(11, 11, 14); }
  if (name === 'fogo') { I.ell(4, 4, 11, 14, 15); I.ell(6, 7, 9, 14, 14); }
  return I;
}
// mascote da logo: pastel sorridente (paleta 1). wink = piscando
function mascote(wink) {
  const I = new Img(32, 32);
  for (let y = 3; y <= 29; y++) for (let x = 5; x <= 26; x++) {
    if ((x === 5 || x === 26) && (y === 3 || y === 29)) continue;
    const edge = x <= 6 || x >= 25 || y <= 4 || y >= 28;
    I.set(x, y, edge ? (((x + y) & 1) ? 7 : 5) : 6);
  }
  for (let y = 5; y <= 27; y++) I.set(24, y, 7);
  [[9, 8], [20, 7], [15, 25], [22, 22], [9, 23], [18, 10], [11, 16]].forEach(([x, y]) => I.set(x, y, 7));
  I.hline(8, 6, 6, 5); I.hline(8, 7, 3, 5);
  if (wink) { I.set(10, 14, 1); I.set(11, 13, 1); I.set(12, 13, 1); I.set(13, 14, 1); }
  else { I.rect(11, 12, 2, 3, 1); I.set(11, 12, 13); }
  I.rect(19, 12, 2, 3, 1); I.set(19, 12, 13);
  [[11, 18], [12, 19], [13, 20], [14, 20], [15, 20], [16, 20], [17, 20], [18, 19], [19, 18]].forEach(([x, y]) => I.set(x, y, 1));
  I.set(9, 17, 15); I.set(22, 17, 15);
  I.outline(1);
  return I;
}
function digito(ch) {
  const I = new Img(8, 8), g = GLYPHS[ch];
  for (let y = 0; y < 7; y++) for (let x = 0; x < 5; x++) if (g[y][x] === '#') I.set(x + 1, y, 5);
  I.outline(1);
  return I;
}
// botoes do controle para o minijogo (16x16, paleta 0)
function botao(tipo) {
  const k = 1, w = 2, g = 3, G = 4, y = 5, o = 6, r = 9, R = 10, n = 11, N = 12, u = 15;
  const I = new Img(16, 16);
  const cores = { A: [r, R], B: [y, o], X: [u, k], Y: [n, N] };
  if (cores[tipo]) {
    const [c, c2] = cores[tipo];
    I.ell(1, 1, 14, 14, c2); I.ell(1, 1, 13, 13, c);
    I.set(4, 3, w); I.set(5, 3, w); I.set(3, 4, w);
    const gl = GLYPHS[tipo], cl = tipo === 'B' ? k : w; // letra preta no amarelo (contraste)
    for (let yy = 0; yy < 7; yy++) for (let xx = 0; xx < 5; xx++) if (gl[yy][xx] === '#') I.set(xx + 5, yy + 4, cl);
  } else if (tipo === 'OK') {
    I.ell(1, 1, 14, 14, N); I.ell(1, 1, 13, 13, n);
    [[4, 8], [5, 9], [6, 10], [7, 9], [8, 8], [9, 7], [10, 6], [11, 5]].forEach(([x, yy]) => { I.set(x, yy, w); I.set(x, yy + 1, w); });
  } else {
    // cruz direcional com o lado pedido aceso
    I.rect(6, 1, 4, 14, G); I.rect(1, 6, 14, 4, G); I.rect(6, 6, 4, 4, g);
    const arm = { U: [6, 1, 4, 5], D: [6, 10, 4, 5], L: [1, 6, 5, 4], R: [10, 6, 5, 4] }[tipo];
    I.rect(arm[0], arm[1], arm[2], arm[3], y);
    if (tipo === 'U') { I.set(7, 2, w); I.set(8, 2, w); I.hline(6, 3, 4, w); }
    if (tipo === 'D') { I.set(7, 13, w); I.set(8, 13, w); I.hline(6, 12, 4, w); }
    if (tipo === 'L') { I.set(2, 7, w); I.set(2, 8, w); I.vline(3, 6, 4, w); }
    if (tipo === 'R') { I.set(13, 7, w); I.set(13, 8, w); I.vline(12, 6, 4, w); }
  }
  I.outline(k);
  return I;
}
// botao 8x8 para aparecer no meio do texto (mesmas cores do botao do minijogo)
const LETRA3 = {
  A: ['.#.', '#.#', '###', '#.#', '#.#'], B: ['##.', '#.#', '##.', '#.#', '##.'],
  X: ['#.#', '#.#', '.#.', '#.#', '#.#'], Y: ['#.#', '#.#', '.#.', '.#.', '.#.'],
  L: ['#..', '#..', '#..', '#..', '###'], R: ['##.', '#.#', '##.', '#.#', '#.#'],
};
function botao8(tipo) {
  const k = 1, w = 2, g = 3, G = 4, y = 5, o = 6, r = 9, R = 10, n = 11, N = 12, u = 15;
  const I = new Img(8, 8);
  const cores = { A: [r, R], B: [y, o], X: [u, k], Y: [n, N] };
  if (cores[tipo]) {
    const [c, c2] = cores[tipo];
    // disco com contorno preto e sombra embaixo/direita no tom escuro
    I.rect(2, 0, 4, 8, k); I.rect(1, 1, 6, 6, k); I.rect(0, 2, 8, 4, k);
    I.rect(2, 1, 4, 6, c2); I.rect(1, 2, 6, 4, c2);
    I.rect(2, 1, 4, 5, c); I.rect(1, 2, 5, 3, c);
    const l = LETRA3[tipo], cl = tipo === 'B' ? k : w; // letra preta no amarelo (contraste)
    const lx = tipo === 'B' ? 3 : 2; // o B (aberto a direita) fica centrado 1 px adiante
    for (let yy = 0; yy < 5; yy++) for (let xx = 0; xx < 3; xx++) if (l[yy][xx] === '#') I.set(xx + lx, yy + 1, cl);
  } else if (tipo === 'L' || tipo === 'R') {
    // botao de ombro: retangulo cinza arredondado, mais alto do lado de fora
    I.rect(1, 0, 6, 8, k); I.rect(0, 1, 8, 7, k);
    I.rect(1, 1, 6, 6, G); I.rect(1, 1, 6, 5, g);
    I.set(tipo === 'L' ? 1 : 6, 1, w);
    const l = LETRA3[tipo];
    for (let yy = 0; yy < 5; yy++) for (let xx = 0; xx < 3; xx++) if (l[yy][xx] === '#') I.set(xx + 3 - (tipo === 'L' ? 1 : 0), yy + 1, k);
  } else {
    // cruz direcional com o lado pedido aceso
    I.rect(2, 0, 4, 8, k); I.rect(0, 2, 8, 4, k);
    I.rect(3, 1, 2, 6, G); I.rect(1, 3, 6, 2, G); I.rect(3, 3, 2, 2, g);
    const arm = { CIMA: [3, 1, 2, 2], BAIXO: [3, 5, 2, 2], ESQ: [1, 3, 2, 2], DIR: [5, 3, 2, 2] }[tipo];
    if (arm) I.rect(arm[0], arm[1], arm[2], arm[3], y);       // {CRUZ}: nenhum lado aceso
  }
  return I;
}
// entregas: telefone de parede, monitor de pedidos e moto do motoboy (paleta 0)
function entrega(tipo) {
  const k = 1, w = 2, g = 3, G = 4, y = 5, o = 6, b = 7, r = 9, R = 10, n = 11, u = 15;
  const I = new Img(16, 16);
  if (tipo === 'tel') {
    I.rect(3, 2, 10, 13, r); I.rect(4, 3, 8, 11, R);
    I.rect(1, 1, 14, 3, r); I.hline(2, 3, 12, R);                   // fone
    for (let yy = 0; yy < 3; yy++) for (let xx = 0; xx < 3; xx++) I.set(5 + xx * 2, 7 + yy * 2, w);  // teclas
    I.set(2, 4, k); I.set(2, 5, k); I.set(1, 6, k); I.set(1, 7, k);  // fio
  } else if (tipo === 'pc') {
    I.rect(1, 1, 14, 10, G); I.rect(2, 2, 12, 8, u);
    I.hline(3, 3, 6, w); I.hline(3, 5, 8, w); I.hline(3, 7, 5, y);
    I.rect(6, 11, 4, 2, G); I.rect(3, 13, 10, 2, g);
  } else {
    // moto vista de lado com o motoboy
    I.ell(1, 10, 5, 14, k); I.ell(10, 10, 14, 14, k); I.ell(2, 11, 4, 13, g); I.ell(11, 11, 13, 13, g);
    I.rect(4, 9, 8, 3, r); I.rect(10, 6, 2, 4, G); I.rect(1, 7, 4, 3, y);   // corpo, guidao, bau
    I.rect(6, 4, 3, 5, u); I.ell(6, 0, 10, 4, r); I.set(9, 2, w);           // motoboy e capacete
  }
  I.outline(k);
  return I;
}
function refriP() {
  const I = new Img(8, 8);
  I.rect(2, 1, 4, 7, 9); I.rect(3, 0, 2, 1, 3); I.hline(2, 3, 4, 2); I.outline(1);
  return I;
}

// Barra 8x8: moldura escura, trilho interno e brilho no preenchimento.
// Assim os indicadores continuam legiveis mesmo sobre o cenario claro da loja.
function bar(level, fill) {
  // formato de pilula: moldura arredondada, trilho fundo e preenchimento com
  // brilho em cima, sombra embaixo e um reflexo (visual de barra 3D)
  const I = new Img(8, 8);
  const w = Math.ceil(Math.min(level, 8) * 6 / 8);
  I.rect(0, 1, 8, 6, 1); I.hline(1, 0, 6, 1); I.hline(1, 7, 6, 1);
  I.rect(1, 1, 6, 6, 4);
  I.hline(1, 6, 6, 2);
  if (w) {
    I.rect(1, 1, w, 6, fill);
    I.hline(1, 1, w, 3); I.hline(1, 2, w, 3);
    I.hline(1, 6, w, 2);
    if (w >= 3) I.set(2, 3, 3);
  }
  return I;
}

// Reduz um icone 16x16 para 8x8: cada bloco 2x2 vira a cor mais comum (sem o
// contorno), e o contorno escuro e refeito em volta. Usado no sabor ao lado da cesta.
// sprite 8x8 a partir de 8 linhas de digitos hexadecimais (cor da paleta; e = 14)
function desenho8(linhas) {
  const o = new Img(8, 8);
  linhas.forEach((l, y) => [...l].forEach((c, x) => { if (c !== '.') o.set(x, y, parseInt(c, 16)); }));
  return o;
}
function mini(src) {
  const o = new Img(8, 8);
  for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) {
    const n = {};
    for (let j = 0; j < 2; j++) for (let i = 0; i < 2; i++) { const c = src.get(2 * x + i, 2 * y + j); if (c && c !== 1) n[c] = (n[c] || 0) + 1; }
    const cs = Object.keys(n);
    if (cs.length) o.set(x, y, +cs.reduce((a, b) => (n[b] > n[a] ? b : a)));
  }
  o.outline(1);
  return o;
}

// ----- alocador da folha de sprites (16 tiles de largura x 32 de altura)
// emojis: { nome: Img } de gerador/emoji_sprites.py (usados no lugar do desenho)
function buildSprites(emojis = {}) {
  const emo = (nome, desenho) => emojis[nome] || desenho();
  const sheet = new Img(128, 256); // cada pixel guarda (pal<<4)|cor para preview
  const occ = new Array(16 * 32).fill(false);
  const ids = {};
  function alloc(sz, minTy = 0) { // sz em tiles (1,2,4)
    for (let ty = minTy; ty < 32; ty++) for (let tx = 0; tx <= 16 - sz; tx++) {
      if (ty < 16 && ty + sz > 16) continue; if (ty + sz > 32) continue;
      let ok = true;
      for (let j = 0; j < sz && ok; j++) for (let i = 0; i < sz; i++) if (occ[(ty + j) * 16 + tx + i]) { ok = false; break; }
      if (ok) { for (let j = 0; j < sz; j++) for (let i = 0; i < sz; i++) occ[(ty + j) * 16 + tx + i] = true; return { tx, ty }; }
    }
    throw new Error('folha de sprites cheia (sz ' + sz + ')\n' + Array.from({ length: 32 }, (_, y) => occ.slice(y * 16, y * 16 + 16).map((o) => (o ? '#' : '.')).join('')).join('\n'));
  }
  function put(name, img, pal, minTy = 0) {
    const sz = img.w / 8, { tx, ty } = alloc(sz, minTy);
    for (let j = 0; j < img.h; j++) for (let i = 0; i < img.w; i++) { const c = img.get(i, j); if (c) sheet.set(tx * 8 + i, ty * 8 + j, (pal << 4) | c); }
    ids[name] = ty * 16 + tx; return ids[name];
  }
  CUST_SPECS.forEach((sp, v) => { for (let e = 0; e < 2; e++) put(`CUST_${v}_${e}`, person({ ...sp, expr: e }), 3 + v); ids[`CUST_${v}_2`] = ids[`CUST_${v}_0`]; });
  // turista (usa a paleta do fundador: pele, azul, amarelo)
  const TUR = { 1: 1, 2: 4, 3: 5, 4: 6, 5: 7, 6: 10, 7: 11, 8: 2, 9: 8, 10: 9, 11: 13, 12: 12 };
  for (let e = 0; e < 2; e++) {
    const im = person({ hair: 'palha', havaiana: true, expr: e, blush: true });
    for (let i = 0; i < im.p.length; i++) if (im.p[i]) im.p[i] = TUR[im.p[i]] || im.p[i];
    put(`CUST_5_${e}`, im, 2);
  }
  ids.CUST_5_2 = ids.CUST_5_0;
  put('FOUNDER_0', founderBack(0), 2); put('FOUNDER_1', founderBack(1), 2);
  // retratos: faixa separada (128x32) carregada por cima dos clientes so nas cartas
  const portImg = new Img(128, 32);
  PORT_SPECS.forEach((sp, i) => { portImg.paste(person(sp), i * 32, 0); ids[`PORT_${i}`] = i * 4; });
  const minis = [];
  ['carne', 'queijo', 'frango', 'calabresa', 'requeijao', 'bacon'].forEach((n, i) => {
    const im = emo(n, () => icon(n));
    put(`ICON_${i}`, im, 0); minis.push(mini(im));
  });
  put('MASCOTE_0', mascote(false), 1); put('MASCOTE_1', mascote(true), 1);
  for (const n of ['cadeado', 'balao', 'cursor', 'raiva', 'coracao', 'moeda', 'xis', 'estrela', 'refri', 'mao']) put(n.toUpperCase(), emo(n, () => icon(n)), 0);
  put('REFRI_P', refriP(), 0);
  const bola = (c) => () => { const I = new Img(16, 16); I.ell(1, 1, 14, 14, c); I.outline(1); return I; };
  const quadrado = (c) => () => { const I = new Img(16, 16); I.rect(2, 2, 12, 12, c); I.outline(1); return I; };
  // HUD: dia e hora (16x16, ponta das pilulas do topo; moeda e estrela ja existem)
  put('CALENDARIO', emo('calendario', quadrado(9)), 0); put('RELOGIO', emo('relogio', bola(15)), 0);
  // menu de pausa: continuar e sair (sem emoji: triangulo e casinha simples)
  put('PAUSA_CONT', emo('continuar', () => { const I = new Img(16, 16); I.rect(1, 1, 14, 14, 15); for (let j = 0; j < 8; j++) I.rect(5, 4 + j / 2 | 0, 1 + j, 8 - (j & ~1), 2); I.outline(1); return I; }), 0);
  // ajuda (pausa): item da pausa e icones das abas (sem emoji: um circulo de cor)
  put('PAUSA_AJUDA', emo('ajuda', bola(9)), 0);
  put('AJ_CONTROLE', emo('controle', bola(3)), 0); put('AJ_LIVRO', emo('livro', bola(15)), 0); put('AJ_GRAFICO', emo('grafico', bola(11)), 0);
  put('PAUSA_SAIR', emo('casa', () => { const I = new Img(16, 16); for (let j = 0; j < 6; j++) I.rect(7 - j, 1 + j, 2 + 2 * j, 1, 9); I.rect(3, 7, 10, 7, 14); I.rect(7, 10, 3, 4, 7); I.outline(1); return I; }), 0);
  { const b = new Img(8, 8); b.ell(1, 1, 6, 6, 13); b.ell(2, 2, 5, 5, 0); b.set(2, 2, 13); put('BOLHA', b, 1); }
  for (const b of ['U', 'D', 'L', 'R', 'A', 'B', 'X', 'Y', 'OK']) put('BTN_' + b, botao(b), 0);
  put('TELEFONE', emo('telefone', () => entrega('tel')), 0); put('MONITOR', emo('monitor', () => entrega('pc')), 0); put('MOTO', emo('moto', () => entrega('moto')), 0);
  // digitos amarelos 8x8 para o "+R$" flutuante
  '0123456789+$'.split('').forEach((ch, i) => put('DIG_' + (ch === '+' ? 'MAIS' : ch === '$' ? 'RS' : ch), digito(ch), 0));
  for (let s = 0; s < 3; s++) put(`PASTEL_${s}`, pastel(s), 1);
  for (const n of ['fumaca', 'brilho', 'fogo']) put(n.toUpperCase(), emo(n, () => pastelFx(n)), 1);
  // botoes do texto: a partir da linha 6 (tiles 96+), que as cartas e a loja nao sobrescrevem
  for (const b of BOTOES) put('BTN8_' + b, botao8(b), 0, 6);
  { const p = pilula(); put('PILULA_E', p.esq, 1, 6); put('PILULA_M', p.meio, 1, 6); put('PILULA_D', p.dir, 1, 6); }
  // barras: precisa de 27 tiles 8x8 consecutivos -> aloca 2 linhas inteiras
  let barBase = -1;
  for (let ty = 31; ty >= 16 && barBase < 0; ty--) {
    let free = true; for (let i = 0; i < 32; i++) { const t = (ty - 1) * 16 + i; if (t < 0 || occ[t]) { free = false; break; } }
    if (free) barBase = (ty - 1) * 16;
  }
  if (barBase < 0) throw new Error('sem espaco para barras');
  const fills = [11, 5, 9];
  for (let c = 0; c < 3; c++) for (let l = 0; l <= 8; l++) {
    const t = barBase + c * 9 + l, tx = t % 16, ty = (t / 16) | 0; occ[t] = true;
    const b = bar(l, fills[c]);
    for (let j = 0; j < 8; j++) for (let i = 0; i < 8; i++) { const cc = b.get(i, j); if (cc) sheet.set(tx * 8 + i, ty * 8 + j, cc); }
  }
  ids.BAR_BASE = barBase;
  // sabores 8x8 em tiles consecutivos (o jogo usa SPR_MINI + sabor, sem tabela)
  let miniBase = -1;
  for (let t = 16 * 16; t <= 512 - minis.length && miniBase < 0; t++) {
    if ((t % 16) + minis.length > 16) continue;
    let free = true; for (let i = 0; i < minis.length; i++) if (occ[t + i]) { free = false; break; }
    if (free) miniBase = t;
  }
  if (miniBase < 0) throw new Error('sem espaco para os sabores 8x8');
  minis.forEach((m, i) => {
    const t = miniBase + i, tx = t % 16, ty = (t / 16) | 0; occ[t] = true;
    for (let j = 0; j < 8; j++) for (let k = 0; k < 8; k++) { const c = m.get(k, j); if (c) sheet.set(tx * 8 + k, ty * 8 + j, c); }
  });
  ids.MINI = miniBase;
  // HUD: emojis 8x8 do rodape (reduzidos do emoji); por ultimo, nos buracos que
  // sobram depois das barras e dos sabores (que pedem tiles seguidos)
  // (o 📦 reduzido vira um borrao: a caixa de estoque e desenhada a mao)
  put('MINI_CAIXA', desenho8(['11111111', '166ee661', '177ee771', '11111111', '177ee771', '177ee771', '188ee881', '11111111']), 0);
  for (const [n, d] of [['coracao', () => icon('coracao')], ['alvo', bola(9)], ['estrela', () => icon('estrela')]])
    put('MINI_' + n.toUpperCase(), mini(emo(n, d)), 0);
  // tiles 4bpp (cor sem paleta)
  const raw = new Img(128, 256); for (let i = 0; i < raw.p.length; i++) raw.p[i] = sheet.p[i] & 15;
  const tiles = []; for (let t = 0; t < 512; t++) tiles.push(enc4(tilePixels(raw, t % 16, (t / 16) | 0)));
  const pals = [...SPAL, ...CUST_PALS.map(toPal)];
  const ptiles = []; for (let t = 0; t < 64; t++) ptiles.push(enc4(tilePixels(portImg, t % 16, (t / 16) | 0)));
  return { livres: occ.filter((x) => !x).length, tiles: Buffer.concat(tiles), ids, sheet, pals, portPals: PORT_PALS.map(toPal), portTiles: Buffer.concat(ptiles), portImg };
}

module.exports = {
  shopScene, shopPal, titleScene, menuScene, menuChecker, tutBalloon, PAL_TUT, TUT_BOX,
  ajudaBalloon, AJ_BOX, controleSFC, PAL_CTRL, CTRL_POS, teclaSenha, buildSprites, sceneToBG, palBytes,
  PAL_SHOP, PAL_TITLE, PAL_MENU, SPAL,
};
