// Password (salvar sem SRAM): formato, alfabeto e tabelas
//
// O save vira um numero em BASE MISTA: cada campo e um "digito" cuja base e o
// numero de valores que ele pode ter (sem arredondar para potencia de 2), e
// P = (...((d0 * b1 + d1) * b2 + d2)...). Depois:
//   bits 0..BITS_P-1           P (embaralhado por um LFSR semeado pela verificacao)
//   bits BITS_P..TOTAL-1       verificacao: CRC-16 CCITT dos bytes (com estes bits
//                              zerados), os bits de baixo, XOR CHAVE_VER
// TOTAL = N_SIMB * 5 bits = N_SIMB simbolos do alfabeto de 32.
//
// Para caber em menos simbolos:
// - chefe + nivel + xp viram um indice so (tabela LVXP pre-calculada: o nivel
//   fica entre o teto do desafio anterior e o do proximo, e o xp vai de 8 em 8);
// - dinheiro em "ponto flutuante": exato ate R$ 511, depois 9 bits de mantissa
//   (perde no maximo 0,2%);
// - estoque, contadores e duelos em degraus (tabelas) alinhados com os limites
//   que missoes e trofeus conferem: so o progresso entre degraus se perde;
// - reputacao de 2 em 2 (o limite de 70 da franquia continua exato);
// - o que da para deduzir nao entra (SenhaDeriva): capitulo = desafios vencidos,
//   final = 10 unidades, melhorias = fritadeira + balcao, tutorial = dia >= 2,
//   pasteis fritos e vendas (so contam para as missoes 0 e 1).
// Ficam so na SRAM: opcoes, historico de lucro e os trofeus que o TrophyCheck
// recalcula (do s_trof so entram os bits 5..7, via pw_trof).
'use strict';

// sem O/0 e I/1 (parecidos demais para anotar)
const ALFABETO = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const VERSAO = 2, N_SIMB = 20, TOTAL = N_SIMB * 5;
const CHAVE_VER = 0x1A3, CHAVE_LFSR = 0x9E37;
const BIG = 12;                     // bytes do numero grande (P cabe em 96 bits)

// nivel: xp para subir = 25 * nivel + 80; tetos de nivel por desafios vencidos
// (LevelCap em telas.s; o ultimo e 99)
const { NV } = require('./niveis');
const TETOS = [NV.DESAFIO0, NV.DESAFIO1, NV.DESAFIO2, NV.DESAFIO3, 99];
const XP_PASSO = 8;
const xpNeed = (L) => 25 * L + 80;
const LVXP = [];                    // [desafios, nivel, inicio do indice]
{
  let base = 0;
  TETOS.forEach((teto, b) => {
    for (let L = b ? TETOS[b - 1] : 1; L <= teto; L++) {
      LVXP.push([b, L, base]);
      base += Math.ceil(xpNeed(L) / XP_PASSO);
    }
  });
  LVXP.total = base;
}

// degraus (o valor guardado e o maior degrau <= valor real)
const TAB = {
  estoque: [...Array(200).keys(), ...Array.from({ length: 80 }, (_, i) => 200 + 10 * i)],  // exato ate 199
  felizes: [0, 1, 10, 25, 50, 100, 250, 500],      // missoes 3, 6; trofeus 1, 100, 500
  perfeitos: [0, 5, 15, 30, 50, 100, 200, 300],    // missao 4; trofeus 50, 300
  entregas: [0, 25, 50, 100],                      // trofeu 100
  duelos: [0, 2, 5],                               // trofeu 5 (raros: 3 degraus pagam o estoque exato)
};

const DIN_MANT = 512, DIN_EXP = 15;     // digito do dinheiro: 0..DIN_MANT*(DIN_EXP+1)-1

// tipos: 0 faixa (min, max, deslocamento), 1 degraus, 2 dinheiro, 3 nivel+xp
const T_FAIXA = 0, T_TAB = 1, T_DIN = 2, T_LVXP = 3;
// [tipo, variavel, bytes, ...]
const CAMPOS = [
  [T_FAIXA, 'pw_versao', 1, 0, 3, 0],
  [T_FAIXA, 's_day', 2, 1, 255, 0],
  [T_DIN, 's_money', 4],
  [T_TAB, 's_stock', 2, 'estoque'],
  [T_LVXP, 's_level', 1],
  [T_FAIXA, 's_rep', 1, 0, 100, 1],
  [T_FAIXA, 's_fryer', 1, 1, 3, 0],
  [T_FAIXA, 's_counter', 1, 1, 3, 0],
  [T_FAIXA, 's_attend', 1, 0, 1, 0],
  [T_FAIXA, 's_ads', 1, 0, 1, 0],
  [T_FAIXA, 's_pc', 1, 0, 1, 0],
  [T_FAIXA, 's_moto', 1, 0, 1, 0],
  [T_FAIXA, 's_freezer', 1, 0, 1, 0],
  [T_FAIXA, 's_ar', 1, 0, 1, 0],
  [T_FAIXA, 's_musica', 1, 0, 1, 0],
  [T_FAIXA, 's_unif', 1, 0, 1, 0],
  [T_FAIXA, 's_stores', 1, 0, 4, 0],
  [T_FAIXA, 's_fran', 1, 0, 5, 0],
  [T_FAIXA, 's_mission', 1, 0, 14, 0],
  [T_FAIXA, 's_promo', 1, 0, 1, 0],
  [T_FAIXA, 's_price', 1, 0, 3, 0],
  [T_FAIXA, 'pw_tflags', 1, 0, 7, 0],      // s_tflags bits 0..2
  [T_FAIXA, 's_reforma', 1, 0, 2, 0],
  [T_TAB, 's_tot_happy', 2, 'felizes'],
  [T_TAB, 's_tot_perf', 2, 'perfeitos'],
  [T_TAB, 's_tot_dlv', 2, 'entregas'],
  [T_TAB, 's_duels', 1, 'duelos'],
  [T_FAIXA, 'pw_trof', 1, 0, 7, 0],        // s_trof bits 5..7
];

