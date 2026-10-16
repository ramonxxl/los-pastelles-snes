// Audio: driver SPC700 minimo (proxy de escrita no DSP), samples BRR e musicas
'use strict';

// ---------- mapa da memoria do SPC700 (64 KB)
//  $0200 driver | $0300 diretorio de samples | $0400-$C3FF vozes fixas e chiado
//  $C400-$D3FF eco (ESA/EDL=2) | $D400-$DFB4 anel das falas (333 blocos BRR)
//  $E000-$FFBE anel da musica (903 blocos BRR)
// (aneis grandes = folgas maiores para atravessar os quadros mais pesados com as
// taxas altas; as vozes fixas a 9 kHz ocupam ate $C37E)
const ARAM = { DRIVER: 0x0200, DIR: 0x0300, FIXAS: 0x0400, FIXAS_FIM: 0xC400,
  ECO: 0xC400, ECO_FIM: 0xD400,
  FALA: 0xD400, FALA_LEN: 333 * 9, MUSICA: 0xE000, MUSICA_LEN: 903 * 9 };
const SRCN = { MUSICA: 3, FRITURA: 4, FALA: 5, FIXA0: 6 };   // 0-2: ondas do chiptune

// ---------- mini montador de SPC700 (so o que o driver usa)
// itens: [bytes...] | {rot: 'nome'} | {br: opcode, alvo: 'nome', pre: [bytes antes do deslocamento]}
function monta(org, itens) {
  const rot = {};
  for (let pass = 0; pass < 2; pass++) {
    let pc = org; const out = [];
    for (const it of itens) {
      if (Array.isArray(it)) { out.push(...it); pc += it.length; continue; }
      if (it.rot) { rot[it.rot] = pc; continue; }
      const pre = it.pre || [];
      const tam = 1 + pre.length + 1;
      const d = pass ? rot[it.alvo] - (pc + tam) : 0;
      if (pass && (d < -128 || d > 127)) throw new Error('desvio longe demais: ' + it.alvo);
      out.push(it.br, ...pre, d & 255); pc += tam;
    }
    if (pass) return out;
  }
}
const lo = (v) => v & 255, hi = (v) => v >> 8;
// Driver. A porta 0 muda a cada comando:
//  - bit 7 = 1: dados. 3 bytes (portas 1-3) vao para o ponteiro A ($02, bit 6 = 0:
//    musica e carga das fixas) ou B ($06, bit 6 = 1: falas), que avanca 3. Sem eco
//    de status, para ser rapido; a volta no anel e o CPU que comanda.
//  - bit 7 = 0: porta1 = registrador do DSP e porta2 = valor; ou porta1 = $80/$81:
//    ponteiro A/B = porta2/3. Esses comandos devolvem o ENDX na porta 1.
// Sempre ecoa a porta 0 no fim. No inicio avisa "pronto" ($D5 na porta 1) depois de
// ler a porta 0: sem isso o 1o comando do CPU pode ser tomado como valor inicial.
// O eco sai logo depois de gravar os 3 bytes, antes de avancar o ponteiro: o CPU
// ja escreve o proximo trio enquanto o SPC700 soma 3 (o envio e limitado pelo laco
// do SPC700, ~2 bytes por linha de video; isso tira a espera do CPU do caminho).
const DADOS = (p) => [
  [0x8D, 0x00],                                       // mov y,#0
  [0xE4, 0xF5, 0xD7, p, 0xFC],                        // mov a,$F5 / mov [p]+y,a / inc y
  [0xE4, 0xF6, 0xD7, p, 0xFC],
  [0xE4, 0xF7, 0xD7, p],
  [0xFA, 0x00, 0xF4],                                 // mov $F4,$00 (eco)
  [0x60, 0x98, 0x03, p, 0x98, 0x00, p + 1],           // clrc / adc p,#3 / adc p+1,#0
];
// No console a leitura de uma porta no mesmo instante em que o CPU a escreve pode
// vir com bits errados (os emuladores nao imitam isso). Um valor errado na porta 0
// virava um comando a mais (dados repetidos, que desalinham o BRR, ou escrita num
// registrador qualquer do DSP) e o som virava zumbido. Por isso a porta 0 e lida
// duas vezes e so vale quando as duas leituras batem.
// A RAM do SPC700 tambem nao comeca zerada no console: o driver zera o buffer do
// eco antes de avisar "pronto", senao o eco toca lixo ao ser ligado.
const DRIVER = monta(ARAM.DRIVER, [
  [0xE4, 0xF4, 0xC4, 0x00],                           // mov a,$F4 / mov $00,a
  [0xE8, 0x00, 0x8D, 0x00],                           // mov a,#0 / mov y,#0
  [0x8F, 0x00, 0x04, 0x8F, hi(ARAM.ECO), 0x05],       // $04/$05 = inicio do eco
  { rot: 'zera' },
  [0xD7, 0x04, 0xFC],                                 // mov [$04]+y,a / inc y
  { br: 0xD0, alvo: 'zera' },                         // bne zera
  [0xAB, 0x05, 0x78, hi(ARAM.ECO_FIM), 0x05],         // inc $05 / cmp $05,#fim
  { br: 0xD0, alvo: 'zera' },                         // bne zera
  [0x8F, 0xD5, 0xF5],                                 // mov $F5,#$D5 (pronto)
  { rot: 'laco' },
  [0xE4, 0xF4, 0x64, 0xF4],                           // mov a,$F4 / cmp a,$F4
  { br: 0xD0, alvo: 'laco' },                         // bne laco (mudou no meio)
  [0x64, 0x00],                                       // cmp a,$00
  { br: 0xF0, alvo: 'laco' },                         // beq laco
  [0xC4, 0x00, 0x5D],                                 // mov $00,a / mov x,a (mov dp,a nao mexe nos flags)
  { br: 0x10, alvo: 'cmd' },                          // bpl cmd (bit 7 = 0: comando)
  [0x28, 0x40],                                       // and a,#$40
  { br: 0xD0, alvo: 'dadosB' },                       // bne dadosB (bit 6: ponteiro B)
  ...DADOS(0x02),
  { br: 0x2F, alvo: 'laco' },
  { rot: 'dadosB' },
  ...DADOS(0x06),
  { br: 0x2F, alvo: 'laco' },
  { rot: 'cmd' },
  [0xE4, 0xF5],                                       // mov a,$F5
  { br: 0x30, alvo: 'ptr' },                          // bmi ptr
  [0xC4, 0xF2, 0xE4, 0xF6, 0xC4, 0xF3],               // mov $F2,a / mov a,$F6 / mov $F3,a
  { br: 0x2F, alvo: 'status' },
  { rot: 'ptr' },
  [0x68, 0x81],                                       // cmp a,#$81
  { br: 0xF0, alvo: 'ptrB' },
  [0xE4, 0xF6, 0xC4, 0x02, 0xE4, 0xF7, 0xC4, 0x03],   // ponteiro A = porta2/3
  { br: 0x2F, alvo: 'status' },
  { rot: 'ptrB' },
  [0xE4, 0xF6, 0xC4, 0x06, 0xE4, 0xF7, 0xC4, 0x07],   // ponteiro B = porta2/3
  { rot: 'status' },
  [0x8F, 0x7C, 0xF2, 0xE4, 0xF3, 0xC4, 0xF5],         // porta1 = ENDX
  { rot: 'ack' },
  [0xFA, 0x00, 0xF4],                                 // mov $F4,$00 (ecoa a porta 0)
  { br: 0x2F, alvo: 'laco' },
]);
if (DRIVER.length > ARAM.DIR - ARAM.DRIVER) throw new Error('driver do SPC700 grande demais');

