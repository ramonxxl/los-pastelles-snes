# TO-DO

Lista de trabalho pendente. Antes de cada item, reler as regras do `CLAUDE.md` (limite de sprites por linha, banco 0 cheio, larguras de texto, alinhamento 8×8 dos botões, testes em Mesen sem save).

## Correções

- [x] **"PRACA" → "PRAÇA"** no evento `EV_FESTIVAL` (`gerador/textos.js:236`). O glifo `Ç` já existe em `gerador/fonte.js`. Procurar outras ocorrências sem cedilha/acento (`grep -rni praca gerador/ src/`) e conferir se a quebra de linha continua cabendo no card.

- [x] **Soft-lock: dia começa sem estoque de pastel.** Feito: `DiaBloqueado` (`src/banco28.s`) no início de `PreDayInit`; carta `SEMESTOQUE` com {A} loja / {B} menu; sem dinheiro para o estoque, o mestre dá 10 porções (carta `FALIU`). Novos impedimentos entram em `DiaBloqueado`.
  - Hoje, se o dia começa com `s_stock` = 0, o jogador é obrigado a passar o dia inteiro falhando para só então chegar à loja e comprar estoque.
  - Correção: antes de iniciar o dia (no `ST_PREDAY` / `DayInit`), checar se há algo que impeça o dia de acontecer normalmente. Se houver, mostrar uma caixa explicando o problema (ex.: "SEM ESTOQUE DE PASTEL!") com duas opções:
    1. voltar ao menu principal (`ST_TITLE`);
    2. ir à loja (`ST_SHOP`) para resolver — e da loja seguir para o dia normalmente.
  - Fazer a checagem genérica (lista de impedimentos), para incluir outros casos além do estoque. Levantar quais existem (ex.: estoque menor que o mínimo para um pedido, todos os cestos quebrados?).
  - Cuidar do caso sem dinheiro para comprar estoque (a loja não resolveria): definir saída (ex.: estoque mínimo de emergência).
  - Textos novos em `gerador/textos.js`, respeitando a largura das caixas; opções com `{A}`/`{CIMA}`/`{BAIXO}` e rodapé com `Footer`. Banco 0 cheio: código em outro banco.

- [x] **Acentos faltando em textos.** Ex.: "LUCRO DOS ULTIMOS DIAS" (ÚLTIMOS), carta `EV_CRITICO` ("CRITICO GASTRONOMICO" → CRÍTICO GASTRONÔMICO). Revisar todo `gerador/textos.js` procurando palavras sem acento.

- [x] **Acento agudo quase invisível na fonte.** No `Ú` (`gerador/fonte.js`), o acento é um único pixel (linha 0, coluna 3) colado na perna direita do U. Com o contorno e a sombra da fonte, parece só uma perna mais alta, e "ÚLTIMOS" (gráfico do fim do dia) e "MÚSICA" (opções) ficam parecendo sem acento.
  - `Á`, `É`, `Í` e `Ó` usam o mesmo pixel `...#.` logo acima do corpo da letra, então provavelmente têm o mesmo problema. Conferir todos em captura ampliada (o `Ç` e os acentos `^`/`~` parecem estar bem).
  - Correção: redesenhar os glifos acentuados para o acento ficar separado do corpo por uma linha vazia (por exemplo, encurtar o corpo da letra em 1 pixel, como já fazem `Ã`/`Â`/`Ê`), com um traço inclinado de 2 pixels. Os glifos são 5×7 num tile 8×8 com contorno e sombra, então conferir que nada passa do tile.
  - Feito: `Á` `À` `É` `Í` `Ó` `Ú` com traço de 2 pixels na linha 0 (`...##`; `##...` no `À`), linha vazia e corpo de 5 linhas, no padrão de `Ã`/`Â`/`Ê`. O traço inclinado em 2 linhas deixava o corpo com 4 linhas e a letra parecia minúscula.