const base = (c) => {
  switch (c[0]) {
    case T_FAIXA: return ((c[4] - c[3]) >> c[5]) + 1;
    case T_TAB: return TAB[c[3]].length;
    case T_DIN: return DIN_MANT * (DIN_EXP + 1);
    default: return LVXP.total;
  }
};
const log2 = CAMPOS.reduce((s, c) => s + Math.log2(base(c)), 0);
const BITS_P = Math.ceil(log2);
const BITS_VER = TOTAL - BITS_P;
if (CAMPOS.some((c) => base(c) > 65535)) throw new Error('password: base de campo maior que 16 bits');
if (BITS_P > BIG * 8) throw new Error(`password: ${BITS_P} bits nao cabem no numero de ${BIG} bytes`);
if (BITS_VER < 9) throw new Error(`password: so ${BITS_VER} bits de verificacao (minimo 9)`);

// gen/senha.inc: constantes e tabelas (banco 28)
function inc(CODE) {
  const L = ['; gerado por build.js (gerador/senha.js) - formato do password'];
  const bytes = Math.ceil(TOTAL / 8), bytesP = Math.ceil(BITS_P / 8);
  L.push(`SENHA_VERSAO = ${VERSAO}`, `SENHA_N = ${N_SIMB}`, `SENHA_BITS_P = ${BITS_P}`,
    `SENHA_BITS_VER = ${BITS_VER}`, `SENHA_BYTES = ${bytes}`, `SENHA_BYTES_P = ${bytesP}`,
    `SENHA_MASC_P = $${((0xFF00 >> (BITS_P - 8 * (bytesP - 1))) & 0xFF).toString(16)}`,
    `SENHA_MASC_VER = $${((1 << BITS_VER) - 1).toString(16)}`,
    `SENHA_CHAVE_VER = $${CHAVE_VER.toString(16)}`, `SENHA_CHAVE_LFSR = $${CHAVE_LFSR.toString(16)}`,
    `SENHA_BIG = ${BIG}`, `SENHA_CAMPOS = ${CAMPOS.length}`, `SENHA_LVXP_N = ${LVXP.length}`,
    `SENHA_XP_DESL = ${Math.log2(XP_PASSO)}`, `SENHA_DIN_MANT = ${DIN_MANT}`, `SENHA_DIN_EXP = ${DIN_EXP}`,
    `SENHA_T_FAIXA = ${T_FAIXA}`, `SENHA_T_TAB = ${T_TAB}`, `SENHA_T_DIN = ${T_DIN}`, `SENHA_T_LVXP = ${T_LVXP}`);
  L.push('; por campo (10 bytes): tipo, bytes, endereco, base, e conforme o tipo:',
    ';   faixa: minimo, maximo, deslocamento   degraus: tabela (.word)');
  L.push('SenhaCampos:');
  for (const c of CAMPOS) {
    const [t, v, tam] = c;
    L.push(`    .byte ${t}, ${tam}`, `    .word ${v}, ${base(c)}`);
    if (t === T_FAIXA) L.push(`    .byte ${c[3]}, ${c[4]}, ${c[5]}, 0`);
    else if (t === T_TAB) L.push(`    .word .loword(SenhaTab_${c[3]}), 0`);
    else L.push('    .word 0, 0');
  }
  for (const [n, t] of Object.entries(TAB)) L.push(`SenhaTab_${n}: .word ${t.join(', ')}`);
  L.push('; nivel + xp: por par (desafios, nivel) em ordem, o inicio do indice');
  L.push('SenhaLvDes: .byte ' + LVXP.map((e) => e[0]).join(', '));
  L.push('SenhaLvNiv: .byte ' + LVXP.map((e) => e[1]).join(', '));
  L.push('SenhaLvIni: .word ' + [...LVXP.map((e) => e[2]), LVXP.total].join(', '));
  L.push(`SENHA_TRACO = ${CODE['-']}`, `SENHA_BLOCO = ${CODE['■']}`);
  L.push('SenhaAlfa:', '    .byte ' + [...ALFABETO].map((ch) => CODE[ch]).join(', '));
  return L.join('\n') + '\n';
}

module.exports = { ALFABETO, VERSAO, N_SIMB, TOTAL, BITS_P, BITS_VER, CAMPOS, inc, log2 };