// BRR com filtro 0: nibbles -8..7, shift 11 -> amplitude ~7k
function brr(levels) { // levels: multiplo de 16, valores -8..7
  const out = [];
  for (let b = 0; b < levels.length; b += 16) {
    const last = b + 16 >= levels.length;
    out.push((11 << 4) | (last ? 3 : 2));
    for (let i = 0; i < 16; i += 2) out.push(((levels[b + i] & 15) << 4) | (levels[b + i + 1] & 15));
  }
  return out;
}
function samples() {
  const sq = [], pu = [], tri = [];
  for (let i = 0; i < 32; i++) {
    sq.push(i < 16 ? 6 : -6);
    pu.push(i < 8 ? 6 : -6);
    const t = i < 16 ? i / 16 : (32 - i) / 16; // 0..1..0
    tri.push(Math.max(-8, Math.min(7, Math.round(t * 15 - 7.5))));
  }
  return [brr(sq), brr(tri), brr(pu)];
}

// extras: [{ inicio, loop }] para os SRCN 3.. (anel da musica, fritura, anel das falas, vozes fixas)
function spcBlob(extras = []) {
  const base = ARAM.DRIVER, dirAddr = ARAM.DIR;
  const smp = samples();
  const blob = new Array(dirAddr - base).fill(0);
  DRIVER.forEach((b, i) => { blob[i] = b; });
  const dir = [], data = [];
  let addr = dirAddr + (smp.length + extras.length) * 4;
  for (const s of smp) { dir.push(addr & 255, addr >> 8, addr & 255, addr >> 8); data.push(...s); addr += s.length; }
  for (const e of extras) dir.push(lo(e.inicio), hi(e.inicio), lo(e.loop), hi(e.loop));
  blob.push(...dir, ...data);
  if (base + blob.length > ARAM.FIXAS) throw new Error('driver + diretorio passam de $0400');
  // a sequencia do IPL termina com (tamanho+1)&255 != 0
  while (((blob.length + 1) & 255) === 0) blob.push(0);
  return Buffer.from(blob);
}

