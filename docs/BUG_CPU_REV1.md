# DMA geral com HDMA ligado: risco de travar no SNES de CPU revisão 1

Relatório de auditoria, 2026-11-14. **Nada foi corrigido nem testado em hardware**; é leitura de código.

## Resumo

As cargas de cena do jogo fazem DMA para a VRAM com a tela apagada, mas com o HDMA da cena anterior ainda ligado.
Nos consoles com a primeira revisão da S-CPU isso pode travar a CPU. A correção sugerida é uma linha em `ScreenOff`.

## O defeito do hardware

Manual oficial de desenvolvimento do SNES, Book I, capítulo 25 "Documented Problems", Problem 1 (pág. 2-25-1):

- Na **S-CPU versão 1**, se uma DMA geral (`$420B`) **termina** nos primeiros 2,24 µs do H-blank (cerca de 48 ciclos
  mestres) das linhas 0–224, ou no começo da linha 0, **com HDMA em uso**, a CPU pode travar ou o HDMA sair errado.
- O canal não importa: basta haver HDMA ligado em qualquer canal (`$420C` ≠ 0).
- Não acontece se a DMA geral só roda no V-blank, ou se o HDMA está desligado.
- O HDMA continua rodando com a tela apagada (forced blank), então apagar a tela não protege.
- Só os consoles da primeira revisão têm o defeito, e nenhum emulador o reproduz. O único sintoma é um relato de
  "trava só nesse console".

Origem desta auditoria: o patch do Mega Man X3 sem Cx4 (`~/projetos/mx3`, commit `7d9bb6a`) travava na abertura só
nesses consoles por causa de uma DMA geral no meio do quadro com HDMA ligado.

## O que acontece neste projeto

Conferido no código:

1. `ScreenOff` (`src/main.s:499-507`) grava `INIDISP = $80` e `NMITIMEN = $01` (NMI desligada). Não toca em `$420C`.
2. `$420C` (`HDMAEN`, `src/ui.s:14`) só é escrito dentro da NMI:
   - `src/ui.s:202` — `stz HDMAEN` nos modos OFF e TÍTULO;
   - `src/ui.s:242` — `HDMAEN = $80` nos modos PAINEL e HUD (canal 7, degradê por `COLDATA`);
   - `src/ui.s:170` — `HDMAEN = $60` na abertura elástica da caixa (canais 5 e 6);
   - `src/ui.s:827` — balão do tutorial (`TutNmi`);
   - `src/main.s:361` — `stz HDMAEN` quando `dim_on` (pausa, tutorial escurecido).
3. `UiOff`, `UiPanelOn` e `UiHudOn` (`src/ui.s:39-85`) só mudam a variável `ui_mode`; o registrador muda na NMI
   seguinte.
4. Como `ScreenOff` desliga a NMI, o `$420C` fica com o valor que a última NMI escreveu para a cena **anterior**. As
   DMAs de carga que vêm depois (`VRAM_LOAD` / `DmaVram`, `src/main.s:479`) rodam com esse HDMA ativo.

Portanto: toda carga de cena que sai de uma tela em modo PAINEL ou HUD (ou durante a abertura da caixa) faz DMA geral
com HDMA ligado. Cargas que saem do título, do logo ou do mapa (modos TÍTULO/OFF) rodam com `$420C = 0` e são seguras.
No boot também é seguro (`InitHardware`, `src/main.s:436-440`, zera o registrador).

As DMAs da própria NMI (OAM, animação, mapa do BG3, CGRAM; `src/main.s:304-346`, no máximo ~3,1 KB por quadro) rodam
no V-blank e não entram no problema.

## Pontos afetados

Chamadas de `ScreenOff` seguidas de carga por DMA (as chamadas foram conferidas; o conteúdo de cada carga e as
transições vêm da auditoria automática):

