// Ajuda do menu de pausa: abas e paginas (texto maiusculo, \n = nova linha).
// Cada pagina vai da linha AJ_LIN0 (13 linhas, 26 letras, coluna 3); build.js confere.
// desenho: true = a pagina mostra o controle do Super Famicom (BG2) nas primeiras linhas.
'use strict';
const { NV, lista } = require('./niveis');

const LARG = 26, LINHAS = 13;
const tam = (l) => [...l.replace(/\{[A-Z]+\}/g, '@')].length;
// duas colunas de 13 letras (legenda do controle)
const duas = (a, b) => a + ' '.repeat(Math.max(1, 13 - tam(a))) + b;

// "NV xx texto": itens do mesmo nivel alinhados depois do numero; continuacao +2
function niveisPaginas(T, CARDS) {
  const itens = [];
  let ult = -1;
  for (const [nv, txt] of lista(T, CARDS)) {
    const ls = [nv === ult ? '      ' : `NV ${String(nv).padStart(2)} `];
    ult = nv;
    let novo = true;
    for (const p of txt.split(' ')) {
      const i = ls.length - 1, add = (novo ? '' : ' ') + p;
      if (tam(ls[i]) + tam(add) > LARG) ls.push('        ' + p);
      else ls[i] += add;
      novo = false;
    }
    if (nv === ult && itens.length && ls[0].startsWith(' ')) itens[itens.length - 1].push(...ls);
    else itens.push(ls);
  }
  // pagina 1 abre com a explicacao dos desafios; um item nunca fica dividido
  const pags = [[`NOS NÍVEIS ${NV.DESAFIO0}, ${NV.DESAFIO1}, ${NV.DESAFIO2} E ${NV.DESAFIO3}`,
    'VEM UM DESAFIO: VENÇA PARA', 'CONTINUAR SUBINDO.', '']];
  for (const ls of itens) {
    const pg = pags[pags.length - 1], vazia = pg.length && pg[pg.length - 1] !== '' ? 1 : 0;
    if (pg.length + vazia + ls.length > LINHAS) pags.push([...ls]);
    else { if (vazia) pg.push(''); pg.push(...ls); }
  }
  return pags.map((p) => ({ txt: p.join('\n') }));
}

function abas(T, CARDS) {
  return [
    {
      nome: 'CONTROLES', icone: 'CONTROLE',
      paginas: [
        // linhas 0..6 ficam para o desenho do controle
        { desenho: true, txt: '\n\n\n\n\n\n\n' + [
          duas('{CRUZ} CURSOR', '{A} AÇÃO'), '',
          duas('{B} JOGA FORA', '{X} REFRI'), '',
          duas('{Y} ENTREGA', 'START PAUSA')].join('\n') },
        { txt: [
          '{A} ESCOLHE O SABOR, TIRA', '    DO ÓLEO E ENTREGA O', '    PASTEL.', '',
          '{B} JOGA FORA O PASTEL', '    QUE ESTÁ NA MÃO.', '',
          '{X} PEGA O REFRI PARA O', `    COMBO (NÍVEL ${NV.REFRI}).`, '',
          '{Y} ANOTA A ENTREGA E PÕE', '    NO SACO DO MOTOBOY', `    (NÍVEL ${NV.TELEFONE}).`].join('\n') },
        { txt: [
          'START PAUSA O JOGO.', '',
          '{L} {R} TROCAM AS ABAS DA', '    LOJA E DA AJUDA.', '',
          'NO MINIJOGO, REPITA OS', 'BOTÕES DO TOPO ANTES DO', 'TEMPO ACABAR.'].join('\n') },
      ],
    },
    {
      nome: 'COMO JOGAR', icone: 'LIVRO',
      paginas: [
        { txt: [
          '1. O CLIENTE CHEGA E O', '   BALÃO MOSTRA O SABOR.', '',
          '2. NA MESA, ESCOLHA O', '   SABOR E APERTE {A}.', '',
          '3. REPITA OS BOTÕES DO', '   TOPO PARA FECHAR O', '   PASTEL.', '',
          '4. ESPERE A BARRA DO CESTO', '   FICAR VERDE E APERTE {A}.'].join('\n') },
        { txt: [
          '5. O CURSOR VAI ATÉ QUEM', '   PEDIU: APERTE {A} PARA', '   ENTREGAR.', '',
          'CRU OU QUEIMADO, O CLIENTE', 'RECLAMA. NO PONTO VERDE', 'ELE FICA FELIZ E DÁ', 'GORJETA.', '',
          'SE A PACIÊNCIA ACABAR, O', 'CLIENTE VAI EMBORA.'].join('\n') },
        { txt: [
          'BALÃO COM LATINHA: COMBO.', 'PEGUE O REFRI ({X}) ANTES', 'DE ENTREGAR.', '',
          'BALÃO COM 2: PEDIDO DUPLO.', '',
          'TELEFONE TOCANDO: {Y}', 'ANOTA A ENTREGA. COM O', 'PASTEL NA MÃO, {Y} PÕE NO', 'SACO DO MOTOBOY.', '',
          'CESTO QUEBRADO: {A} NELE E', 'REPITA 5 BOTÕES.'].join('\n') },
      ],
    },
    { nome: 'NÍVEIS', icone: 'ESTRELA', paginas: niveisPaginas(T, CARDS) },
    {
      nome: 'EVOLUÇÃO', icone: 'GRAFICO',
      paginas: [
        { txt: [
          'O DINHEIRO VEM DAS VENDAS', 'E GORJETAS. NO FIM DO DIA', 'SAEM O ALUGUEL E OS', 'SALÁRIOS.', '',
          'CADA PASTEL GASTA UMA', 'PORÇÃO DO ESTOQUE. COMPRE', 'INGREDIENTES NA LOJA.', '',
          'CLIENTE FELIZ DÁ XP. COM', 'XP VOCÊ SOBE DE NÍVEL E', 'LIBERA NOVIDADES (VEJA A', 'ABA NÍVEIS).'].join('\n') },
        { txt: [
          'A REPUTAÇÃO (0 A 100) TRAZ', 'MAIS CLIENTES. SOBE COM', 'CLIENTE FELIZ E CAI COM', 'RECLAMAÇÃO.', '',
          'MISSÕES (* NO RODAPÉ) DÃO', 'R$ 50 E XP.', '',
          'NA LOJA, MELHORE A', 'FRITADEIRA E O BALCÃO,', 'CONTRATE A EQUIPE E', 'REFORME O SALÃO.'].join('\n') },
        { txt: [
          `NO NÍVEL ${NV.LOJA}, ABRA LOJAS EM`, 'OUTROS BAIRROS: CADA UMA', 'DÁ LUCRO TODO DIA.', '',
          `NO NÍVEL ${NV.FRANQUIA}, COM 3`, 'DESAFIOS VENCIDOS E', 'REPUTAÇÃO 70, VENDA', 'FRANQUIAS.', '',
          'O MAPA (LOJA, ABA REDE)', 'MOSTRA A REDE. CHEGUE A', '10 UNIDADES PARA FORMAR', 'O IMPÉRIO!'].join('\n') },
      ],
    },
  ];
}

module.exports = { abas, LARG, LINHAS, tam };
