// Mapa da expansao (telas ST_MAP e ST_CHOOSE): cena 256x224 desenhada em RGB
// (terreno a mao + predios/arvores do Twemoji, gen/emoji_mapa.json), reduzida
// para 6 paletas de BG (2..7): a 2 e fixa (terreno, com a agua animada) e as
// outras 5 saem das cores dos tiles que nao cabem nela (sempre com o verde da
// grama e o contorno, para nao aparecer emenda).
// Lojas e franquias compradas sao "remendos" de tiles: o mapa base tem os
// terrenos em obra e as placas de venda; MapObras (src/banco28.s) escreve por
// cima o retangulo de cada unidade ja comprada.
'use strict';
const fs = require('fs'), path = require('path');
const { Img, enc4, flipH, flipV, png } = require('./gfx');

const W = 256, H = 224;
const hx = (s) => parseInt(s.slice(1), 16) & 0xF8F8F8;   // 15 bits (5 por canal)
const rgbHex = (c) => '#' + c.toString(16).padStart(6, '0');

// ---------------------------------------------------------------- paleta fixa (BG 2)
// 9 e 11: brilhos da agua (o jogo troca as duas cores a cada 16 quadros: a agua
// corre). A 9 comeca quase igual a 10 (mesmo tom, so para o indice ser outro)
const PAL_TERRA = [null, '#1C0A04', '#2F6F27', '#3E8E33', '#4FA83C', '#66C04A', '#4A4A52', '#6E6E78', '#E8E0C8',
  '#2E70C0', '#2E70C8', '#78B0F0', '#6A3E1C', '#A8703A', '#3A1A0C', '#C8A878'];
const T = {}; ['K', 'G0', 'G1', 'G2', 'G3', 'R0', 'R1', 'LZ', 'AB', 'AG', 'AC', 'M0', 'M1', 'BAR', 'AR']
  .forEach((k, i) => { T[k] = hx(PAL_TERRA[i + 1]); });
// cores que toda paleta automatica tambem tem (grama e contorno)
const FIXAS = [T.K, T.G0, T.G1, T.G2, T.G3];
const AGUA_COR = { 9: PAL_TERRA[10], 11: PAL_TERRA[11] };   // cores reais dos brilhos

// ---------------------------------------------------------------- unidades
// retangulos em tiles (x, y, l, a): o que muda quando a unidade e comprada
// lojas 1..4 (a 0, original, sempre existe) e franquias 0..4
const LOJAS = [
  { r: [4, 5, 6, 7], tipo: 'comercial' },     // 1 centro comercial
  { r: [14, 5, 5, 7], tipo: 'residencial' },  // 2 regiao residencial
  { r: [24, 15, 5, 4], tipo: 'faculdade' },   // 3 area universitaria
  { r: [25, 4, 4, 8], tipo: 'torre' },        // 4 distrito empresarial
];
const FRANQ = [[0, 3, 4, 4], [29, 3, 3, 4], [0, 19, 4, 4], [14, 20, 4, 4], [29, 15, 3, 4]];
// ponto (pixels) acima de cada unidade, para o cursor da escolha da loja (StoreXY)
const LOJA0 = { x: 104, y: 124 };

// ---------------------------------------------------------------- tela RGB
class Tela {
  constructor() { this.p = new Int32Array(W * H); }
  set(x, y, c) { x |= 0; y |= 0; if (x >= 0 && y >= 0 && x < W && y < H) this.p[y * W + x] = c; }
  get(x, y) { return this.p[y * W + x]; }
  rect(x, y, w, h, c) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) this.set(i, j, typeof c === 'function' ? c(i, j) : c); }
  ell(cx, cy, rx, ry, c) {
    for (let y = Math.floor(cy - ry); y <= cy + ry; y++) for (let x = Math.floor(cx - rx); x <= cx + rx; x++) {
      const dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1) this.set(x, y, typeof c === 'function' ? c(x, y) : c);
    }
  }
}

