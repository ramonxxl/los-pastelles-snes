// Build da ROM "Los Pastelles: O Imperio do Pastel" (SNES, LoROM SlowROM 1 MB)
// Uso: node build.js
'use strict';
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const A = require('./gerador/arte');
const F = require('./gerador/fonte');
const AU = require('./gerador/audio');
const { T, CARDS } = require('./gerador/textos');
const V = require('./gerador/versao');
const { palBytes } = require('./gerador/gfx');

const ROOT = __dirname, GEN = path.join(ROOT, 'gen');
// interpretador Python: variavel PYTHON, senao "python" no Windows e "python3" nos demais
const PY = process.env.PYTHON || (process.platform === 'win32' ? 'python' : 'python3');
fs.mkdirSync(GEN, { recursive: true });
const w = (name, buf) => fs.writeFileSync(path.join(GEN, name), buf);
const hex2 = (n) => '$' + n.toString(16).toUpperCase().padStart(2, '0');
const hex4 = (n) => '$' + n.toString(16).toUpperCase().padStart(4, '0');
const byteLines = (arr) => { const out = []; for (let i = 0; i < arr.length; i += 16) out.push('  .byte ' + arr.slice(i, i + 16).map(hex2).join(',')); return out.join('\n'); };

// ------------------------------------------------------------ versao (gerador/versao.js)
// entra so como texto (abertura e carta de creditos): nao muda nada do jogo nem do save
const VERSAO = V.versaoDoJogo();
const VERSAO_TXT = 'VERSÃO ' + V.versaoNaTela(VERSAO);
CARDS.CREDITOS[2] += '\n\n' + VERSAO_TXT;
T.SP_VER = VERSAO_TXT;                              // abertura, centralizada (SP_VER_COL)
fs.writeFileSync(path.join(GEN, 'versao.txt'), VERSAO + '\n');
console.log(`versao: ${VERSAO}`);

// ------------------------------------------------------------ logo (gerador/logo.py)
// Python/Pillow so e necessario quando a imagem da logo foi alterada. Com os
// recursos ja gerados, o restante da ROM continua compilavel em um PC sem Python.
const logoIdx = path.join(GEN, 'logo_idx.bin');
const logoPalFile = path.join(GEN, 'logo_pal.json');
try {
  execFileSync(PY, [path.join('gerador', 'logo.py')], { cwd: ROOT, stdio: 'inherit' });
} catch (e) {
  if (!fs.existsSync(logoIdx) || !fs.existsSync(logoPalFile)) throw e;
  console.warn('Python indisponivel: reutilizando a logo ja gerada em gen/.');
}
const { Img } = require('./gerador/gfx');
const logoImg = new Img(256, 224);
logoImg.p.set(fs.readFileSync(logoIdx));
const logoPal = [null, ...JSON.parse(fs.readFileSync(logoPalFile, 'utf8')).cores];

// ------------------------------------------------------------ cenarios
// xadrez animado dos menus (BG2): tiles no fim da area do BG1, que o menu nao usa
const MENU_CHK_TILE = 1021;
const CHK = A.menuChecker(MENU_CHK_TILE);
w('menu_chk_tiles.bin', CHK.tiles); w('menu_chk_map.bin', CHK.map); w('chk_pal.bin', palBytes(A.PAL_MENU));