- [x] **Gráfico "LUCRO DOS ÚLTIMOS DIAS" só mostra a barra do primeiro dia.** Os rótulos dos dias (1, 2, 3…) aparecem, mas só a primeira barra é desenhada.
  - Causa (`DrawChart` em `src/banco28.s`): o passo da escala (valor de cada bloco = maior lucro / 8) fica em `tmp2`, mas o rótulo do dia embaixo de cada barra é impresso com `PrintNum` → `PrintStr`, que usa `tmp2` como variável de trabalho (`sta tmp2` em `PrintStrB`, `src/main.s`). Depois do primeiro rótulo, o passo vira ~1400 e as barras seguintes ficam com altura 0.
  - Feito: o passo é salvo na pilha em volta do `PrintNum` do rótulo. De quebra, o número do dia ficou embaixo da barra (antes ficava à direita). `teste/resultado_cheio.lua` força 7 dias de histórico com lucros e prejuízos.

- [x] **Não falar em "bateria" nem em "SRAM" para o jogador.** Cartuchos feitos sem a função de salvar não têm como receber bateria; dizer "sem bateria" dá a entender que dá para colocar uma bateria nova, e não dá. Sem SRAM, o jogo simplesmente não oferece salvar/carregar (sem CONTINUAR, sem escolha de espaço) e usa só o password, sem apresentar isso como um problema do cartucho.
  - Feito: `SD_20` → "MOSTRA O PASSWORD DESTE / JOGO PARA CONTINUAR / DE ONDE PAROU." e `SD_19N` → "COMEÇA O PRÓXIMO DIA. / ANOTE O PASSWORD / ANTES DE SAIR."; a ajuda e as cartas não falavam de bateria. No `LEIAME.md` a linha do password não cita bateria nem SRAM; a nota técnica da placa continua citando, e agora diz que sem SRAM o jogo continua pelo password.
  - Textos do jogo (`gerador/textos.js`): `SD_20` ("...CONTINUAR SEM BATERIA."), `SD_19N` ("SEM BATERIA: ANOTE O PASSWORD...") e qualquer outro que fale do cartucho. Sugestões: `SD_20` → "MOSTRA O PASSWORD DESTE\nJOGO PARA CONTINUAR\nDE ONDE PAROU."; `SD_19N` → "COMEÇA O PRÓXIMO DIA.\nANOTE O PASSWORD\nANTES DE SAIR.". Conferir a ajuda da pausa (`gerador/ajuda.js`) e as cartas.
  - `LEIAME.md` (linha do Password: "para continuar sem bateria"): descrever o password como forma de continuar de onde parou, sem citar bateria. As notas técnicas de gravação do cartucho (placa com SRAM e bateria) podem ficar.
  - Comentários do código e `CLAUDE.md` podem continuar dizendo "sem SRAM" (o jogador não vê).
  - Conferir com `grep -rni "bateria\|sram" gerador/ LEIAME.md` no fim.

## Melhorias

Ordenadas da mais simples para a mais complexa, respeitando dependências (fazer na ordem).

1. - [x] **Emoji do sabor ao lado do pastel na fritura.**
     - Cada cesto com pastel fritando mostra, ao lado, o emoji do sabor (🥩 🧀 🍗 🥓 etc.), para o jogador saber qual pastel vai pegar antes de pegar.
     - Reaproveitar os sprites de sabor de `emoji_sprites.py`; some quando o cesto esvazia. Atenção ao limite de sprites por linha com vários cestos lado a lado (pode valer usar ícone 8×8 em vez de 16×16).
     - Vem primeiro porque é o menor e cria a rotina "desenhar ícone de sabor" que o item 2 reaproveita.

2. - [x] **Indicador visual do que está na mão do jogador.** *(depende do 1)*
     - Feito: `MaoSprites` (`src/banco28.s`), chamada pelo `DayDraw` logo após o cursor. Mão 🫴 (`SPR_MAO`) à direita do cursor, balançando com ele, com o sabor 8×8 do pastel e/ou a latinha do combo sobre os dedos; mão vazia não mostra nada. A HUD continua mostrando o item no rodapé. Foto de conferência: `teste/mao.lua`.
     - Mostrar um emoji de mão (✋/🫴) combinado com o emoji do que foi pego — sabor do recheio (🥩 🧀 🍗 🥓 etc.) ou pastel pronto do sabor X.
     - Objetivo: o jogador não precisar lembrar o que pegou nem qual pastel é qual (ex.: "pastel de queijo na mão").
     - Atualizar sempre que a mão mudar (pegar, montar, entregar, descartar); mão vazia não mostra nada (ou mão aberta vazia).
     - Novo sprite: só a mão. Conferir em `game.s` quais estados de "mão" existem de fato. Preferir junto ao cursor (fixo na HUD seria refeito no item 9).
     - **Banco 0 está cheio** (hoje ~390 bytes livres no fim do RODATA, mas reservados): o código novo vai para o banco 28 (`src/banco28.s`, `JSL`/`RTL`, chamando o banco 0 com `FAR0`). Se precisar de bytes no banco 0, mover outra rotina grande para lá, como foi feito com `DrawChart`. Os sabores 8×8 já existem (`SPR_MINI` + sabor, tiles consecutivos).

