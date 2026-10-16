// Build da ROM "Los Pastelles: O Imperio do Pastel" (SNES, LoROM SlowROM 2 MB)
// Uso: node build.js
'use strict';
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const A = require('./gerador/arte');
const F = require('./gerador/fonte');
const AU = require('./gerador/audio');
const { T, CARDS } = require('./gerador/textos');
const { NV } = require('./gerador/niveis');
const AJ = require('./gerador/ajuda');
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

// elementos do cenario da loja feitos de emoji (gerador/emoji_cenario.py; Python so quando mudam)
fs.writeFileSync(path.join(GEN, 'shoppal.json'), JSON.stringify([0, 1, 2, 3, 4].map(A.shopPal)));
try {
  execFileSync(PY, [path.join('gerador', 'emoji_cenario.py')], { cwd: ROOT, stdio: 'inherit' });
} catch (e) {
  if (!fs.existsSync(path.join(GEN, 'emoji_cen.json'))) throw e;
  console.warn('Python indisponivel: reutilizando os elementos do cenario ja gerados em gen/.');
}

// prioridade alta no BG1 da loja: balcao (linhas 13-15, clientes atras) e o painel
// da HUD embaixo (linhas 25+: fundador e mascote, com prioridade 2, ficam atras)
const PRIO_LOJA = (tx, ty) => (ty >= 13 && ty <= 15) || ty >= 25;
const scenes = {
  logo: [logoImg, logoPal, null],
  shop0_0: [A.shopScene(0, 0), A.shopPal(0), PRIO_LOJA],
  shop0_1: [A.shopScene(0, 1), A.shopPal(0), PRIO_LOJA],
  shop0_2: [A.shopScene(0, 2), A.shopPal(0), PRIO_LOJA],
  shop1_0: [A.shopScene(1, 0), A.shopPal(1), PRIO_LOJA],
  shop1_1: [A.shopScene(1, 1), A.shopPal(1), PRIO_LOJA],
  shop1_2: [A.shopScene(1, 2), A.shopPal(1), PRIO_LOJA],
  shop2_0: [A.shopScene(2, 0), A.shopPal(2), PRIO_LOJA],
  shop2_1: [A.shopScene(2, 1), A.shopPal(2), PRIO_LOJA],
  shop2_2: [A.shopScene(2, 2), A.shopPal(2), PRIO_LOJA],
  shop3_0: [A.shopScene(3, 0), A.shopPal(3), PRIO_LOJA],
  shop3_1: [A.shopScene(3, 1), A.shopPal(3), PRIO_LOJA],
  shop3_2: [A.shopScene(3, 2), A.shopPal(3), PRIO_LOJA],
  shop4_0: [A.shopScene(4, 0), A.shopPal(4), PRIO_LOJA],
  shop4_1: [A.shopScene(4, 1), A.shopPal(4), PRIO_LOJA],
  shop4_2: [A.shopScene(4, 2), A.shopPal(4), PRIO_LOJA],
  title: [A.titleScene(), A.PAL_TITLE, null],
  menu: [A.menuScene(), A.PAL_MENU, null],
};
let maxLoja = 0;                   // tiles do maior cenario do expediente (BG1)
for (const [name, [img, pal, prio]] of Object.entries(scenes)) {
  const bg = A.sceneToBG(img, 2, prio);
  if ((name === 'menu' || name === 'logo') && bg.count > MENU_CHK_TILE) throw new Error(name + ': tiles demais, invadem o xadrez do BG2');
  w(`${name}_tiles.bin`, bg.tiles); w(`${name}_map.bin`, bg.map); w(`${name}_pal.bin`, palBytes(pal));
  if (/^shop/.test(name)) maxLoja = Math.max(maxLoja, bg.count);
  console.log(`cenario ${name}: ${bg.count} tiles`);
}

