// Vozes e musica gravadas (pasta sounds/): MP3 -> PCM (ffmpeg) -> BRR (gerador/brr.js).
//  - fixas: carregadas na memoria do SPC700 no boot e tocadas sem custo (falas frequentes)
//  - stream: ficam na ROM e sao enviadas ao SPC700 enquanto tocam (falas raras e a musica)
// O BRR convertido fica em arte_fonte/brr/ (versionado), entao compilar nao exige ffmpeg:
// so quando um MP3 muda (ou a taxa) e que o ffmpeg e necessario para reconverter.
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto'), { execFileSync } = require('child_process');
const BRR = require('./brr');

const ROOT = path.join(__dirname, '..');
// sounds/ (os MP3) fica fora do git; o BRR convertido fica versionado em arte_fonte/brr/
const DIR = path.join(ROOT, 'sounds'), CACHE = path.join(ROOT, 'arte_fonte', 'brr');

// taxas (Hz). As fixas usam a maior taxa da lista que couber na memoria do SPC700.
const TAXA_STREAM = 10000, TAXA_MUSICA = 10000;
const TAXAS_FIXAS = [11025, 10000, 9600, 9000, 8000];

// prioridade: 1 = fala comum, 2 = importante (interrompe as comuns); espera = segundos
// sem repetir a mesma fala
const VOZES = [
  // fixas (expediente, tocam toda hora)
  { id: 'FECHOU',   arq: 'fechou',               tipo: 'fixa',   pri: 1, espera: 3 },
  { id: 'ABRIU',    arq: 'iih-abriu',            tipo: 'fixa',   pri: 1, espera: 3 },
  { id: 'CRU',      arq: 'tá-cru',               tipo: 'fixa',   pri: 1, espera: 3 },
  { id: 'QUEIMOU',  arq: 'queimou',              tipo: 'fixa',   pri: 1, espera: 3 },
  { id: 'OLHA',     arq: 'olha-o-pastel',        tipo: 'fixa',   pri: 1, espera: 4 },
  { id: 'ESSENAO',  arq: 'esse-não',             tipo: 'fixa',   pri: 1, espera: 3 },
  { id: 'REFRI',    arq: 'com-refri',            tipo: 'fixa',   pri: 1, espera: 3 },
  { id: 'TOP',      arq: 'top-demais',           tipo: 'fixa',   pri: 1, espera: 12 },
  // stream (raras: tocam junto com a musica sem faltar dado)
  { id: 'QUEBROU',  arq: 'quebrou-o-cesto',      tipo: 'stream', pri: 2, espera: 3 },
  { id: 'DESISTIU', arq: 'ih-desistiu',          tipo: 'stream', pri: 1, espera: 4 },
  { id: 'TELEFONE', arq: 'los-pastelles-qual-o-pedido(telefone)', tipo: 'stream', pri: 1, espera: 4 },
  { id: 'BOMDIA',   arq: 'bom-dia-freguesia',    tipo: 'stream', pri: 2, espera: 0 },
  { id: 'PORHOJE',  arq: 'por-hoje-é-só',        tipo: 'stream', pri: 2, espera: 0 },
  { id: 'MISSAO',   arq: 'missao-cumprida',      tipo: 'stream', pri: 2, espera: 0 },
  { id: 'TROFEU',   arq: 'troféu',               tipo: 'stream', pri: 2, espera: 0 },
  { id: 'DESAFIO',  arq: 'desafio',              tipo: 'stream', pri: 2, espera: 0 },
  { id: 'VITORIA',  arq: 'vitória',              tipo: 'stream', pri: 2, espera: 0 },
  { id: 'DERROTA',  arq: 'ah-não-foi-dessa-vez', tipo: 'stream', pri: 2, espera: 0 },
  { id: 'IMPERIO',  arq: 'parabéns-o-império-é-seu', tipo: 'stream', pri: 2, espera: 0 },
  { id: 'TITULO',   arq: 'los-pasteles-o-imperio-do-pastel', tipo: 'stream', pri: 2, espera: 0 },
  { id: 'TEMA',     arq: 'pastelito-theme-song-1min', tipo: 'musica', pri: 2, espera: 0 },
];
// chiado da fritura: trecho em loop (voz 6), na mesma taxa das fixas
const FRITURA = { arq: 'shhhh(barulho-da-fritura)', inicio: 0.6, dur: 0.5, cruz: 0.12 };

const CORTE = 'silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.03,areverse,' +
  'silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.06,areverse';