// ---------------------------------------------------------------- terreno
// textura da grama: repete a cada 32x32 (poucos tiles diferentes)
function grama(x, y) {
  const a = x & 31, b = y & 31;
  const h = ((a * 73856093) ^ (b * 19349663) ^ ((a + b) * 83492791)) >>> 0;
  if (h % 151 < 2) return T.G0;
  if (h % 19 === 0) return T.G1;
  if (h % 37 === 1 && b > 0) return T.G3;
  // tufinhos: um pixel claro em cima de um escuro
  const h2 = (((a) * 2654435761) ^ ((b + 1) * 40503)) >>> 0;
  if (h2 % 47 === 0) return T.G3;
  const h3 = (((a) * 2654435761) ^ ((b) * 40503)) >>> 0;
  if (h3 % 47 === 0) return T.G1;
  return T.G2;
}
// agua: tom medio com brilhos em faixas diagonais curtas (indices 9 e 11 se alternam)
function agua(x, y) {
  const k = ((x >> 1) + y * 3) % 14;
  if (k === 0 || k === 1) return T.AC;
  if (k === 7 || k === 8) return T.AB;
  return T.AG;
}
const rioX = (y) => 174 + 8 * Math.sin((y - 24) / 21 + 0.3);
const RIO_L = 8;   // meia largura

function terreno(t) {
  t.rect(0, 24, W, 168, grama);
  // lago no canto de baixo (margem marrom com contorno), cortado pela barra
  t.ell(262, 204, 66, 50, T.K); t.ell(262, 204, 64, 48, T.M0); t.ell(262, 204, 62, 46, agua);
  // rio sinuoso: margem de 2 px
  for (let y = 24; y < 192; y++) {
    const c = rioX(y);
    for (let x = Math.round(c - RIO_L - 2); x <= Math.round(c + RIO_L + 2); x++) {
      const d = Math.abs(x - c);
      t.set(x, y, d > RIO_L + 1 ? T.K : d > RIO_L ? T.M0 : agua(x, y));
    }
  }
  // plantacao (bairro rural): fileiras de terra arada com mudas, borda de madeira
  const px0 = 32, py0 = 122, pw = 48, ph = 44;
  t.rect(px0, py0, pw, ph, (x, y) => {
    const i = x - px0, j = y - py0;
    if (i === 0 || j === 0 || i === pw - 1 || j === ph - 1) return T.M0;
    const lin = (j - 2) % 8;
    if (lin === 6 || lin === 7 || j < 2) return T.M1;       // trilha entre fileiras
    const col = (i - 2) % 7;
    const muda = [[0, 1, 1, 1, 0], [1, 1, 2, 1, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0]];
    const m = (col >= 0 && col < 5 && i < pw - 2) ? muda[lin][col] : 0;
    return m === 2 ? T.G3 : m === 1 ? T.G1 : T.M0;
  });
  // estradas: asfalto com borda escura e faixa tracejada; faixa de pedestres no cruzamento
  const EH = { y: 104, x0: 0, x1: 256 }, EV = { x: 88, y0: 24, y1: 192 };
  t.rect(EH.x0, EH.y, EH.x1 - EH.x0, 16, (x, y) => (y === EH.y || y === EH.y + 15) ? T.R0 : T.R1);
  t.rect(EV.x, EV.y0, 16, EV.y1 - EV.y0, (x, y) => (x === EV.x || x === EV.x + 15) ? T.R0 : T.R1);
  t.rect(EV.x + 1, EH.y, 14, 16, T.R1);
  for (let x = EH.x0 + 2; x < EH.x1; x += 10) if (x + 6 < EV.x - 6 || x > EV.x + 21) t.rect(x, EH.y + 7, 6, 2, T.LZ);
  for (let y = EV.y0 + 2; y < EV.y1; y += 10) if (y + 6 < EH.y - 6 || y > EH.y + 21) t.rect(EV.x + 7, y, 2, 6, T.LZ);
  for (let k = 0; k < 4; k++) {
    t.rect(EV.x + 2 + k * 3, EH.y - 6, 2, 5, T.LZ); t.rect(EV.x + 2 + k * 3, EH.y + 17, 2, 5, T.LZ);
    t.rect(EV.x - 6, EH.y + 2 + k * 3, 5, 2, T.LZ); t.rect(EV.x + 17, EH.y + 2 + k * 3, 5, 2, T.LZ);
  }
  // ponte de madeira sobre o rio
  const bc = Math.round(rioX(112));
  t.rect(bc - 14, EH.y - 2, 28, 20, (x, y) => {
    if (y === EH.y - 2 || y === EH.y + 17) return T.K;
    if (y === EH.y - 1 || y === EH.y + 16) return T.M0;
    if (x === bc - 14 || x === bc + 13) return T.K;
    return (x - bc) % 3 === 0 ? T.M0 : T.M1;
  });
  // caminho de terra batida ate a torre (distrito empresarial)
  t.rect(208, 96, 10, 8, (x, y) => (x === 208 || x === 217) ? T.M1 : T.AR);
}