// ---------- tabela de afinacao: periodo de 32 samples. nota 1 = C2
function pitchTable() {
  const t = [0];
  for (let n = 1; n <= 72; n++) {
    const midi = n + 35, f = 440 * Math.pow(2, (midi - 69) / 12);
    t.push(Math.min(0x3FFF, Math.round(f * 32 / 32000 * 4096)));
  }
  return t;
}
const NOTE_IDX = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
function noteNum(tok) {
  const m = /^([A-G])([#b]?)(\d)$/.exec(tok);
  if (!m) throw new Error('nota invalida ' + tok);
  let midi = (parseInt(m[3]) + 1) * 12 + NOTE_IDX[m[1]] + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0);
  const n = midi - 35; if (n < 1 || n > 72) throw new Error('nota fora da faixa ' + tok);
  return n;
}
// formato do canal: [nota(0=pausa) dur] | F0 inst | F1 vol | FE loop | FF fim
function compileTrack(src, tempo, { inst = 0, vol = 0x40, loop = true } = {}) {
  const out = [0xF0, inst, 0xF1, vol];
  for (const tok of src.trim().split(/\s+/)) {
    if (tok === '|') continue;
    if (tok.startsWith('@')) { out.push(0xF0, parseInt(tok.slice(1))); continue; }
    if (tok.startsWith('v')) { out.push(0xF1, parseInt(tok.slice(1), 16)); continue; }
    const [n, d] = tok.split(':');
    let frames = Math.round(parseFloat(d) * tempo);
    const note = n === 'R' ? 0 : noteNum(n);
    let first = true;
    while (frames > 0) { const f = Math.min(frames, 250); out.push(first ? note : 0, f); frames -= f; first = false; }
  }
  out.push(loop ? 0xFE : 0xFF);
  return out;
}

// instrumentos: [sample, ADSR1, ADSR2]
const INSTR = [
  [0, 0xEF, 0xCC], // 0 quadrada (melodia)
  [1, 0xFF, 0xF0], // 1 triangulo (baixo)
  [2, 0xFE, 0x54], // 2 pulso curto (acordes)
  [0, 0xFF, 0xF0], // 3 quadrada sustentada (efeitos)
  [2, 0xFF, 0xF0], // 4 pulso sustentado (efeitos)
  [1, 0xFE, 0x76], // 5 triangulo curto (efeitos)
];

const bar = (s) => s;
// ---------- musicas (3 vozes: melodia, baixo, acordes)
const SONGS = {
  titulo: { tempo: 8, loop: true, ch: [
    [0, 0x38, `E5:2 G5:2 C6:4 B5:2 A5:2 G5:4 | F5:2 A5:2 G5:2 E5:2 C5:4 R:4 | D5:2 F5:2 A5:4 G5:2 F5:2 E5:4 | D5:2 E5:2 F5:2 D5:2 G5:8 |
               E5:2 G5:2 C6:4 D6:2 C6:2 A5:4 | F5:2 A5:2 C6:2 A5:2 G5:8 | F5:2 E5:2 D5:2 F5:2 E5:2 D5:2 C5:2 E5:2 | D5:4 G4:4 C5:8`],
    [1, 0x50, `C3:4 G3:4 C3:4 G3:4 | F2:4 C3:4 C3:4 G3:4 | D3:4 A3:4 D3:4 A3:4 | G2:4 D3:4 G2:4 B2:4 |
               C3:4 G3:4 A2:4 E3:4 | F2:4 C3:4 F2:4 A2:4 | D3:4 A2:4 G2:4 B2:4 | G2:4 G2:4 C3:8`],
    [2, 0x22, `R:2 E4:2 R:2 G4:2 R:2 E4:2 R:2 G4:2 | R:2 F4:2 R:2 A4:2 R:2 E4:2 R:2 G4:2 | R:2 F4:2 R:2 A4:2 R:2 F4:2 R:2 A4:2 | R:2 D4:2 R:2 B3:2 R:2 D4:2 R:2 F4:2 |
               R:2 E4:2 R:2 G4:2 R:2 C4:2 R:2 E4:2 | R:2 F4:2 R:2 A4:2 R:2 F4:2 R:2 A4:2 | R:2 F4:2 R:2 A4:2 R:2 D4:2 R:2 B3:2 | R:2 D4:2 R:2 F4:2 R:2 E4:2 R:2 G4:2`],
  ] },
  // (as musicas do expediente agora sao a musica gravada: sounds/, gerador/sons.js)
  resultado: { tempo: 7, loop: true, ch: [
    [0, 0x30, `C5:2 E5:2 G5:2 E5:2 F5:4 A5:4 | G5:2 E5:2 C5:2 E5:2 D5:8 | C5:2 E5:2 G5:2 C6:2 B5:4 A5:4 | G5:4 F5:2 D5:2 C5:8`],
    [1, 0x48, `C3:4 G2:4 F2:4 A2:4 | C3:4 E3:4 G2:4 B2:4 | A2:4 E3:4 F2:4 C3:4 | G2:4 G2:4 C3:8`],
    [2, 0x1C, `R:2 E4:2 R:2 G4:2 R:2 F4:2 R:2 A4:2 | R:2 E4:2 R:2 G4:2 R:2 D4:2 R:2 G4:2 | R:2 C4:2 R:2 E4:2 R:2 F4:2 R:2 A4:2 | R:2 D4:2 R:2 F4:2 R:2 E4:2 R:2 G4:2`],
  ] },
  vitoria: { tempo: 5, loop: false, ch: [
    [0, 0x40, `G5:2 G5:2 G5:2 C6:6 R:2 B5:2 C6:2 D6:2 E6:12`],
    [1, 0x50, `C3:2 C3:2 C3:2 E3:6 R:2 G2:2 G2:2 G2:2 C3:12`],
    [2, 0x28, `E5:2 E5:2 E5:2 G5:6 R:2 G5:2 A5:2 B5:2 C6:12`],
  ] },
  derrota: { tempo: 8, loop: false, ch: [
    [0, 0x38, `G4:3 F#4:3 F4:3 E4:9`],
    [1, 0x48, `C3:3 B2:3 Bb2:3 A2:9`],
    [2, 0x00, `R:18`],
  ] },
};

// efeitos: duracoes em quadros (tempo 1)
const SFX = {
  moeda: [4, 0x40, `B5:3 E6:10`],
  plop: [5, 0x50, `G3:3 C3:5`],
  pegar: [4, 0x38, `C5:2 G5:4`],
  erro: [3, 0x40, `C3:6 R:2 C3:8`],
  cursor: [4, 0x28, `A5:2`],
  ok: [4, 0x38, `C5:3 E5:3 G5:6`],
  alarme: [4, 0x30, `A5:4 R:2 A5:4`],
  bravo: [3, 0x40, `E3:4 C3:10`],
  nivel: [4, 0x38, `C5:4 E5:4 G5:4 C6:4 E6:4 G6:12`],
  sino: [4, 0x30, `E6:3 C6:8`],
  lixo: [5, 0x50, `E3:3 C3:3 A2:6`],
  queimou: [3, 0x38, `D4:4 C#4:4 C4:12`],
  // telefone de parede: trim-trim classico
  telefone: [4, 0x30, `E6:2 C6:2 E6:2 C6:2 E6:2 C6:2 E6:2 C6:2 R:8 E6:2 C6:2 E6:2 C6:2 E6:2 C6:2 E6:2 C6:2`],
  // alerta de pedido no aplicativo (estilo app de delivery: plim-plim brilhante)
  app: [0, 0x34, `E6:3 A6:3 E7:8 R:4 E6:3 A6:3 E7:8 R:4 C#7:3 E7:12`],
  buzina: [3, 0x38, `A4:5 R:3 A4:8`],
  // letra da caixa de texto aparecendo (bem baixinho)
  texto: [0, 0x16, `B6:1`],
};

function musicData() {
  const songs = [];
  const names = Object.keys(SONGS);
  for (const name of names) {
    const s = SONGS[name];
    songs.push({ name, tracks: s.ch.map(([inst, vol, src]) => compileTrack(src, s.tempo, { inst, vol, loop: s.loop })) });
  }
  const sfx = Object.keys(SFX).map((name) => { const [inst, vol, src] = SFX[name]; return { name, data: compileTrack(src, 1, { inst, vol, loop: false }) }; });
  return { songs, sfx };
}

module.exports = { spcBlob, pitchTable, musicData, INSTR, ARAM, SRCN };