const scenes = {
  logo: [logoImg, logoPal, null],
  shop0_0: [A.shopScene(0, 0), A.shopPal(0), (tx, ty) => ty >= 13 && ty <= 15],
  shop0_1: [A.shopScene(0, 1), A.shopPal(0), (tx, ty) => ty >= 13 && ty <= 15],
  shop0_2: [A.shopScene(0, 2), A.shopPal(0), (tx, ty) => ty >= 13 && ty <= 15],
  shop1_0: [A.shopScene(1, 0), A.shopPal(1), (tx, ty) => ty >= 13 && ty <= 15],
  shop1_1: [A.shopScene(1, 1), A.shopPal(1), (tx, ty) => ty >= 13 && ty <= 15],
  shop1_2: [A.shopScene(1, 2), A.shopPal(1), (tx, ty) => ty >= 13 && ty <= 15],
  shop2_0: [A.shopScene(2, 0), A.shopPal(2), (tx, ty) => ty >= 13 && ty <= 15],
  shop2_1: [A.shopScene(2, 1), A.shopPal(2), (tx, ty) => ty >= 13 && ty <= 15],
  shop2_2: [A.shopScene(2, 2), A.shopPal(2), (tx, ty) => ty >= 13 && ty <= 15],
  shop3_0: [A.shopScene(3, 0), A.shopPal(3), (tx, ty) => ty >= 13 && ty <= 15],
  shop3_1: [A.shopScene(3, 1), A.shopPal(3), (tx, ty) => ty >= 13 && ty <= 15],
  shop3_2: [A.shopScene(3, 2), A.shopPal(3), (tx, ty) => ty >= 13 && ty <= 15],
  shop4_0: [A.shopScene(4, 0), A.shopPal(4), (tx, ty) => ty >= 13 && ty <= 15],
  shop4_1: [A.shopScene(4, 1), A.shopPal(4), (tx, ty) => ty >= 13 && ty <= 15],
  shop4_2: [A.shopScene(4, 2), A.shopPal(4), (tx, ty) => ty >= 13 && ty <= 15],
  title: [A.titleScene(), A.PAL_TITLE, null],
  menu: [A.menuScene(), A.PAL_MENU, null],
  map: [A.mapScene(), A.PAL_MAP, null],
};
for (const [name, [img, pal, prio]] of Object.entries(scenes)) {
  const bg = A.sceneToBG(img, 2, prio);
  if ((name === 'menu' || name === 'logo') && bg.count > MENU_CHK_TILE) throw new Error(name + ': tiles demais, invadem o xadrez do BG2');
  w(`${name}_tiles.bin`, bg.tiles); w(`${name}_map.bin`, bg.map); w(`${name}_pal.bin`, palBytes(pal));
  console.log(`cenario ${name}: ${bg.count} tiles`);
}

// balao do tutorial (BG2 no expediente): tiles 960+, paleta 3, prioridade alta
const TUT_TILE = 960;
{
  const { tilePixels, enc4 } = require('./gerador/gfx');
  const img = A.tutBalloon(), tiles = [], dict = new Map(), map = Buffer.alloc(2048);
  for (let ty = 0; ty < 28; ty++) for (let tx = 0; tx < 32; tx++) {
    const px = tilePixels(img, tx, ty);
    if (px.every((c) => !c)) continue;              // tile 0 do cenario e vazio
    const k = px.join(',');
    if (!dict.has(k)) { dict.set(k, tiles.length); tiles.push(enc4(px)); }
    map.writeUInt16LE((TUT_TILE + dict.get(k)) | (3 << 10) | 0x2000, (ty * 32 + tx) * 2);
  }
  if (TUT_TILE + tiles.length > MENU_CHK_TILE) throw new Error('balao do tutorial: tiles demais');
  w('tut_tiles.bin', Buffer.concat(tiles)); w('tut_map.bin', map); w('tut_pal.bin', palBytes(A.PAL_TUT));
  console.log(`balao do tutorial: ${tiles.length} tiles`);
}

// ------------------------------------------------------------ sprites
// sabores e icones como emojis (gerador/emoji_sprites.py; Python so quando mudam)
fs.writeFileSync(path.join(GEN, 'spal.json'), JSON.stringify(A.SPAL));
try {
  execFileSync(PY, [path.join('gerador', 'emoji_sprites.py')], { cwd: ROOT, stdio: 'inherit' });
} catch (e) {
  if (!fs.existsSync(path.join(GEN, 'emoji_spr.json'))) throw e;
  console.warn('Python indisponivel: reutilizando os emojis ja gerados em gen/.');
}
const emojis = {};
for (const [nome, idx] of Object.entries(JSON.parse(fs.readFileSync(path.join(GEN, 'emoji_spr.json'), 'utf8')))) {
  const im = new Img(16, 16); im.p.set(idx); emojis[nome] = im;
}
const S = A.buildSprites(emojis);
w('spr_tiles.bin', S.tiles);
w('port_tiles.bin', S.portTiles);
w('spr_pal.bin', Buffer.concat(S.pals.map(palBytes)));
w('port_pal.bin', Buffer.concat(S.portPals.map(palBytes)));