// ---------------------------------------------------------------- desenhos
let EMO = {};
function emoji(t, nome, x, y) {
  const e = EMO[nome];
  if (!e) return;
  for (let j = 0; j < e.h; j++) for (let i = 0; i < e.w; i++) {
    const o = (j * e.w + i) * 4;
    if (e.px[o + 3] >= 128) t.set(x + i, y + j, ((e.px[o] << 16) | (e.px[o + 1] << 8) | e.px[o + 2]) & 0xF8F8F8);
  }
}
const emoW = (n) => (EMO[n] ? EMO[n].w : 16), emoH = (n) => (EMO[n] ? EMO[n].h : 16);
// emoji centrado na horizontal, apoiado embaixo (sombra no chao)
function emojiChao(t, nome, cx, base) {
  const w = emoW(nome), h = emoH(nome);
  t.ell(cx, base - 1, w / 2 - 1, 2, T.G1);
  emoji(t, nome, Math.round(cx - w / 2), base - h);
}
function cerca(t, x, y, w, h) {
  for (let i = 0; i < w; i++) for (const yy of [y, y + h - 1]) t.set(x + i, yy, i % 4 === 0 ? T.K : T.R1);
  for (let j = 0; j < h; j++) for (const xx of [x, x + w - 1]) t.set(xx, y + j, j % 4 === 0 ? T.K : T.R1);
  for (let i = 0; i < w; i += 4) { t.set(x + i, y - 1, T.R0); t.set(x + i, y + h - 2, T.R0); }
}
// terreno em obra: chao de areia, cerca, guindaste e cavalete
function obra(t, [tx, ty, tw, th], grande) {
  const x = tx * 8 + 3, y = ty * 8 + 4, w = tw * 8 - 6, h = th * 8 - 7;
  t.rect(x, y, w, h, (i, j) => (((i * 7 + j * 5) % 17) === 0 ? T.M1 : T.AR));
  cerca(t, x, y, w, h);
  emoji(t, 'guindaste', x + w - emoW('guindaste') - 2, y + 3);
  emoji(t, 'cavalete', x + Math.round((w - emoW('cavalete')) / 2), y + h - emoH('cavalete') + 2);
  if (grande) emoji(t, 'trator', x + 4, y + Math.round(h / 2) - 4);
}
// calcada de pedra clara embaixo de um predio
function calcada(t, x, y, w, h) {
  t.rect(x, y, w, h, (i, j) => ((i + j) % 6 === 0 ? T.AR : T.LZ));
  for (let i = 0; i < w; i++) t.set(x + i, y + h, T.K);
}
// torre do distrito empresarial (a mao: vidro escuro com janelas acesas)
function torre(t, x, y, w, h) {
  const C = { k: T.K, c: hx('#3C2C48'), C: hx('#58466A'), j: hx('#F8D860'), J: hx('#8C7C50'), a: hx('#9AA0B8') };
  t.rect(x, y + 6, w, h - 6, C.k);
  t.rect(x + 1, y + 7, w - 2, h - 8, (i, j) => (i < x + 3 ? C.C : C.c));
  t.rect(x + 3, y + 3, w - 6, 4, C.k); t.rect(x + 4, y + 4, w - 8, 3, C.C);
  t.rect(x + Math.floor(w / 2), y - 4, 1, 7, C.a);                       // antena
  for (let j = y + 10; j < y + h - 10; j += 5) for (let i = x + 4; i < x + w - 4; i += 4) {
    const acesa = ((i * 3 + j * 7) % 5) !== 0;
    t.rect(i, j, 2, 3, acesa ? C.j : C.J);
  }
  t.rect(x + Math.floor(w / 2) - 3, y + h - 8, 6, 7, C.a); t.rect(x + Math.floor(w / 2), y + h - 8, 1, 7, C.k);   // porta
}
function lojaComprada(t, l) {
  const [tx, ty, tw, th] = l.r;
  const x = tx * 8, y = ty * 8, w = tw * 8, h = th * 8;
  if (l.tipo === 'torre') {
    calcada(t, x + 2, y + h - 10, w - 4, 6);
    torre(t, x + 5, y + 6, w - 10, h - 12);
    return;
  }
  const base = y + h - (h > 40 ? 8 : 5);
  calcada(t, x + 3, base - 6, w - 6, 8);
  emojiChao(t, l.tipo, x + w / 2, base);
  if (l.tipo === 'comercial') { emojiChao(t, 'arvore_p', x + 7, y + h - 18); emojiChao(t, 'arvore_p', x + w - 7, y + h - 18); }
}
function franquia(t, [tx, ty, tw, th], comprada) {
  const cx = tx * 8 + tw * 4, base = ty * 8 + th * 8 - 2;
  if (comprada) { calcada(t, cx - 13, base - 5, 26, 3); emojiChao(t, 'franquia', cx, base - 1); return; }
  // lote vazio a venda: terra com a placa
  t.ell(cx, base - 6, 10, 5, T.M0); t.ell(cx, base - 6, 9, 4, T.M1);
  emojiChao(t, 'placa', cx, base - 3);
}

