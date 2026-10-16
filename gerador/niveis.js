// Niveis em que cada coisa libera: fonte unica. build.js gera as constantes NV_*
// (gen/assets.inc) que o codigo usa e a aba NIVEIS da ajuda; textos.js usa nas cartas.
'use strict';

const NV = {
  // sabores (o jogo comeca com carne, queijo e frango)
  CALABRESA: 3, REQUEIJAO: 6, BACON: 9,
  // clientes e pedidos
  TURISTA: 3, DUPLO: 4, MISTERIO: 4, REFRI: 7, TELEFONE: 6,
  // botoes no minijogo de fechar o pastel (2 no comeco)
  MG3: 6, MG4: 13,
  // itens da loja
  FREEZER: 4, MUSICA: 5, ATENDENTE: 6, MOTOBOY: 6, AR: 7, REFORMA1: 8,
  PUBLI: 10, UNIFORME: 10, LOJA: 13, PC: 13, REFORMA2: 14, FRANQUIA: 21,
  // desafios: o nivel para nesses valores ate vencer o desafio (LevelCap)
  DESAFIO0: 5, DESAFIO1: 12, DESAFIO2: 20, DESAFIO3: 30,
};

// o que aparece na aba NIVEIS: [nivel, texto]; T = textos do jogo, CARDS = cartas
function lista(T, CARDS) {
  const d = (n) => { const t = CARDS['BOSS_' + n][1]; return /^DESAFIO/.test(t) ? t : 'DESAFIO: ' + t; };
  return [
    [NV.CALABRESA, 'PASTEL DE CALABRESA'], [NV.TURISTA, 'CLIENTE TURISTA'],
    [NV.FREEZER, T.S_10], [NV.DUPLO, 'PEDIDO DUPLO'], [NV.MISTERIO, 'CLIENTE MISTERIOSO'],
    [NV.MUSICA, T.S_12], [NV.DESAFIO0, d(0)],
    [NV.REQUEIJAO, 'PASTEL DE REQUEIJÃO'], [NV.ATENDENTE, T.S_4], [NV.MOTOBOY, T.S_9],
    [NV.TELEFONE, 'ENTREGAS (TELEFONE)'], [NV.MG3, '3 BOTÕES NO MINIJOGO'],
    [NV.REFRI, 'REFRI E COMBO'], [NV.AR, T.S_11],
    [NV.REFORMA1, 'REFORMA (ETAPA 1)'],
    [NV.BACON, 'PASTEL DE BACON'],
    [NV.PUBLI, T.S_5], [NV.UNIFORME, T.S_13],
    [NV.DESAFIO1, d(1)],
    [NV.LOJA, T.S_6], [NV.PC, T.S_8], [NV.MG4, '4 BOTÕES NO MINIJOGO'],
    [NV.REFORMA2, 'REFORMA (ETAPA 2)'],
    [NV.DESAFIO2, d(2)],
    [NV.FRANQUIA, T.S_7 + ' (REPUTAÇÃO 70 E 3 DESAFIOS)'],
    [NV.DESAFIO3, d(3)],
  ].sort((a, b) => a[0] - b[0]);
}

module.exports = { NV, lista };