// ------------------------------------------------------------ fonte e paletas de texto
w('font.bin', F.fontTiles());
// ------------------------------------------------------------ interface (HDMA) e icones dos menus
const UI = require('./gerador/ui_tabs');
w('ui_panel.bin', UI.panelGrad());
w('ui_hud.bin', UI.hudGloss());
w('ui_band8.bin', UI.band(8));
w('ui_band16.bin', UI.band(16));
w('ui_open.bin', UI.openTabs());
try {
  execFileSync(PY, [path.join('gerador', 'icones.py')], { cwd: ROOT, stdio: 'inherit' });
} catch (e) {
  if (!fs.existsSync(path.join(GEN, 'icon_tiles.bin'))) { console.error('icones: precisa de Python/Pillow'); process.exit(1); }
}
// cor 1 = corpo, cor 2 = contorno/sombra, cor 3 = brilho do topo da letra
// 0-3: sobre faixas escuras (HUD); 4-7: sobre o painel creme (sombra caramelo suave)
const TEXTPAL = [
  ['#000000', '#C8D4F0', '#100C20', '#FFFFFF'],
  ['#000000', '#F0A010', '#100C20', '#F8F070'],
  ['#000000', '#38B040', '#100C20', '#A8F8A0'],
  ['#000000', '#E03828', '#100C20', '#F8A890'],
  ['#000000', '#3A2418', '#E0C498', '#7A5034'],
  ['#000000', '#B82010', '#E0C498', '#E85A30'],
  ['#000000', '#1C6C24', '#E0C498', '#4CAC50'],
  ['#000000', '#1C3C98', '#E0C498', '#5080E0'],
];
w('text_pal.bin', Buffer.concat(TEXTPAL.map((p) => palBytes(p).slice(0, 8))));

// ------------------------------------------------------------ audio
// vozes gravadas (gerador/sons.js): fixas na memoria do SPC700, o resto em stream da ROM
const SO = require('./gerador/sons').sons(AU.ARAM.FIXAS_FIM - AU.ARAM.FIXAS);
const FPS = 60.0988;                                     // quadros por segundo (NTSC)
const pitch = (taxa) => Math.round(taxa * 4096 / 32000);
const flagFim = (brr, f) => { const b = Buffer.from(brr); b[b.length - 9] |= f; return b; };
// memoria do SPC700: chiado (loop) e vozes fixas a partir de $0400
const extras = [{ inicio: AU.ARAM.MUSICA, loop: AU.ARAM.MUSICA }];   // SRCN 3
const fixasBin = [];
let aram = AU.ARAM.FIXAS;
for (const [brr, flag] of [[SO.fritura, 3], ...SO.fixas.map((v) => [v.brr, 1])]) {
  extras.push({ inicio: aram, loop: aram });
  // extras[i] e o SRCN 3+i: depois do chiado (SRCN 4) vem o anel das falas (SRCN 5)
  if (3 + extras.length === AU.SRCN.FALA) extras.push({ inicio: AU.ARAM.FALA, loop: AU.ARAM.FALA });
  fixasBin.push(flagFim(brr, flag));
  aram += brr.length;
}
if (aram > AU.ARAM.FIXAS_FIM) throw new Error('vozes fixas passam da memoria do SPC700');
let fixas = Buffer.concat(fixasBin);
fixas = Buffer.concat([fixas, Buffer.alloc((3 - fixas.length % 3) % 3)]);
console.log(`vozes fixas: ${SO.fixas.length} + chiado a ${SO.taxaFixas} Hz, ${fixas.length} bytes ($${AU.ARAM.FIXAS.toString(16)}-$${aram.toString(16)})`);
if (extras[AU.SRCN.MUSICA - 3].inicio !== AU.ARAM.MUSICA || extras[AU.SRCN.FALA - 3].inicio !== AU.ARAM.FALA ||
    extras.length !== AU.SRCN.FIXA0 - 3 + SO.fixas.length) throw new Error('diretorio de samples fora de ordem');
