// Abertura "RAMON" (homenagem as aberturas da Konami): monta os graficos e a tabela
// de paletas a partir de arte_fonte/abertura/abertura.json (gerador/abertura_ramon.py).
//   BG1 (tiles 16x16, mapa 32x32 = 512x512 px): a "cortina". Linha 1 do mapa: o laser
//     (x 0..255), a faisca da ponta (x 256..271, 4 formas em AB_FAISCA + 2k) e preto;
//     linhas 2..15: preto; o resto transparente. A rolagem (src/banco28.s) traz o
//     laser da esquerda e depois desce, revelando o BG2.
//   BG2 (tiles 8x8): a logo na posicao da tela, paletas 0..1.
//   Sprites 16x16 (paleta OBJ 0 = copia da paleta 2): a perna do R, com prioridade 1,
//     atras do BG2 (o bojo fica na frente) e da cortina. Ela encontra o amarelo numa
//     curva, e cada tile do BG so tem uma paleta.
//   Paletas: as cores 0..63 em cada quadro em que mudam.
'use strict';
const { enc4 } = require('./gfx');

const LETRAS = '.' + '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/';
const idx = (ch) => { const i = LETRAS.indexOf(ch); if (i < 0) throw new Error('abertura: cor invalida ' + ch); return i; };

// tiles 16x16 da cortina (numero do tile 8x8 do canto de cima a esquerda)
const T_VAZIO = 0, T_PRETO = 2, T_FEIXE = 4, T_FAISCA = 6;   // faisca: 6, 8, 10, 12
const RESERVADO = (t) => (t & 15) < 14 && t < 32;     // tiles 0..13 e 16..29

function gerarAbertura(J) {
  const tiles = [];                 // tiles 8x8 (32 bytes cada), pelo numero
  const vazio = Buffer.alloc(32), vazio32 = vazio;
  const put = (n, px) => { while (tiles.length <= n) tiles.push(vazio); tiles[n] = enc4(px); };

  // ---- cortina: cada bloco 16x16 vira os tiles n, n+1, n+16, n+17
  const bloco16 = (n, cor) => {   // cor(x, y) -> indice 0..15
    for (let q = 0; q < 4; q++) {
      const ox = (q & 1) * 8, oy = (q >> 1) * 8, px = [];
      for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) px.push(cor(ox + x, oy + y));
      put(n + (q & 1) + (q >> 1) * 16, px);
    }
  };
  const feixe = J.feixe.split(' ').map(idx);
  const faiscas = J.faiscas.map((f) => f.map((l) => [...l].map(idx)));
  const palDe = (v) => v >> 4;
  for (const v of [...feixe, ...faiscas.flat(2)]) if (v && palDe(v) !== 3) throw new Error('abertura: laser fora da paleta 3');
  bloco16(T_VAZIO, () => 0);
  bloco16(T_PRETO, () => 1);
  bloco16(T_FEIXE, (x, y) => feixe[y] & 15);
  faiscas.forEach((f, k) => bloco16(T_FAISCA + 2 * k, (x, y) => f[y][x] & 15));
  const bg1 = Buffer.alloc(2048);
  for (let ty = 0; ty < 32; ty++) for (let tx = 0; tx < 32; tx++) {
    let e = T_VAZIO;
    if (ty === 1) e = tx < 16 ? T_FEIXE | (3 << 10) : tx === 16 ? T_FAISCA | (3 << 10) : T_PRETO;
    else if (ty >= 2 && ty < 16) e = T_PRETO;
    bg1.writeUInt16LE(e, (ty * 32 + tx) * 2);
  }

  // ---- logo (BG2): imagem da tela inteira cortada em tiles 8x8 iguais aos do mapa
  const W = 256, H = 224, img = new Uint8Array(W * H), obj = new Uint8Array(W * H);
  J.logo.linhas.forEach((l, y) => [...l].forEach((ch, x) => {
    const v = idx(ch), i = (J.logo.y + y) * W + J.logo.x + x;
    if (palDe(v) === 2) obj[i] = v; else img[i] = v;
  }));
  const bg2 = Buffer.alloc(2048), dict = new Map();
  let livre = 0;
  for (let ty = 0; ty < 28; ty++) for (let tx = 0; tx < 32; tx++) {
    const px = [];
    for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) px.push(img[(ty * 8 + y) * W + tx * 8 + x]);
    if (px.every((c) => !c)) continue;
    const pals = new Set(px.filter((c) => c).map(palDe));
    if (pals.size > 1) throw new Error(`abertura: tile (${tx},${ty}) da logo com mais de uma paleta`);
    const pal = [...pals][0], cor = px.map((c) => c & 15), k = cor.join(',');
    if (!dict.has(k)) {
      while (RESERVADO(livre)) livre++;
      dict.set(k, livre); put(livre, cor); livre++;
    }
    bg2.writeUInt16LE(dict.get(k) | (pal << 10), (ty * 32 + tx) * 2);
  }

  // ---- perna (sprites 16x16 numa grade a partir do canto da perna; o sprite k usa
  // os tiles OBJ 2k%16 + 32*(k>>3), +1, +16, +17)
  let ox = W, oy = H;
  for (let i = 0; i < W * H; i++) if (obj[i]) { ox = Math.min(ox, i % W); oy = Math.min(oy, (i / W) | 0); }
  const objTiles = [], oam = [];
  for (let sy = oy; sy < H; sy += 16) for (let sx = ox; sx < W; sx += 16) {
    const cor = (x, y) => (sx + x < W && sy + y < H ? obj[(sy + y) * W + sx + x] & 15 : 0);
    let vazio = true;
    for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) if (cor(x, y)) vazio = false;
    if (vazio) continue;
    const k = oam.length, n = (k & 7) * 2 + (k >> 3) * 32;
    for (let q = 0; q < 4; q++) {
      const px = [];
      for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) px.push(cor((q & 1) * 8 + x, (q >> 1) * 8 + y));
      const t = n + (q & 1) + (q >> 1) * 16;
      while (objTiles.length <= t) objTiles.push(vazio32);
      objTiles[t] = enc4(px);
    }
    oam.push([sx, sy, n]);
  }
  if (oam.length > 32) throw new Error('abertura: sprites demais na perna do R');

  // ---- paletas: 128 bytes (cores 0..63) por mudanca, com o quadro em que entra
  const pal = Buffer.alloc(J.paletas.length * 128);
  J.paletas.forEach((p, i) => p.cores.split(' ').forEach((h, c) => pal.writeUInt16LE(parseInt(h, 16), i * 128 + c * 2)));
  const quadros = J.paletas.map((p) => p.q);
  if (quadros[0] !== 0) throw new Error('abertura: a primeira paleta tem de entrar no quadro 0');

  return { tiles: Buffer.concat(tiles), nTiles: tiles.length, nLogo: dict.size, bg1, bg2, pal, quadros, faisca: T_FAISCA | (3 << 10),
    objTiles: Buffer.concat(objTiles), oam };
}

module.exports = { gerarAbertura };
