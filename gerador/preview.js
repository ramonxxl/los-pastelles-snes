// Gera PNGs de pre-visualizacao da arte (pasta gen/preview)
'use strict';
const fs = require('fs'), path = require('path');
const { png } = require('./gfx');
const A = require('./arte');
const out = path.join(__dirname, '..', 'gen', 'preview'); fs.mkdirSync(out, { recursive: true });
for (let v = 0; v < 5; v++) for (let r = 0; r < 3; r++) fs.writeFileSync(path.join(out, `loja${v}_${r}.png`), png(A.shopScene(v, r), [A.shopPal(v)], 2));
fs.writeFileSync(path.join(out, 'titulo.png'), png(A.titleScene(), [A.PAL_TITLE.map((c, i) => i === 14 ? '#F8F0D0' : i === 15 ? '#F84838' : c)], 3));
fs.writeFileSync(path.join(out, 'menu.png'), png(A.menuScene(), [A.PAL_MENU], 2));
// mapa da expansao: node gerador/mapa.js (gen/preview/mapa_base.png e mapa_cheio.png)
const S = A.buildSprites();
const pals = S.pals.slice(); pals[7] = S.portPals[1];
fs.writeFileSync(path.join(out, 'sprites.png'), png(S.sheet, pals, 4));
console.log(S.ids);
