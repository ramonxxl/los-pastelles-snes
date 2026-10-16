// Layout do HUD do expediente: gerador/arte.js desenha os baloes no cenario (BG1)
// e build.js gera as constantes HUD_* usadas pelo jogo (src/banco28.s, game.s).
// Topo: uma pilula creme por valor, com o emoji (sprite 16x16) na ponta esquerda.
// Rodape: um painel creme com duas linhas de texto (missao/avisos e estoque/reputacao/meta).
'use strict';

// [coluna do texto, largura em casas] na linha HUD_LIN_TOPO
const TOPO = { DIA: [4, 3], RS: [10, 7], NV: [20, 2], HORA: [25, 5] };
const LIN_TOPO = 1;
const PILULA = { y: 4, h: 16 };                         // a pilula envolve a linha 1 (y 8..15)
// x da pilula: 2 px antes do icone (que fica 18 px antes do texto) ate 2 px depois do texto
const pilulaX = ([col, w]) => [col * 8 - 20, (col + w) * 8 + 2];
const icoX = ([col]) => col * 8 - 18;

// painel do rodape: linhas 25 (missao, avisos) e 26 (numeros), com 2 px de folga
const PAINEL = { x: 4, y: 196, w: 248, h: 24 };
const LIN_MSG = 25, LIN_NUM = 26;
// [coluna do texto, largura]; o icone 8x8 fica na coluna anterior
const BAIXO = { EST: [3, 3], REP: [9, 3], META: [16, 5] };

module.exports = { TOPO, LIN_TOPO, PILULA, pilulaX, icoX, PAINEL, LIN_MSG, LIN_NUM, BAIXO };
