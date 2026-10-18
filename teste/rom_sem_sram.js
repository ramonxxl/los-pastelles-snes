// copia a ROM com o cabecalho dizendo "sem SRAM" (tipo $00, tamanho da SRAM 0)
// para testar o cartucho sem bateria: gen/LosPastelles_sem_sram.sfc
// uso: node teste/rom_sem_sram.js  (depois do node build.js)
'use strict';
const fs = require('fs');
const path = require('path');
const raiz = path.join(__dirname, '..');
const rom = fs.readFileSync(path.join(raiz, 'LosPastelles.sfc'));
const H = 0x7FC0;                  // cabecalho LoROM
rom[H + 0x16] = 0x00;              // so ROM
rom[H + 0x18] = 0x00;              // sem SRAM
rom.writeUInt16LE(0xFFFF, H + 0x1C);
rom.writeUInt16LE(0x0000, H + 0x1E);
let soma = 0;
for (const b of rom) soma = (soma + b) & 0xFFFF;
rom.writeUInt16LE(soma ^ 0xFFFF, H + 0x1C);
rom.writeUInt16LE(soma, H + 0x1E);
const saida = path.join(raiz, 'gen', 'LosPastelles_sem_sram.sfc');
fs.writeFileSync(saida, rom);
console.log('ROM sem SRAM: ' + saida);
