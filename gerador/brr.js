// Codificador e decodificador BRR (formato de amostra do DSP do SNES).
// Cada bloco: 1 byte de cabecalho (shift << 4 | filtro << 2 | loop << 1 | fim) e
// 8 bytes com 16 amostras de 4 bits. O decodificador segue o SPC_DSP do blargg (o
// mesmo comportamento do hardware); o codificador testa os 4 filtros e todos os shifts
// em cada bloco e fica com o de menor erro, acompanhando o estado do decodificador.
'use strict';

const clamp16 = (v) => (v > 32767 ? 32767 : v < -32768 ? -32768 : v);
const wrap16 = (v) => ((v & 0xFFFF) ^ 0x8000) - 0x8000;

// uma amostra: nibble com sinal (-8..7) -> saida (em 16 bits, ja "dobrada" como no DSP).
// Igual ao SPC_DSP (blargg), base do Mesen: nos filtros a amostra de 2 atras entra
// dividida por 2 (conferido contra as amostras que o DSP do Mesen decodifica)
function decodeSample(nib, shift, filter, p1, p2) {
  p2 >>= 1;
  let s = nib;
  if (shift <= 12) { s <<= shift; s >>= 1; } else s &= ~0x7FF;
  switch (filter) {
    case 1: s += p1 >> 1; s += (-p1) >> 5; break;
    case 2: s += p1; s -= p2; s += p2 >> 4; s += (p1 * -3) >> 6; break;
    case 3: s += p1; s -= p2; s += (p1 * -13) >> 7; s += (p2 * 3) >> 4; break;
  }
  return wrap16(clamp16(s) << 1);
}

// pcm: Int16Array (mono). primeiroFiltro0: o 1o bloco usa so o filtro 0 (inicio limpo).
// Retorna Buffer com os blocos (cabecalhos sem as flags de fim/loop).
function encode(pcm) {
  const n = Math.ceil(pcm.length / 16) * 16;
  const out = Buffer.alloc((n / 16) * 9);
  let p1 = 0, p2 = 0;
  for (let b = 0; b < n / 16; b++) {
    const x = new Array(16);
    for (let i = 0; i < 16; i++) x[i] = pcm[b * 16 + i] || 0;
    let best = null;
    const filtros = b === 0 ? [0] : [0, 1, 2, 3];
    for (const f of filtros) for (let sh = 0; sh <= 12; sh++) {
      let q1 = p1, q2 = p2, err = 0;
      const nibs = new Array(16);
      for (let i = 0; i < 16; i++) {
        // melhor nibble para esta amostra (testa os vizinhos da estimativa)
        let bn = 0, bs = 0, be = Infinity;
        for (let nb = -8; nb <= 7; nb++) {
          const s = decodeSample(nb, sh, f, q1, q2);
          const e = (s - x[i]) * (s - x[i]);
          if (e < be) { be = e; bn = nb; bs = s; }
        }
        nibs[i] = bn; err += be;
        if (best && err >= best.err) break;
        q2 = q1; q1 = bs;
      }
      if (!best || err < best.err) best = { err, f, sh, nibs, q1, q2 };
    }
    const o = b * 9;
    out[o] = (best.sh << 4) | (best.f << 2);
    for (let i = 0; i < 8; i++) out[o + 1 + i] = ((best.nibs[2 * i] & 15) << 4) | (best.nibs[2 * i + 1] & 15);
    p1 = best.q1; p2 = best.q2;
  }
  return out;
}

// decodifica blocos BRR -> Int16Array (para conferir a qualidade)
function decode(buf) {
  const out = new Int16Array((buf.length / 9) * 16);
  let p1 = 0, p2 = 0, k = 0;
  for (let o = 0; o < buf.length; o += 9) {
    const sh = buf[o] >> 4, f = (buf[o] >> 2) & 3;
    for (let i = 0; i < 16; i++) {
      const byte = buf[o + 1 + (i >> 1)];
      let nib = (i & 1) ? byte & 15 : byte >> 4;
      if (nib >= 8) nib -= 16;
      const s = decodeSample(nib, sh, f, p1, p2);
      out[k++] = s; p2 = p1; p1 = s;
    }
  }
  return out;
}

// muda quando o codificador muda: invalida o cache dos sons ja convertidos
const VERSAO = 2;

module.exports = { encode, decode, VERSAO };