function cena(lojas, franqs) {
  const t = new Tela();
  terreno(t);
  // arvores soltas
  for (const [n, x, y] of [['pinheiro', 12, 72], ['arvore', 16, 94], ['arvore', 116, 40], ['pinheiro', 138, 40],
    ['arvore', 240, 66], ['pinheiro', 238, 92], ['arvore', 10, 132], ['arvore_p', 20, 150], ['arvore_p', 154, 150],
    ['arvore', 64, 40], ['arvore_p', 200, 172], ['arvore_p', 82, 176], ['pinheiro', 40, 182]]) emojiChao(t, n, x, y);
  // trator na plantacao
  emoji(t, 'trator', 58, 145);
  // loja original (bairro inicial): casa grande no centro
  calcada(t, LOJA0.x + 2, 156, 44, 6);
  emojiChao(t, 'casa', LOJA0.x + 24, 160);
  LOJAS.forEach((l, i) => (i < lojas ? lojaComprada(t, l) : obra(t, l.r, i === 0)));
  FRANQ.forEach((f, i) => franquia(t, f, i < franqs));
  // faixas da HUD (titulo em cima; lojas, franquias e voltar embaixo)
  t.rect(0, 0, W, 24, (x, y) => (y === 23 ? T.K : y === 22 ? T.M0 : T.BAR));
  t.rect(0, 192, W, 32, (x, y) => (y === 192 ? T.K : y === 193 ? T.M0 : T.BAR));
  return t;
}

// ---------------------------------------------------------------- reducao de cores
const dist = (a, b) => {
  const dr = ((a >> 16) & 255) - ((b >> 16) & 255), dg = ((a >> 8) & 255) - ((b >> 8) & 255), db = (a & 255) - (b & 255);
  return 2 * dr * dr + 4 * dg * dg + 3 * db * db;
};
function maisPerto(c, pal) {
  let bi = 1, bd = Infinity;
  for (let i = 1; i < pal.length; i++) { const d = dist(c, pal[i]); if (d < bd) { bd = d; bi = i; } }
  return [bi, bd];
}
// k cores para um conjunto ponderado de cores (corte pela mediana + Lloyd)
function kcores(hist, k) {
  const cores = [...hist.keys()];
  if (cores.length <= k) return cores;
  let caixas = [cores];
  while (caixas.length < k) {
    let bi = -1, bs = -1, bc = 0;
    caixas.forEach((cx, i) => {
      if (cx.length < 2) return;
      for (let ch = 0; ch < 3; ch++) {
        const v = cx.map((c) => (c >> (16 - 8 * ch)) & 255), s = Math.max(...v) - Math.min(...v);
        const peso = cx.reduce((a, c) => a + hist.get(c), 0);
        if (s * Math.sqrt(peso) > bs) { bs = s * Math.sqrt(peso); bi = i; bc = ch; }
      }
    });
    if (bi < 0) break;
    const cx = caixas[bi].slice().sort((a, b) => ((a >> (16 - 8 * bc)) & 255) - ((b >> (16 - 8 * bc)) & 255));
    const m = cx.length >> 1;
    caixas.splice(bi, 1, cx.slice(0, m), cx.slice(m));
  }
  let cent = caixas.map((cx) => media(cx, hist));
  for (let it = 0; it < 10; it++) {
    const acc = cent.map(() => [0, 0, 0, 0]);
    for (const c of cores) {
      let bi = 0, bd = Infinity;
      cent.forEach((p, i) => { const d = dist(c, p); if (d < bd) { bd = d; bi = i; } });
      const n = hist.get(c), a = acc[bi];
      a[0] += ((c >> 16) & 255) * n; a[1] += ((c >> 8) & 255) * n; a[2] += (c & 255) * n; a[3] += n;
    }
    cent = acc.map((a, i) => (a[3] ? (((Math.round(a[0] / a[3]) << 16) | (Math.round(a[1] / a[3]) << 8) | Math.round(a[2] / a[3])) & 0xF8F8F8) : cent[i]));
  }
  return [...new Set(cent)];
}
function media(cx, hist) {
  let r = 0, g = 0, b = 0, n = 0;
  for (const c of cx) { const k = hist.get(c); r += ((c >> 16) & 255) * k; g += ((c >> 8) & 255) * k; b += (c & 255) * k; n += k; }
  return ((Math.round(r / n) << 16) | (Math.round(g / n) << 8) | Math.round(b / n)) & 0xF8F8F8;
}