const spc = AU.spcBlob(extras);
w('spc.bin', spc);
const music = AU.musicData();
// ROM: vozes fixas (carga no boot) + streams, em sequencia a partir do banco SONS_BANCO
const SONS_BANCO = 13, partes = [fixas];
let ofs = fixas.length;
const streams = SO.streams.map((v) => { const o = ofs; partes.push(v.brr); ofs += v.brr.length; return { ...v, ofs: o }; });
const sonsBin = Buffer.concat(partes);
w('sons.bin', sonsBin);
const romEnd = (o) => '$' + ((SONS_BANCO + (o >> 15)) * 0x10000 + 0x8000 + (o & 0x7FFF)).toString(16).toUpperCase().padStart(6, '0');
const sonsInc = ['; gerado por build.js - vozes e musica gravadas (BRR), um pedaco por banco'];
for (let o = 0, b = SONS_BANCO; o < sonsBin.length; o += 0x8000, b++) {
  if (b > 31) throw new Error('sons passam do fim da ROM (1 MB)');
  sonsInc.push(`.segment "BANK${b}"`, `  .incbin "gen/sons.bin", ${o}, ${Math.min(0x8000, sonsBin.length - o)}`);
}
w('sons.inc', sonsInc.join('\n') + '\n');
console.log(`sons na ROM: ${sonsBin.length} bytes (bancos ${SONS_BANCO}-${SONS_BANCO + ((sonsBin.length - 1) >> 15)})`);

// ------------------------------------------------------------ includes
const inc = [];
inc.push('; gerado por build.js - nao editar');
for (const [k, v] of Object.entries(S.ids)) inc.push(`SPR_${k} = ${hex4(v)}`);
inc.push(`FONT_0 = ${hex2(F.CODE['0'])}`);
inc.push(`FONT_SPACE = ${hex2(F.CODE[' '])}`);
inc.push(`FONT_BOX = ${hex2(F.FONT_BOX)}`);
inc.push(`FONT_ARROW = ${hex2(F.CODE['▶'])}`);
inc.push(`FONT_COLON = ${hex2(F.CODE[':'])}`);
inc.push(`FONT_BTN0 = ${hex2(F.FONT_BTN0)}`, `N_BTN = ${F.BOTOES.length}`);
inc.push(`SPC_SIZE = ${spc.length}`);
{
  const V = [...SO.fixas, ...streams];
  V.forEach((v, i) => inc.push(`VOZ_${v.id} = ${i}`));
  inc.push(`VOZ_N = ${V.length}`, `MUSICA_ARAM = ${hex4(AU.ARAM.MUSICA)}`, `MUSICA_LEN = ${AU.ARAM.MUSICA_LEN}`,
    `FALA_ARAM = ${hex4(AU.ARAM.FALA)}`, `FALA_LEN = ${AU.ARAM.FALA_LEN}`, `SRCN_MUSICA = ${AU.SRCN.MUSICA}`, `SRCN_FALA = ${AU.SRCN.FALA}`, `SRCN_FRITURA = ${AU.SRCN.FRITURA}`, `FRITURA_PITCH = ${hex4(pitch(SO.taxaFixas))}`,
    `FIXAS_ARAM = ${hex4(AU.ARAM.FIXAS)}`, `FIXAS_LEN = ${fixas.length}`, `FIXAS_ROM = ${romEnd(0)}`);
  const tab = ['; gerado por build.js - tabelas das vozes (gerador/sons.js)'];
  const col = (nome, dir, fn) => tab.push(`${nome}: ${dir} ` + V.map(fn).join(', '));
  col('VozTipo', '.byte', (v) => (v.tipo === 'fixa' ? 0 : v.tipo === 'musica' ? 2 : 1));
  col('VozPri', '.byte', (v) => v.pri);
  col('VozEspera', '.word', (v) => Math.round(v.espera * FPS));
  col('VozSrcn', '.byte', (v, i) => (v.tipo === 'fixa' ? AU.SRCN.FIXA0 + i : v.tipo === 'musica' ? AU.SRCN.MUSICA : AU.SRCN.FALA));
  col('VozPitch', '.word', (v) => hex4(pitch(v.taxa)));
  col('VozQuadros', '.word', (v) => Math.ceil((v.brr.length / 9) * 16 / v.taxa * FPS) + 2);
  col('VozRom', '.faraddr', (v) => (v.tipo === 'fixa' ? '0' : romEnd(v.ofs)));
  col('VozLen', '.faraddr', (v) => (v.tipo === 'fixa' ? 0 : v.brr.length));
  col('VozBpq', '.word', (v) => Math.round(v.taxa * 9 / 16 / FPS * 256));          // bytes por quadro (8.8)
  col('VozFolga', '.word', (v) => Math.round(v.taxa * 9 / 16 * (v.tipo === 'musica' ? 0.5 : 0.15) / 3) * 3); // folga no anel
  // cartas que falam (CARD_* -> VOZ_* ou $FF)
  const CV = { BOSS_0: 'DESAFIO', BOSS_1: 'DESAFIO', BOSS_2: 'DESAFIO', BOSS_3: 'DESAFIO', DUELO: 'DESAFIO',
    VITORIA: 'VITORIA', DUELO_OK: 'VITORIA', DERROTA: 'DERROTA', DUELO_NO: 'DERROTA', FIM: 'IMPERIO' };
  tab.push('CartaVoz: .byte ' + Object.keys(CARDS).map((k) => (/^TROF_/.test(k) ? 'VOZ_TROFEU' : CV[k] ? 'VOZ_' + CV[k] : '$FF')).join(', '));
  w('voz.inc', tab.join('\n') + '\n');
}
inc.push(`MENU_CHK_VRAM = ${hex4(MENU_CHK_TILE * 16)}`);
inc.push(`TUT_VRAM = ${hex4(TUT_TILE * 16)}`);
inc.push(`SP_VER_COL = ${(32 - [...VERSAO_TXT].length) >> 1}`);
{ const b = A.TUT_BOX; inc.push(`TUT_X0 = ${b.x}`, `TUT_X1 = ${b.x + b.w - 1}`, `TUT_Y0 = ${b.y}`, `TUT_H = ${b.h}`); }
inc.push(`UI_N_OPEN = ${UI.N_OPEN}`, `UI_TAB_LEN = ${UI.TAB_LEN}`);
Object.keys(CARDS).forEach((k, i) => inc.push(`CARD_${k} = ${i}`));
music.songs.forEach((s, i) => inc.push(`SONG_${s.name.toUpperCase()} = ${i}`));
music.sfx.forEach((s, i) => inc.push(`SFX_${s.name.toUpperCase()} = ${i}`));
w('assets.inc', inc.join('\n') + '\n');