3. - [x] **Tela de fim do dia (resultados) modernizada.**
     - Feito: `DrawResults` foi para o banco 28 e usa uma segunda folha de emojis (`ICONES_RES` em `gerador/icones.py`); só sobraram texto no título, no desafio e na missão. Gráfico com 📊 e 🥇. Fotos: `teste/resultado.lua` e `teste/resultado_cheio.lua`.
     - Usar emojis no lugar de rótulos e cortar texto sempre que um ícone + número bastar.
     - Tela isolada, fora do dia (sem disputa de sprites com clientes); usa os ícones emoji já existentes (`IconeSprite`/`ICO_*`).

4. - [x] **Loja do caixa com abas por tipo de item.**
     - Feito: 4 abas (DIA, LOJA, EQUIPE, REDE; `ShopOrd`/`ShopAbaIni` em `src/telas.s`), sem rolagem (até 6 itens por aba). L/R (e ◀/▶) trocam de aba; barra com `{L}`/`{R}` (tokens novos) e pílula atrás da aba escolhida. Fotos: `teste/loja.lua`.
     - Agrupar os 19 itens da loja (`ShopName`/`ShopDesc`) por categoria, uma aba por grupo.
     - L e R trocam de aba.
     - Mostrar ícones dos botões L e R ao lado das abas (criar tokens/sprites `{L}`/`{R}` no padrão de `{A}`/`{B}`, se ainda não existirem).

5. - [x] **Menu de pausa no estilo do tutorial.**
     - Feito: a pausa usa o balão do tutorial (`dim_on = 2`), com ▶️/🏠 ao lado dos itens (`PauseSprites`, chamada no fim do `TutSprites`), aviso só com SAIR escolhido e rodapé `{A}: ESCOLHER` em pílula. {B} volta ao jogo. Teste: `teste/pausa.lua`.
     - Redesenhar a pausa com o mesmo balão creme do tutorial (BG2 + janela + escurecimento via HDMA, como `TutBox`/`TutNmi`), um emoji por item e rodapé com pílula (`Footer`).
     - Mais trabalho que a loja: mexe com HDMA/janelas por cima do jogo e com o limite de sprites (esconder sprites sob o balão, como `TutSprites`).

6. - [x] **Ajuda dentro do menu de pausa.** *(depende do 4 e do 5)*
     - Feito: AJUDA (❓) entre CONTINUAR e SAIR; balão grande (BG2, `dim_on = 3`) com 4 abas por {L}/{R} (🎮 CONTROLES com o controle do Super Famicom desenhado no BG2, 📘 COMO JOGAR, ⭐ NÍVEIS gerada de `gerador/niveis.js`, 📈 EVOLUÇÃO) e páginas por {CIMA}/{BAIXO}. Níveis com fonte única (`NV_*`). Textos em `gerador/ajuda.js` (largura checada no build). Teste: `teste/ajuda.lua`.