| Local | Cena | Cargas |
|---|---|---|
| `src/telas.s:101` | `TitleInit` (logo / título) | tiles e mapas do BG1, xadrez do BG2, OBJ |
| `src/telas.s:390` | (não classificado pela auditoria) | — |
| `src/telas.s:528` | `CardInit` | `LoadMenuScene` + retratos |
| `src/telas.s:885` | `ResultsInit` | `LoadMenuScene`; ícones em `DrawResults` (`src/banco28.s:155-171`) |
| `src/telas.s:1474` | `ShopInit` | `LoadMenuScene` + ícones |
| `src/telas.s:2444` | `MapInit` / `MapCarrega` | tiles e mapa do mapa |
| `src/extra.s:57` | `OptInit` | `LoadMenuScene` |
| `src/extra.s:353` | `ChooseInit` | `MapCarrega` |
| `src/extra.s:574` | `SlotsInit` | `LoadMenuScene` |
| `src/extra.s:909` | `SplashInit` | `LoadMenuScene` |
| `src/extra.s:1151` | `TrofInit` | `LoadMenuScene` |
| `src/segredo.s:64` | `SecretInit` | `LoadMenuScene` |
| `src/game.s:40` | `DayInit` → `LoadShopScene` (`src/extra.s:486-542`) | tiles do BG1, mapas, tutorial, ajuda, animação (mais de 10 KB) |
| `src/banco28.s:2702-2727` | `SenhaInitL` | teclado da senha + `LoadMenuScene` |

Transições apontadas como as mais expostas (HDMA ligado na cena de origem):

- expediente (HUD) → resultados (`src/game.s:946` → `ResultsInit`);
- pausa → sair → título (`src/game.s:525-531`);
- carta ou outra tela de painel → expediente (`PreDayInit` → `DayInit`);
- loja, opções, troféus e demais telas de painel → próxima cena.

Cada carga tem milhares de bytes, ou seja, atravessa muitas linhas; a chance de terminar exatamente na janela de
48 ciclos é de poucos por cento por DMA, mas são várias DMAs por troca de cena e muitas trocas por partida.

## Correção sugerida (não aplicada)

Zerar o registrador em `ScreenOff`, depois de desligar a NMI:

```asm
ScreenOff:
    lda #$80
    sta bright
    sta INIDISP
    lda #$01
    sta NMITIMEN
    stz HDMAEN          ; nenhuma DMA de carga com HDMA ligado (S-CPU versão 1)
    rts
```

A NMI religa o HDMA sozinha no primeiro quadro depois que a cena nova liga a NMI de novo (`UiNmi` grava `$420C` todo
quadro conforme `ui_mode`), então não deve ser preciso mais nada. `HDMAEN` está definido em `src/ui.s`; `main.s`
já o usa na linha 361.

A conferir ao aplicar:

- se alguma carga por DMA roda **sem** passar por `ScreenOff` (com a NMI ligada e a tela acesa ou em fade);
- se `telas.s:390` é uma carga de cena como as outras;
- se alguma rotina faz DMA geral no laço principal durante o expediente (a auditoria não achou nenhuma).

## Como verificar

O defeito não aparece em emulador, mas dá para provar que a condição deixou de existir. O script
`~/.claude/skills/snes-otimizacao/scripts/lua/dmarev1.lua` registra, no Mesen 2, cada escrita em `$420B` fora do
V-blank com o último `$420C` escrito diferente de zero:

```sh
env FRAMES=6000 TIMEOUT=900 ROUTE="start@300:3,..." \
  ~/.claude/skills/snes-otimizacao/scripts/mesen_run.sh \
  /caminho/absoluto/LosPastelles.sfc /caminho/absoluto/saida \
  ~/.claude/skills/snes-otimizacao/scripts/lua/dmarev1.lua
```

- `saida/rev1.txt` lista cada DMA nessa condição (PC, valor do HDMA, linha e posição de início e fim); tem de ficar
  vazio depois da correção.
- `saida/resumo.txt` agrupa por PC.
- Use caminhos absolutos e uma rota de botões (ou um savestate em `STATE=`) que passe por expediente → resultados e
  por telas de painel.

A confirmação final é rodar num SNES de CPU revisão 1 (ou pedir a quem tenha um).