// layout dos textos em caixa: largura (caracteres) e altura (linhas) que cabem
// cartas: corpo na coluna 3, linhas 8..24 (rodape na 26); tutorial: coluna 4, linhas 11..16
const tam = (l) => [...l.replace(/\{[A-Z]+\}/g, '@')].length;
function cabe(nome, txt, maxCol, maxLin) {
  const ls = txt.split('\n');
  ls.forEach((l, i) => { if (tam(l) > maxCol) throw new Error(`${nome}: linha ${i + 1} com ${tam(l)} caracteres (max ${maxCol}), passa da caixa: "${l}"`); });
  if (ls.length > maxLin) throw new Error(`${nome}: ${ls.length} linhas (max ${maxLin}), passa da caixa`);
}
for (const [k, [, , b]] of Object.entries(CARDS)) cabe('carta ' + k, b, 26, 17);
for (const [k, v] of Object.entries(T)) if (/^TB_B/.test(k)) cabe(k, v, 25, 6);

const data = [];
data.push('; gerado por build.js - nao editar');
for (const [k, v] of Object.entries(T)) data.push(`TXT_${k}:\n${byteLines(F.compile(v))}`);
const cardEntries = Object.entries(CARDS);
const cards = ['; gerado por build.js - textos das cartas (banco proprio)'];
cardEntries.forEach(([k, [p, t, b]]) => {
  cards.push(`CTXT_${k}_T:\n${byteLines(F.compile(t))}`);
  cards.push(`CTXT_${k}_B:\n${byteLines(F.compile(b))}`);
});
cards.push('CardTable:');
cardEntries.forEach(([k, [p]]) => cards.push(`  .byte ${hex2(p & 255)}\n  .word .loword(CTXT_${k}_T), .loword(CTXT_${k}_B)`));
w('cards.inc', cards.join('\n') + '\n');
data.push('MissionTxt:\n' + Array.from({ length: 15 }, (_, i) => `  .word TXT_MIS_${i}`).join('\n'));
data.push('ShopName:\n' + Array.from({ length: 20 }, (_, i) => `  .word TXT_S_${i}`).join('\n'));
data.push('ShopDesc:\n' + Array.from({ length: 20 }, (_, i) => `  .word TXT_SD_${i}`).join('\n'));
data.push('TrophyTxt:\n' + Array.from({ length: 16 }, (_, i) => `  .word TXT_TROF_${i}`).join('\n'));
// musica
music.songs.forEach((s) => s.tracks.forEach((t, c) => data.push(`MUS_${s.name}_${c}:\n${byteLines(t)}`)));
data.push('SongTable:');
music.songs.forEach((s) => data.push(`  .word ${s.tracks.map((_, c) => `MUS_${s.name}_${c}`).join(', ')}`));
music.sfx.forEach((s) => data.push(`SFXD_${s.name}:\n${byteLines(s.data)}`));
data.push('SfxTable:');
music.sfx.forEach((s) => data.push(`  .word SFXD_${s.name}`));
data.push('PitchTable:\n' + AU.pitchTable().map((p) => `  .word ${hex4(p)}`).join('\n'));
data.push('MgGlyph:\n  .byte ' +['↑', '↓', '←', '→', 'A', 'B', 'X', 'Y'].map((c) => hex2(F.CODE[c])).join(','));
data.push('BtnSprTile: .word ' + F.BOTOES.map((b) => `SPR_BTN8_${b}`).join(', '));
data.push('UiPulse: .byte ' + UI.PULSO.join(','));
data.push('UiBob: .byte ' + UI.BALANCO.map((v) => v & 255).join(','));
data.push('UiOpenOfs: .word ' + Array.from({ length: UI.N_OPEN }, (_, i) => i * UI.TAB_LEN).join(','));
data.push('InstTable:');
AU.INSTR.forEach((i) => data.push(`  .byte ${i.map(hex2).join(',')}`));
w('data.inc', data.join('\n') + '\n');