7. - [x] **Cenário da loja com emojis.**
     - Feito: `gerador/emoji_cenario.py` (como `emoji_sprites.py`) reduz e quantiza Twemoji na paleta de cada bairro; `shopScene` cola com `colaEmoji`. Janela 🪟 e vaso 🪴 (inicial), janela grande 🪟 e sacolas 🛍️ (centro comercial), quadro 🖼️ (residencial), livros 📚 junto da lousa (universitária), cidade 🏙️ na janela (empresarial), pastéis 🥟 na vitrine da reforma 1 e girassóis 🌻 nos vasos da reforma 2. A paleta da loja trocou a cor 11 (quase não usada) por verde e a 14 (creme quase igual à 3) por azul. Fotos: `teste/loja_cenario.lua`.
     - Ficaram de fora: o chef 🧑‍🍳 (a parede da cozinha fica embaixo dos sabores/cadeados e do cursor, e o resto da parede é coberto pelos clientes) e o Fundador (o sprite é de costas; o emoji é de frente).
     - Substituir desenhos simples de `gerador/arte.js` por arte partindo de emojis ajustados à interface — por exemplo (mas não só): chef 🧑‍🍳, vaso de planta 🪴, janela 🪟. Revisar o cenário inteiro procurando outros elementos candidatos.
     - São 5 bairros × 3 reformas (`shopScene`); atenção a paleta e tamanho de banco.
     - Antes da HUD (item 9) porque a HUD nova deve combinar com o cenário novo.

8. - [x] **Mapa da expansão redesenhado.**
     - Feito: `gerador/mapa.js` desenha o mapa em RGB seguindo a arte do Gemini (`Gemini_Generated_Image_mzvxjfmzvxjfmzvx.jpeg`: grama, estradas tracejadas com faixa de pedestres, rio com ponte, lago, plantação, faixas marrons) com predios, obras e árvores do Twemoji (`gerador/emoji_mapa.py`), e reduz para 6 paletas de BG. Terrenos em obra viram as lojas de cada bairro (a torre do distrito empresarial é desenhada à mão) e placas de venda viram franquias: remendos de tiles aplicados por `MapObras` (banco 28). A água corre (troca de cores, `MapAgua`). Fotos: `teste/mapa.lua`.
     - Refazer a arte do mapa (`mapScene` em `gerador/arte.js`, tela `ST_MAP`) com mais qualidade: visual moderno de 16 bits, sem cara de desenho de Paint feito por criança.
     - Usar emojis (Twemoji, como o resto do projeto) para os elementos do mapa (lojas, franquias, prédios, árvores, rios, estradas etc.).
     - Antes de desenhar, gerar com o Gemini uma arte conceitual em pixel art 16 bits como referência de composição, cores e estilo; a arte final continua gerada por código em `gerador/`.
     - Atenção à paleta (BG em 4bpp, 15 cores por paleta) e ao tamanho do banco onde o mapa fica.

9. - [x] **HUD do dia mais moderno.** *(depois do 2, do 7 e do 8)*
     - Feito: pílulas creme no topo (📅 dia, 🪙 dinheiro, ⭐ nível, ⏰ hora) e painel creme no rodapé com a linha de avisos/missão (os avisos que ficavam na linha 2 agora aparecem ali no lugar da missão, que volta quando o aviso acaba) e a de números (📦 estoque, ❤️ reputação, 🎯 meta). Layout em `gerador/hud.js`; texto e emojis em `HudValores`/`HudSprites` (`src/banco28.s`). Fotos: `teste/hud.lua`.
     - Trocar a HUD atual por balões (estilo do balão do tutorial / pílula), ícones de emoji (moeda, relógio, estrela etc.) e texto estilizado.
     - Cuidado com o limite de 32 sprites / 34 tiles por linha durante o jogo e com as paletas de sprite 3–7, que são dos clientes. Reservar espaço/sprites para os indicadores dos itens 1 e 2.

10. - [x] **Animação grande da montagem do pastel (minigame).**
      - Feito: cartão creme no BG2 na cozinha (64×48 px de pastel): massa → recheio (emoji do sabor por cima do monte) → dobra → fechamento com o garfo 🍴 → pronto ✨, com 2 quadros de morph entre as chaves (`gerador/morph.py`). Cada acerto anda até a chave proporcional ao progresso; errar chama `MgaErro` (gancho para o item 11). Player genérico `Anim*` em `src/banco28.s`; quadros nos bancos 29–31. Interface no CLAUDE.md ("Big animations"). Teste: `teste/montagem.lua`.
     - Pelo menos 5 quadros-chave da montagem (massa → recheio → dobra → fechamento → pastel pronto), exibidos grandes na tela.
     - Cada acerto de botão sorteado avança a animação; errar desvia para o desfecho de erro (item 11).
     - Arte baseada em emojis/glyphs da internet (Twemoji, como o resto do projeto), com quadros intermediários gerados por morph entre os quadros-chave para suavizar o movimento.
     - Gerar tudo por script em `gerador/` (como `emoji_sprites.py`); verificar espaço em banco/VRAM. Montar o gerador de morph de forma reutilizável para o item 11.