// mapa da expansao (gerador/mapa.js): 6 paletas (BG 2..7) e remendos das unidades
// compradas (gen/map_obras.inc, lidos por MapObras). Emojis: gerador/emoji_mapa.py
try {
  execFileSync(PY, [path.join('gerador', 'emoji_mapa.py')], { cwd: ROOT, stdio: 'inherit' });
} catch (e) {
  if (!fs.existsSync(path.join(GEN, 'emoji_mapa.json'))) throw e;
  console.warn('Python indisponivel: reutilizando os emojis do mapa ja gerados em gen/.');
}
{
  const MAPA = require('./gerador/mapa').gerarMapa(JSON.parse(fs.readFileSync(path.join(GEN, 'emoji_mapa.json'), 'utf8')));
  w('map_tiles.bin', MAPA.tiles); w('map_map.bin', MAPA.map); w('map_pal.bin', Buffer.concat(MAPA.palHex.map(palBytes)));
  w('map_obras.inc', MAPA.obras);
  console.log(`mapa: ${MAPA.count} tiles`);
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

// ajuda da pausa (BG2 no expediente): balao grande + controle do Super Famicom (paleta 4).
// Dois mapas fixos na VRAM (A com o controle, B so o balao); a NMI troca o BG2SC.
// Mapas logo antes dos tiles do balao do tutorial, tiles da ajuda logo antes dos mapas.
const AJ_MAPA = 0x3400, AJ_MAPB = 0x3800;   // enderecos de palavra (multiplos de $400)
let AJ_TILE;
{
  const { tilePixels, enc4 } = require('./gerador/gfx');
  const bal = A.ajudaBalloon(), ctl = A.controleSFC(), P = A.CTRL_POS;
  const tiles = [], dict = new Map(), ea = [], eb = [];
  const ent = (px, pal) => {
    const k = pal + ':' + px.join(',');
    if (!dict.has(k)) { dict.set(k, tiles.length); tiles.push(enc4(px)); }
    return { t: dict.get(k), pal };
  };
  for (let ty = 0; ty < 28; ty++) for (let tx = 0; tx < 32; tx++) {
    const px = tilePixels(bal, tx, ty), i = ty * 32 + tx;
    eb[i] = px.every((c) => !c) ? null : ent(px, 3);
    ea[i] = eb[i];
    const cx = tx - P.x / 8, cy = ty - P.y / 8;
    if (cx >= 0 && cy >= 0 && cx < ctl.w / 8 && cy < ctl.h / 8) {
      const cp = tilePixels(ctl, cx, cy);
      if (!cp.every((c) => c === 15)) ea[i] = ent(cp, 4);
    }
  }
  AJ_TILE = AJ_MAPA / 16 - tiles.length;
  if (maxLoja > AJ_TILE) throw new Error(`cenario da loja com ${maxLoja} tiles invade os tiles da ajuda (${AJ_TILE}+)`);
  const mapa = (es) => { const m = Buffer.alloc(2048); es.forEach((e, i) => { if (e) m.writeUInt16LE((AJ_TILE + e.t) | (e.pal << 10) | 0x2000, i * 2); }); return m; };
  w('aj_tiles.bin', Buffer.concat(tiles)); w('aj_mapa.bin', mapa(ea)); w('aj_mapb.bin', mapa(eb)); w('aj_pal.bin', palBytes(A.PAL_CTRL));
  console.log(`ajuda: ${tiles.length} tiles (${AJ_TILE}+; maior cenario da loja: ${maxLoja})`);
}

// animacoes grandes do expediente (BG2, paleta 5): gerador/anim_<nome>.py faz os
// quadros (Python so quando mudam), gerador/anim.js os tiles. Tiles logo antes da ajuda.
const ANIMS = ['montagem', 'lixeira'];
let ANIM;
{
  for (const n of ANIMS) {
    try {
      execFileSync(PY, [path.join('gerador', `anim_${n}.py`)], { cwd: ROOT, stdio: 'inherit' });
    } catch (e) {
      if (!fs.existsSync(path.join(GEN, `anim_${n}.json`))) throw e;
      console.log(`anim_${n}.py falhou; usando gen/anim_${n}.json existente`);
    }
  }
  ANIM = require('./gerador/anim').gerarAnims(
    ANIMS.map((nome) => ({ nome, dados: JSON.parse(fs.readFileSync(path.join(GEN, `anim_${nome}.json`), 'utf8')) })), AJ_TILE);
  if (maxLoja > ANIM.base) throw new Error(`cenario da loja com ${maxLoja} tiles invade os tiles das animacoes (${ANIM.base}+)`);
  w('anim_borda.bin', ANIM.borda); w('anim_map.bin', ANIM.map); w('anim_pal.bin', palBytes([null, ...ANIM.pal]));
  for (const [k, v] of Object.entries(ANIM.bins)) w(k, v);
  w('anim.inc', ANIM.inc);
  console.log(`animacoes: ${ANIM.n} quadros, tiles ${ANIM.base}+`);
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
// ROM: todo o audio (vozes fixas, carregadas no boot, musica e falas) em sequencia nos
// bancos 32-63, a segunda metade da ROM de 2 MB (um stream pode atravessar de um banco
// para o seguinte). Os bancos 13-27 ficaram livres quando o audio foi para la.
const SONS_BANCO = 32, SONS_FIM = 63;
// segundos de folga nos aneis (o que atravessa quadros pesados e falas por cima da musica)
const FOLGA_S = { musica: 0.7, fala: 0.2 };
const partes = [fixas];
let ofs = fixas.length;
const streams = SO.streams.map((v) => { const o = ofs; partes.push(v.brr); ofs += v.brr.length; return { ...v, ofs: o }; });
const sonsBin = Buffer.concat(partes);
w('sons.bin', sonsBin);
const romEnd = (o) => '$' + ((SONS_BANCO + (o >> 15)) * 0x10000 + 0x8000 + (o & 0x7FFF)).toString(16).toUpperCase().padStart(6, '0');
const sonsInc = ['; gerado por build.js - vozes e musica gravadas (BRR), um pedaco por banco'];
for (let o = 0, b = SONS_BANCO; o < sonsBin.length; o += 0x8000, b++) {
  if (b > SONS_FIM) throw new Error(`sons passam do banco ${SONS_FIM} (fim da ROM de 2 MB)`);
  sonsInc.push(`.segment "BANK${b}"`, `  .incbin "gen/sons.bin", ${o}, ${Math.min(0x8000, sonsBin.length - o)}`);
}
w('sons.inc', sonsInc.join('\n') + '\n');
const livreSons = (SONS_FIM - SONS_BANCO + 1) * 0x8000 - sonsBin.length;
console.log(`sons na ROM: ${sonsBin.length} bytes (bancos ${SONS_BANCO}-${SONS_BANCO + ((sonsBin.length - 1) >> 15)}; livres ${livreSons})`);

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
    `FALA_ARAM = ${hex4(AU.ARAM.FALA)}`, `FALA_LEN = ${AU.ARAM.FALA_LEN}`, `ECO_ARAM = ${hex4(AU.ARAM.ECO)}`, `SRCN_MUSICA = ${AU.SRCN.MUSICA}`, `SRCN_FALA = ${AU.SRCN.FALA}`, `SRCN_FRITURA = ${AU.SRCN.FRITURA}`, `FRITURA_PITCH = ${hex4(pitch(SO.taxaFixas))}`,
    `FIXAS_ARAM = ${hex4(AU.ARAM.FIXAS)}`, `FIXAS_LEN = ${fixas.length}`, `FIXAS_ROM = ${romEnd(0)}`,
    // musica com menos que isso no anel (0,2 s) passa na frente das falas (Bomba)
    `MUS_CRITICO = ${Math.round(SO.streams.find((v) => v.tipo === 'musica').taxa * 9 / 16 * 0.2)}`);
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
  const folga = (v) => Math.round(v.taxa * 9 / 16 * FOLGA_S[v.tipo === 'musica' ? 'musica' : 'fala'] / 3) * 3;
  col('VozFolga', '.word', folga); // folga no anel
  // o ressincronismo (VozQuadro/MusQuadro) acha que a escrita ainda nao deu a volta
  // quando ela passa de 3/4 do anel: folga + um lote + um quadro tem de caber nisso
  for (const v of V) {
    if (v.tipo === 'fixa') continue;
    const anel = v.tipo === 'musica' ? AU.ARAM.MUSICA_LEN : AU.ARAM.FALA_LEN;
    const max = folga(v) + 72 + Math.ceil(v.taxa * 9 / 16 / FPS);
    if (max > anel * 3 / 4) throw new Error(`voz ${v.id}: folga ${folga(v)} + lote + quadro = ${max} passa de 3/4 do anel (${anel})`);
  }
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
{ const b = A.AJ_BOX; inc.push(`AJ_X0 = ${b.x}`, `AJ_X1 = ${b.x + b.w - 1}`, `AJ_Y0 = ${b.y}`, `AJ_H = ${b.h}`); }
// HUD do expediente (gerador/hud.js): colunas, larguras, linhas e x dos emojis
{
  const H = require('./gerador/hud');
  inc.push(`HUD_LIN_TOPO = ${H.LIN_TOPO}`, `HUD_LIN_MSG = ${H.LIN_MSG}`, `HUD_LIN_NUM = ${H.LIN_NUM}`, `HUD_ICO_Y = ${H.PILULA.y}`);
  for (const [k, v] of Object.entries(H.TOPO)) inc.push(`HUD_${k}_COL = ${v[0]}`, `HUD_${k}_W = ${v[1]}`, `HUD_${k}_ICOX = ${H.icoX(v)}`);
  for (const [k, v] of Object.entries(H.BAIXO)) inc.push(`HUD_${k}_COL = ${v[0]}`, `HUD_${k}_W = ${v[1]}`);
  // as pilulas nao podem se encostar nem sair da tela
  const xs = Object.values(H.TOPO).map(H.pilulaX).sort((a, b) => a[0] - b[0]);
  xs.forEach(([x0, x1], i) => { if (x0 < 0 || x1 > 255 || (i && x0 <= xs[i - 1][1] + 1)) throw new Error('HUD: pilulas do topo se sobrepoem ou saem da tela'); });
}
for (const [k, v] of Object.entries(ANIM.consts)) inc.push(`${k} = ${v}`);
inc.push(`AJ_VRAM = ${hex4(AJ_TILE * 16)}`, `AJ_MAPA_VRAM = ${hex4(AJ_MAPA)}`, `AJ_MAPB_VRAM = ${hex4(AJ_MAPB)}`,
  `AJ_SC_A = ${hex2(AJ_MAPA >> 8)}`, `AJ_SC_B = ${hex2(AJ_MAPB >> 8)}`);
// niveis (gerador/niveis.js): o codigo usa NV_*; cartas de desbloqueio agrupadas no mesmo nivel
for (const [k, v] of Object.entries(NV)) inc.push(`NV_${k} = ${v}`);
inc.push(`AJ_ABAS = ${AJ.abas(T, CARDS).length}`);
if (NV.ATENDENTE !== NV.REQUEIJAO || NV.TELEFONE !== NV.REQUEIJAO || NV.PC !== NV.LOJA)
  throw new Error('niveis.js: as cartas UN_ATEND/UN_TEL saem no nivel do requeijao e UN_PC no da nova loja (ResultsUpdate)');
inc.push(`UI_N_OPEN = ${UI.N_OPEN}`, `UI_TAB_LEN = ${UI.TAB_LEN}`);
Object.keys(CARDS).forEach((k, i) => inc.push(`CARD_${k} = ${i}`));
music.songs.forEach((s, i) => inc.push(`SONG_${s.name.toUpperCase()} = ${i}`));
music.sfx.forEach((s, i) => inc.push(`SFX_${s.name.toUpperCase()} = ${i}`));
// abertura "RAMON" (homenagem a Konami): arte_fonte/abertura/abertura.json, de gerador/abertura_ramon.py
{
  const AB = require('./gerador/abertura').gerarAbertura(JSON.parse(fs.readFileSync(path.join(ROOT, 'arte_fonte', 'abertura', 'abertura.json'), 'utf8')));
  w('abertura_tiles.bin', AB.tiles); w('abertura_bg1.bin', AB.bg1); w('abertura_bg2.bin', AB.bg2); w('abertura_pal.bin', AB.pal);
  w('abertura_obj.bin', AB.objTiles);
  w('abertura.inc', '; gerado por build.js - quadro em que entra cada paleta da abertura\nAbPalQ: .word ' + AB.quadros.join(', ') +
    '\n; sprites da perna do R: x, y, tile\nAbObj: ' + AB.oam.map((o) => '.byte ' + o.join(', ')).join('\n       ') + '\n');
  inc.push(`AB_NPAL = ${AB.quadros.length}`, `AB_NOBJ = ${AB.oam.length}`, `AB_FAISCA = ${hex4(AB.faisca)}`, `AB_FIM = ${AB.quadros[AB.quadros.length - 1] + 8}`);
  console.log(`abertura: ${AB.nLogo} tiles da logo, ${AB.oam.length} sprites na perna do R, ${AB.quadros.length} paletas, ${AB.quadros[AB.quadros.length - 1] + 8} quadros`);
}
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
// pausa (balao do tutorial): titulo e aviso na coluna 4, itens na 7 (depois do icone)
cabe('PAUSA', T.PAUSA, 25, 1);
for (const k of ['PA_CONT', 'PA_AJUDA', 'PA_SAIR', 'PA_AVISO']) cabe(k, T[k], 22, 1);
// missao ao lado do icone no fim do dia (DrawResults: coluna 5 ate 28)
for (const [k, v] of Object.entries(T)) if (/^MIS_/.test(k)) cabe(k, v, 24, 1);
// avisos do expediente: linha de avisos do painel do rodape, colunas 1..30
for (const [k, v] of Object.entries(T)) if (/^(M_|TUT_|DEMO$)/.test(k)) cabe(k, v, 30, 1);

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
// ajuda da pausa (gerador/ajuda.js): textos no banco das cartas
{
  const AB = AJ.abas(T, CARDS), aj = ['; gerado por build.js - ajuda da pausa (gerador/ajuda.js)'];
  const pags = [];
  AB.forEach((a, i) => {
    cabe('ajuda: aba ' + a.nome, a.nome, 22, 1);
    aj.push(`AJN_${i}:\n${byteLines(F.compile(a.nome))}`);
    a.paginas.forEach((p, j) => {
      cabe(`ajuda: ${a.nome} pagina ${j + 1}`, p.txt, AJ.LARG, AJ.LINHAS);
      const n = pags.length;
      pags.push(p);
      aj.push(`AJP_${n}:\n${byteLines(F.compile(p.txt))}`, `AJQ_${n}:\n${byteLines(F.compile(`${j + 1}/${a.paginas.length}`))}`);
    });
  });
  let ini = 0;
  aj.push('AjNome: .word ' + AB.map((_, i) => `.loword(AJN_${i})`).join(', '));
  aj.push('AjPagIni: .byte ' + [...AB.map((a) => { const r = ini; ini += a.paginas.length; return r; }), ini].join(', '));
  aj.push('AjPagTxt: .word ' + pags.map((_, n) => `.loword(AJP_${n})`).join(', '));
  aj.push('AjPagNum: .word ' + pags.map((_, n) => `.loword(AJQ_${n})`).join(', '));
  aj.push('AjPagDes: .byte ' + pags.map((p) => (p.desenho ? 1 : 0)).join(', '));
  w('ajuda.inc', aj.join('\n') + '\n');
}
// password (gerador/senha.js): tabela de campos e alfabeto, lidos no banco 28
{
  // tecla escolhida do teclado (16x16): tiles na ordem de cima (0, 1) e de baixo (16, 17)
  const { tilePixels, enc4 } = require('./gerador/gfx');
  const tec = A.teclaSenha();
  w('tecla_tiles.bin', Buffer.concat([[0, 0], [1, 0], [0, 1], [1, 1]].map(([x, y]) => enc4(tilePixels(tec, x, y)))));
  const SE = require('./gerador/senha');
  w('senha.inc', SE.inc(F.CODE));
  console.log(`password: ${SE.N_SIMB} simbolos (${SE.BITS_P} bits de jogo + ${SE.BITS_VER} de verificacao)`);
}
data.push('MissionTxt:\n' + Array.from({ length: 15 }, (_, i) => `  .word TXT_MIS_${i}`).join('\n'));
data.push('ShopName:\n' + Array.from({ length: 21 }, (_, i) => `  .word TXT_S_${i}`).join('\n'));
data.push('ShopDesc:\n' + Array.from({ length: 21 }, (_, i) => `  .word TXT_SD_${i}`).join('\n'));
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