const N_AUTO = 5;
function reduz(telas) {
  // tiles distintos (RGB) de todas as variantes
  const tiles = new Map();
  for (const t of telas) for (let ty = 0; ty < 28; ty++) for (let tx = 0; tx < 32; tx++) {
    const px = []; for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) px.push(t.get(tx * 8 + x, ty * 8 + y));
    const k = px.join(',');
    if (!tiles.has(k)) tiles.set(k, { px, pal: 0 });
  }
  const terra = [null, ...PAL_TERRA.slice(1).map(hx)], setTerra = new Set(terra.slice(1));
  const auto = [...tiles.values()].filter((t) => !t.px.every((c) => setTerra.has(c)));
  // grupos iniciais: pela cor media (fora grama/contorno), do mais escuro ao mais claro
  const fixas = new Set(FIXAS);
  const chave = (t) => { const o = t.px.filter((c) => !fixas.has(c)); return o.length ? media(o, new Map(o.map((c) => [c, 1]))) : 0; };
  auto.forEach((t) => { t.m = chave(t); t.lum = ((t.m >> 16) & 255) * 2 + ((t.m >> 8) & 255) * 4 + (t.m & 255) * 3; });
  auto.sort((a, b) => a.lum - b.lum || a.m - b.m);
  auto.forEach((t, i) => { t.g = Math.floor(i * N_AUTO / auto.length); });
  let pals = [];
  for (let it = 0; it < 8; it++) {
    pals = [];
    for (let g = 0; g < N_AUTO; g++) {
      const hist = new Map();
      for (const t of auto) if (t.g === g) for (const c of t.px) if (!fixas.has(c)) hist.set(c, (hist.get(c) || 0) + 1);
      const livres = kcores(hist, 15 - FIXAS.length);
      pals.push([null, ...FIXAS, ...livres]);
    }
    let mudou = 0;
    for (const t of auto) {
      let bg = t.g, be = Infinity;
      pals.forEach((p, g) => { const e = t.px.reduce((a, c) => a + maisPerto(c, p)[1], 0); if (e < be) { be = e; bg = g; } });
      if (bg !== t.g) { t.g = bg; mudou++; }
    }
    if (!mudou) break;
  }
  for (const t of auto) t.pal = 1 + t.g;
  const todas = [terra, ...pals];
  for (const t of tiles.values()) t.idx = t.px.map((c) => maisPerto(c, todas[t.pal])[0]);
  return { tiles, pals: todas };
}