11. - [x] **Animação de erro: pastel indo para a lixeira.** *(depende do 10)*
      - Feito: `gerador/anim_lixeira.py` (referência `arte_fonte/lixeira/gemini_referencia.png`, gerada no Gemini): pastel aberto, lata com tampa e poeira 💨, 5 quadros-chave e intermediários que interpolam posição e ângulo das camadas (17 quadros). `MgaErro` toca a sequência no botão errado e no tempo esgotado (nunca no tutorial nem no conserto do cesto). Teste: `teste/lixeira.lua`.
      - Ideia futura: o descarte com {B} (`DayInput`, `TXT_M_LIXO`) pode reaproveitar a mesma animação, mais curta.

12. - [x] **Sistema de password (salvar sem SRAM).** *(depois do 4: o password aparece na loja)*
      - Feito: 20 caracteres (5 blocos de 4) de um alfabeto de 32 símbolos (`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`, sem O/0/I/1). O save vira um número em base mista (cada campo com a base exata da sua faixa), com nível+xp+desafios num índice só (tabela pré-calculada), dinheiro em ponto flutuante (perde no máximo 0,2%), estoque exato até 199 (depois de 10 em 10), contadores em degraus alinhados com missões e troféus, e o que dá para deduzir fora: 91 bits de jogo + 9 de verificação CRC, embaralhados por LFSR (`gerador/senha.js`). Opções ficam só na SRAM; dos troféus entram só os 3 que não dá para recalcular. Tela com teclado 8×4 (`ST_SENHA`), PASSWORD no título, VER PASSWORD na loja (aba DIA), detecção de SRAM no boot e modo sem SRAM. Testes: `teste/senha.lua` (inclui 30 jogos sorteados) e `teste/sem_sram.lua`.
      - **Uma única ROM.** No boot, detectar se o cartucho tem SRAM: gravar e reler dois padrões diferentes (ex.: `$55`/`$AA`) num endereço de SRAM, sem confiar em open bus, e restaurar o byte original. Guardar o resultado numa variável (ex.: `tem_sram`).
        - **Com SRAM:** mantém carregar/salvar como hoje **e** as opções de password (carregar password e depois salvar na SRAM, ou jogo novo na SRAM e depois ver o password dele).
        - **Sem SRAM:** só password. Esconder as opções de slot/salvar e não tentar ler/gravar SRAM.
      - **Onde aparece:** "carregar password" no menu principal; "mostrar password" onde hoje o jogo salva (fim do dia/loja). Se o password for curto o bastante (ver abaixo), mostrá-lo sempre no rodapé do menu de compras.
      - **Conteúdo:** o bloco `save_start`..`save_end` (~32 bytes úteis sem `s_magic`). Antes de codificar, compactar ao máximo: cada campo só com os bits do seu intervalo real (ex.: `s_fryer` 1..3 = 2 bits), limitar/arredondar campos grandes (`s_money`, `s_tot_*`) ou recalcular o que der. Pode usar o algoritmo mais pesado que couber, mesmo que a CPU demore para gerar (só roda em menu).
      - **Verificação:** dígito(s)/glifo(s) verificador(es) (CRC ou similar) + embaralhar os bits com chave fixa (LFSR/XOR), para que trocar um caractere mude tudo e combinações aleatórias quase nunca funcionem. Incluir um número de versão do formato.
      - **Alfabeto — decidir nesta ordem de preferência:**
        1. **Até 8 glifos do jogo** (ex.: QUEIJO CALABRESA FRANGO QUEIJO CARNE QUEIJO QUEIJO FRANGO). Atenção: 8 símbolos de 6 sabores ≈ 20 bits, e de 16 ícones = 32 bits, muito menos que o save atual (~100+ bits mesmo compactado). Só dá se o save for reduzido a quase nada; fazer a conta antes e descartar se não couber.
        2. **Conjunto pequeno, ex.: 16 símbolos** (hexadecimal, ou 16 ícones do jogo = 4 bits cada): mais caracteres, mas poucos botões para digitar e anotar.
        3. **A–Z (+ dígitos)** com teclado QWERTY virtual: só se os anteriores ficarem longos demais.
      - **Tela de digitação** (acessível pelo menu principal): teclado virtual moderno em pixel art, com as cores do jogo; com 16 símbolos, uma grade 4×4 em vez de QWERTY. Pensar na usabilidade no controle: cursor que dá a volta nas bordas, {B} apaga, {A} digita, START confirma, agrupar o código em blocos de 4 para facilitar a anotação, mensagem clara quando o password for inválido.
      - Opções de jogo (`OPT_SRAM`) e troféus: decidir se entram no password ou ficam só na SRAM.
      - Código em outro banco (banco 0 cheio). Teste Lua: gerar password, carregar e comparar o bloco do save; testar também o boot sem SRAM.