function hashArq(p) { return crypto.createHash('sha1').update(fs.readFileSync(p)).digest('hex'); }
function temFfmpeg() { try { execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' }); return true; } catch (e) { return false; } }

// MP3 -> Int16Array mono na taxa pedida (sem silencio nas pontas; musica sem corte)
function pcm(arq, taxa, cortar) {
  const args = ['-v', 'error', '-i', path.join(DIR, arq + '.mp3')];
  if (cortar) args.push('-af', CORTE);
  args.push('-ac', '1', '-ar', String(taxa), '-f', 's16le', '-');
  const raw = execFileSync('ffmpeg', args, { maxBuffer: 1 << 28 });
  return new Int16Array(raw.buffer, raw.byteOffset, raw.length >> 1);
}
// volume com folga (pico em ~67%, -3,5 dB): o BRR passa um pouco do original nos
// picos e a voz ainda soma com a musica na mixagem do DSP
const PICO = 22000;
function normaliza(x) {
  let pk = 1; for (const v of x) pk = Math.max(pk, Math.abs(v));
  const g = PICO / pk;
  return Int16Array.from(x, (v) => Math.round(v * g));
}
// trecho em loop com emenda cruzada, com tamanho multiplo de 16 amostras
function loopFritura(x, taxa) {
  const n = Math.round(FRITURA.dur * taxa / 16) * 16, c = Math.round(FRITURA.cruz * taxa), i0 = Math.round(FRITURA.inicio * taxa);
  const out = new Int16Array(n);
  for (let i = 0; i < n; i++) {
    let v = x[i0 + i] || 0;
    if (i < c) { const t = i / c; v = v * t + (x[i0 + n + i] || 0) * (1 - t); }
    out[i] = Math.round(v);
  }
  return out;
}

// cache: sounds/brr/<nome>.brr + indice.json { nome: { sha1, taxa, amostras } }
function carregaIndice() { try { return JSON.parse(fs.readFileSync(path.join(CACHE, 'indice.json'), 'utf8')); } catch (e) { return {}; } }
function converte(nome, arq, taxa, gera) {
  const idx = carregaIndice(), mp3 = path.join(DIR, arq + '.mp3'), alvo = path.join(CACHE, nome + '.brr');
  const h = fs.existsSync(mp3) ? hashArq(mp3) : null;
  const e = idx[nome];
  if (e && fs.existsSync(alvo) && e.taxa === taxa && e.versao === BRR.VERSAO && (!h || e.sha1 === h)) return fs.readFileSync(alvo);
  if (!h) throw new Error(`som ${nome}: falta ${mp3} e nao ha BRR em cache`);
  if (!temFfmpeg()) throw new Error(`som ${nome}: o MP3 mudou e precisa do ffmpeg para reconverter`);
  const brr = BRR.encode(gera());
  fs.mkdirSync(CACHE, { recursive: true });
  fs.writeFileSync(alvo, brr);
  idx[nome] = { arq, sha1: h, taxa, versao: BRR.VERSAO, amostras: (brr.length / 9) * 16 };
  fs.writeFileSync(path.join(CACHE, 'indice.json'), JSON.stringify(idx, null, 1) + '\n');
  console.log(`som convertido: ${nome} (${taxa} Hz, ${brr.length} bytes)`);
  return brr;
}

// taxa das fixas: a maior da lista em que fixas + fritura cabem em 'espaco' bytes
function taxaFixas(espaco) {
  const idx = carregaIndice();
  const dur = (v) => {
    const e = idx[v.id];
    if (e) return e.amostras / e.taxa;
    return pcm(v.arq, 8000, true).length / 8000; // sem cache: mede com o ffmpeg
  };
  const total = VOZES.filter((v) => v.tipo === 'fixa').reduce((s, v) => s + dur(v), 0) + FRITURA.dur;
  for (const t of TAXAS_FIXAS) if (Math.ceil(total * t / 16 + VOZES.length) * 9 <= espaco) return t;
  throw new Error(`vozes fixas (${total.toFixed(1)} s) nao cabem em ${espaco} bytes`);
}

// gera tudo: { fixas: [{id, brr}], fritura: brr, streams: [{id, brr, loop}], taxas }
function sons(espacoFixas) {
  const tf = taxaFixas(espacoFixas);
  const r = { taxaFixas: tf, fixas: [], streams: [] };
  for (const v of VOZES) {
    const taxa = v.tipo === 'fixa' ? tf : v.tipo === 'musica' ? TAXA_MUSICA : TAXA_STREAM;
    const brr = converte(v.id, v.arq, taxa, () => normaliza(pcm(v.arq, taxa, v.tipo !== 'musica')));
    const item = { ...v, taxa, brr };
    (v.tipo === 'fixa' ? r.fixas : r.streams).push(item);
  }
  r.fritura = converte('FRITURA', FRITURA.arq, tf, () => loopFritura(normaliza(pcm(FRITURA.arq, tf, false)), tf));
  return r;
}

module.exports = { sons, VOZES };