// ---------------------------------------------------------------- tiles, mapa e remendos
function gerarMapa(emojis) {
  EMO = emojis || {};
  const base = cena(0, 0), cheia = cena(LOJAS.length, FRANQ.length);
  // cada unidade so pode mudar dentro do proprio retangulo
  const rets = [...LOJAS.map((l) => l.r), ...FRANQ];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (base.get(x, y) === cheia.get(x, y)) continue;
    const tx = x >> 3, ty = y >> 3;
    if (!rets.some(([rx, ry, rw, rh]) => tx >= rx && tx < rx + rw && ty >= ry && ty < ry + rh)) throw new Error(`mapa: mudanca fora das unidades em ${x},${y}`);
  }
  const { tiles, pals } = reduz([base, cheia]);
  const BG_PAL = 2;
  const dados = [], dict = new Map();
  const add = (px) => {
    const k = px.join(',');
    if (dict.has(k)) return dict.get(k);
    const id = dados.length; dados.push(enc4(px));
    dict.set(k, { id, f: 0 });
    for (const [f, q] of [[1, flipH(px)], [2, flipV(px)], [3, flipV(flipH(px))]]) { const kk = q.join(','); if (!dict.has(kk)) dict.set(kk, { id, f }); }
    return { id, f: 0 };
  };
  add(new Array(64).fill(0));
  const entrada = (t, tx, ty) => {
    const px = []; for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) px.push(t.get(tx * 8 + x, ty * 8 + y));
    const q = tiles.get(px.join(',')), e = add(q.idx);
    return e.id | ((BG_PAL + q.pal) << 10) | ((e.f & 1) << 14) | ((e.f & 2) << 14);
  };
  const map = Buffer.alloc(2048);
  for (let ty = 0; ty < 28; ty++) for (let tx = 0; tx < 32; tx++) map.writeUInt16LE(entrada(base, tx, ty), (ty * 32 + tx) * 2);
  // remendos: lojas 1..4 e franquias 0..4, na ordem que MapObras le
  const linhas = ['; gerado por gerador/mapa.js: remendos do mapa (lojas 1..4, franquias 0..4)', 'MapObraPtr:'];
  const corpo = ['MapObraDados:'];
  let off = 0;
  rets.forEach(([rx, ry, rw, rh], u) => {
    linhas.push(`  .word ${off}`);
    const ws = [];
    for (let ty = ry; ty < ry + rh; ty++) for (let tx = rx; tx < rx + rw; tx++) ws.push(entrada(cheia, tx, ty));
    corpo.push(`  .word VRAM_BG1MAP + ${ry * 32 + rx}`, `  .byte ${rw}, ${rh}`);
    for (let i = 0; i < ws.length; i += 12) corpo.push('  .word ' + ws.slice(i, i + 12).map((v) => '$' + v.toString(16).padStart(4, '0')).join(','));
    off += 4 + ws.length * 2;
  });
  if (dados.length > 1024) throw new Error('mapa: tiles demais: ' + dados.length);
  // paletas (BG 2..7); na 2 os brilhos da agua comecam no tom do jogo
  const palHex = pals.map((p, i) => [null, ...p.slice(1).map(rgbHex)].concat(Array(16).fill('#000000')).slice(0, 16));
  palHex[0][9] = AGUA_COR[9]; palHex[0][11] = AGUA_COR[11];
  // ponto de cada loja (0..4) para o cursor da escolha: centro, em cima do predio
  const xy = [[LOJA0.x + 16, LOJA0.y - 4], ...LOJAS.map((l) => [l.r[0] * 8 + l.r[2] * 4 - 8, l.r[1] * 8 - 2])];
  return {
    tiles: Buffer.concat(dados), map, count: dados.length, palHex,
    obras: [...linhas, ...corpo, `MAP_OBRAS_N = ${rets.length}`, 'StoreXY: .byte ' + xy.map(([x, y]) => `${x},${y}`).join(', '), ''].join('\n'),
    imgs: { base, cheia, tiles, pals },
  };
}

// pre-visualizacao (indices + paletas), como o SNES mostra
function preview(res, t) {
  const img = new Img(W, H);
  for (let ty = 0; ty < 28; ty++) for (let tx = 0; tx < 32; tx++) {
    const px = []; for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) px.push(t.get(tx * 8 + x, ty * 8 + y));
    const q = res.imgs.tiles.get(px.join(','));
    for (let i = 0; i < 64; i++) img.set(tx * 8 + (i & 7), ty * 8 + (i >> 3), (q.pal << 4) | q.idx[i]);
  }
  return png(img, res.palHex, 3);
}

module.exports = { gerarMapa, cena, preview, PAL_TERRA };

if (require.main === module) {
  const ROOT = path.join(__dirname, '..'), out = path.join(ROOT, 'gen', 'preview');
  fs.mkdirSync(out, { recursive: true });
  const emo = JSON.parse(fs.readFileSync(path.join(ROOT, 'gen', 'emoji_mapa.json'), 'utf8'));
  const r = gerarMapa(emo);
  fs.writeFileSync(path.join(out, 'mapa_base.png'), preview(r, r.imgs.base));
  fs.writeFileSync(path.join(out, 'mapa_cheio.png'), preview(r, r.imgs.cheia));
  console.log('mapa:', r.count, 'tiles');
}