13. - [x] **Vozes com taxa maior (mais qualidade).**
      - Feito: música 10 → 14 kHz, falas em stream 10 → 16 kHz, vozes fixas em 9 kHz, todas com reforço de agudos (compensa o filtro gaussiano do DSP: +1,5 dB nas falas e +4 a +5 dB nas fixas, medido numa simulação da saída do DSP) e reamostragem soxr. A ROM passou para 2 MB (áudio nos bancos 32–63).
      - O que abriu espaço, medido com `teste/audio_orc.lua` num dia de fim de jogo: antes a lógica deixava só ~40 linhas ociosas e a música ficava sem dados em 17% dos quadros, mesmo a 10 kHz. HUD só reimprime o número que mudou, minijogo não reimprime o aviso todo quadro, `OamClear`/`AddSprite`/`NumConv` mais leves: mediana de 137 linhas (p10 106; no minijogo p50 122). Driver do SPC700 ecoa antes de avançar o ponteiro; a música passa na frente quando está quase vazia; anéis maiores (música 903 blocos com folga de 0,7 s, falas 333 com 0,2 s). Nenhum quadro com anel vazio; a música não desce de ~0,2 s de reserva.
      - Limites: o envio ao SPC700 (~2,4 bytes por linha ociosa) é o teto, e não o tamanho da ROM. Música a 16 kHz passou no Mesen com só ~0,05 s de reserva; ficou em 14 kHz por segurança. Vozes fixas a 10 kHz pedem ~2,3 KB a mais na memória do SPC700 (eco menor muda a reverberação das músicas de chiptune) — decidir.
      - Validar no console real: o driver do SPC700, os anéis e a ROM de 2 MB mudaram.
      - Objetivo: subir a taxa das vozes gravadas. A música tema (`VOZ_TEMA`, 10 kHz) já está boa; **não mexer nela**.
      - **Falas em stream** (10 kHz, voz 7 / anel B): o limite é o barramento. Hoje o dia tem ~170–180 bytes/quadro de folga, e música + fala usam ~94 + 94. Para subir a fala, liberar tempo de CPU por quadro otimizando o que compete com o `Bomba` (lógica do dia, montagem de OAM, uploads na NMI, `BtnSprites`/`PillSprites`, etc.). Perfilar antes (skill `snes-otimizacao`, Mesen) para achar os maiores consumidores.
      - Outras ideias: aumentar `LOTE_MAX`, acelerar o laço do `Bomba`, dar prioridade maior à fala enquanto toca, ajustar colchões (0,5 s música / 0,15 s fala).
      - **Vozes fixas** (9 kHz): o limite aqui é espaço na ARAM (~50 KB divididos entre elas), não barramento. Para subir, liberar ARAM (ex.: anéis menores, eco menor, mover vozes pouco frequentes para stream).
      - Medir o nível dos anéis nos quadros mais pesados antes e depois (anel vazio = estalo/corte). Validar no console real se possível. A troca de taxa regera o BRR (`arte_fonte/brr/`, precisa de ffmpeg).