// ------------------------------------------------------------ montagem
// verificador de largura: desvio com largura errada e erro de verdade; sem Python so
// avisa (no CI, onde a variavel CI existe, tambem falha)
try {
  execFileSync(PY, [path.join('gerador', 'checa_largura.py'), 'src/main.s', 'src/audio.s', 'src/game.s', 'src/telas.s', 'src/extra.s', 'src/segredo.s', 'src/ui.s'], { cwd: ROOT, stdio: 'inherit' });
} catch (e) {
  if (e.status === 1 || process.env.CI) { console.error('FALHA NO VERIFICADOR DE LARGURA'); process.exit(1); }
  console.warn('verificador de largura nao rodou (precisa de Python)');
}
// cc65: tools/cc65/bin se existir; senao, ca65/ld65 do PATH (ex.: apt install cc65)
const CC_LOCAL = path.join(ROOT, 'tools', 'cc65', 'bin');
const cc = (n) => (fs.existsSync(path.join(CC_LOCAL, n)) || fs.existsSync(path.join(CC_LOCAL, n + '.exe')) ? path.join(CC_LOCAL, n) : n);
const out = path.join(ROOT, 'LosPastelles.sfc');
try {
  execFileSync(cc('ca65'), ['--cpu', '65816', '-g', '-I', '.', '-o', 'gen/main.o', '-l', 'gen/main.lst', 'src/main.s'], { cwd: ROOT, stdio: 'inherit' });
  execFileSync(cc('ld65'), ['-C', 'src/snes.cfg', '-o', out, '-m', 'gen/map.txt', '-Ln', 'gen/labels.txt', 'gen/main.o'], { cwd: ROOT, stdio: 'inherit' });
} catch (e) { console.error('FALHA NA MONTAGEM'); process.exit(1); }

// checksum
const rom = fs.readFileSync(out);
rom.writeUInt16LE(0xFFFF, 0x7FDC); rom.writeUInt16LE(0x0000, 0x7FDE);
let sum = 0; for (const b of rom) sum = (sum + b) & 0xFFFF;
rom.writeUInt16LE(sum ^ 0xFFFF, 0x7FDC); rom.writeUInt16LE(sum, 0x7FDE);
fs.writeFileSync(out, rom);
console.log(`ROM gerada: ${out} (${rom.length} bytes, checksum ${hex4(sum)}, versao ${VERSAO})`);
