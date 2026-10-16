// Animacoes grandes do expediente (BG2, paleta BG 5): junta as saidas de
// gerador/anim_<nome>.py (gen/anim_<nome>.json) e gera
//  - os tiles fixos do cartao (borda) e o mapa do BG2 com o cartao na tela;
//  - os quadros: cada um sao os 8x6 tiles do miolo, enviados inteiros pela NMI
//    para os mesmos tiles da VRAM quando o quadro muda (AnimDma em banco28.s).
//    Ficam nos bancos 29 a 31 (21 quadros por banco);
//  - gen/anim.inc: AnimQuadro (endereco longo de cada quadro), Anim<Nome>Chaves
//    (quadros-chave, relativos) e Anim<Nome>Extra (um byte por quadro).
// Os quadros de todas as animacoes ficam numa lista so: ANIM_<NOME> e o indice do
// primeiro e ANIM_<NOME>_N quantos sao.
'use strict';
const { enc4 } = require('./gfx');

const LARG = 64, ALT = 48, CART_L = 80, CART_A = 64;
const TX = LARG / 8, TY = ALT / 8, MIOLO = TX * TY;
const BYTES = MIOLO * 32;
const POR_BANCO = Math.floor(0x8000 / BYTES);
const BANCOS = [29, 30, 31];
// cartao na tela: colunas/linhas de tile do canto (cozinha, a esquerda, embaixo dos
// botoes do minijogo e abaixo do balcao, que tem prioridade alta; cobre a mesa dos
// sabores, que nao se usa durante o minijogo)
const COL = 2, LIN = 16;

const tile = (img, w, tx, ty) => {
  const px = [];
  for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) px.push(img[(ty * 8 + y) * w + tx * 8 + x]);
  return px;
};

// anims: [{ nome, dados }], fim: primeiro tile da VRAM que nao pode ser usado.
// Devolve os binarios, o .inc e as constantes.
function gerarAnims(anims, fim) {
  if (!anims.length) throw new Error('anim: nenhuma animacao');
  const pal = anims[0].dados.pal, cart = anims[0].dados.cartao;
  for (const a of anims) if (a.dados.pal.join() !== pal.join()) throw new Error('anim: paleta diferente em ' + a.nome);
  // borda do cartao: tiles fora do miolo (sem repetir)
  const borda = [], dict = new Map(), ent = [];
  for (let ty = 0; ty < CART_A / 8; ty++) for (let tx = 0; tx < CART_L / 8; tx++) {
    if (tx >= 1 && tx <= TX && ty >= 1 && ty <= TY) continue;
    const px = tile(cart, CART_L, tx, ty), k = px.join(',');
    if (!dict.has(k)) { dict.set(k, borda.length); borda.push(enc4(px)); }
    ent[ty * 32 + tx] = dict.get(k);
  }
  const base = fim - MIOLO - borda.length;          // borda, depois o miolo
  const slot = base + borda.length;
  const map = Buffer.alloc(2048);
  for (let ty = 0; ty < CART_A / 8; ty++) for (let tx = 0; tx < CART_L / 8; tx++) {
    const miolo = tx >= 1 && tx <= TX && ty >= 1 && ty <= TY;
    const t = miolo ? slot + (ty - 1) * TX + (tx - 1) : base + ent[ty * 32 + tx];
    map.writeUInt16LE(t | (5 << 10) | 0x2000, ((LIN + ty) * 32 + COL + tx) * 2);
  }
  // quadros
  const quadros = [], inc = [], consts = {};
  for (const a of anims) {
    const N = a.nome.toUpperCase(), Cap = a.nome[0].toUpperCase() + a.nome.slice(1);
    consts[`ANIM_${N}`] = quadros.length;
    consts[`ANIM_${N}_N`] = a.dados.quadros.length;
    consts[`ANIM_${N}_PX`] = COL * 8 + 8 + a.dados.ponto[0];
    consts[`ANIM_${N}_PY`] = LIN * 8 + 8 + a.dados.ponto[1];
    for (const q of a.dados.quadros) {
      const ts = [];
      for (let ty = 0; ty < TY; ty++) for (let tx = 0; tx < TX; tx++) ts.push(enc4(tile(q, LARG, tx, ty)));
      quadros.push(Buffer.concat(ts));
    }
    inc.push(`.segment "BANK28"`, `Anim${Cap}Chaves: .byte ${a.dados.chaves.join(', ')}`,
      `Anim${Cap}Extra: .byte ${a.dados.extra.join(', ')}`);
  }
  if (quadros.length > POR_BANCO * BANCOS.length) throw new Error(`anim: ${quadros.length} quadros, cabem ${POR_BANCO * BANCOS.length}`);
  const bins = {}, ptr = [];
  BANCOS.forEach((b, i) => {
    const qs = quadros.slice(i * POR_BANCO, (i + 1) * POR_BANCO);
    if (!qs.length) return;
    bins[`anim_b${b}.bin`] = Buffer.concat(qs);
    inc.push(`.segment "BANK${b}"`, `AnimB${b}: .incbin "gen/anim_b${b}.bin"`);
    qs.forEach((_, j) => ptr.push(`AnimB${b}+${j * BYTES}`));
  });
  inc.push(`.segment "BANK28"`, `AnimQuadro: .faraddr ${ptr.join(', ')}`);
  Object.assign(consts, {
    ANIM_TILE: base, ANIM_VRAM: base * 16, ANIM_SLOT_VRAM: slot * 16, ANIM_BYTES: BYTES,
    ANIM_BORDA_BYTES: borda.length * 32, ANIM_MAPA_VRAM: 0x5C00,
    ANIM_X0: COL * 8, ANIM_X1: COL * 8 + CART_L - 1, ANIM_Y0: LIN * 8, ANIM_Y1: LIN * 8 + CART_A - 1,
  });
  return { borda: Buffer.concat(borda), map, pal, bins, inc: inc.join('\n') + '\n', consts, base, n: quadros.length };
}

module.exports = { gerarAnims, BYTES };
