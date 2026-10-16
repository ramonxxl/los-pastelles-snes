; ================================================================ INTERFACE
; Efeitos visuais dos menus (tudo por HDMA, sem custo de CPU no quadro):
;  - painel com degrade de cor (subtracao de cor so dentro da janela do painel)
;  - faixa de selecao pulsante com chanfro 3D que desliza ate o item escolhido
;  - caixa que abre com efeito elastico (rolagem vertical por linha)
;  - faixas do HUD do expediente com brilho de vidro
;  - texto que aparece letra por letra (maquina de escrever)
;  - botoes do controle coloridos no meio do texto (sprites sobre glifos vazios)
;  - rodape das caixas numa pilula com degrade (sprites) logo abaixo do texto
;  - balao do tutorial (BG2) com o resto da tela, HUD incluso, escurecido
;  - xadrez do fundo (BG2) rolando para a direita sem parar
; Canais: 7 = COLDATA, 6 = BG1VOFS, 5 = BG3VOFS (o canal 0 fica com o DMA comum)

HDMAEN   = $420C
WOBJSEL  = $2125
WH0      = $2126
WH1      = $2127
CGWSEL   = $2130
CGADSUB  = $2131
COLDATA  = $2132

UI_OFF   = 0
UI_PANEL = 1
UI_HUD   = 2
UI_TITULO = 3              ; titulo: xadrez animado (BG2) atras da logo, sem degrade

; icones dos menus na folha de gerador/icones.py
ICO_MUSICA = 12
ICO_FALAS  = 5
ICO_VOLTAR = 18
ICO_NOVO   = 20
ICO_CONT   = 21
ICO_OPC    = 22
ICO_DIF    = 1                ; dificuldade: frigideira (o calor da cozinha)
ICO_SENHA  = 23               ; password: cadeado com chave

; ---------------------------------------------------------------- cenas
; chamada pelas cenas de painel: degrade, faixa desligada e animacao de abertura
UiPanelOn:
    .a8
    .i16
    ldx #0
@cp:
    lda f:UiPanelTab,x
    sta hdma_tab,x
    inx
    cpx #UI_TAB_LEN
    bne @cp
    lda #UI_PANEL
    sta ui_mode
    stz hl_y
    stz hl_cur
    stz hl_old
    lda #1
    sta ui_open
    rts

; cenas sem painel (logo, rua, mapa)
UiOff:
    .a8
    .i16
    stz ui_mode
    stz ui_open
    stz hl_y
    stz hl_old
    stz tw_on
    rts

; titulo: so o xadrez animado
UiTituloOn:
    .a8
    .i16
    jsr UiOff
    lda #UI_TITULO
    sta ui_mode
    rts

; expediente: brilho nas faixas do HUD
UiHudOn:
    .a8
    .i16
    jsr UiOff
    lda #UI_HUD
    sta ui_mode
    rts

; reabre a caixa (cartas seguidas)
UiReopen:
    .a8
    .i16
    lda ui_mode
    cmp #UI_PANEL
    bne :+
    lda #1
    sta ui_open
:   rts

; faixa de selecao na linha de texto do deslocamento X do bg3_buf (seta do menu)
UiMarkX:
    .a8
    .i16
    A16
    txa
    lsr a
    lsr a
    lsr a
    A8
    and #$F8               ; (X/64)*8 = linha * 8
    sta hl_y
    lda #8
    sta hl_h
    rts

; ---------------------------------------------------------------- NMI
; (A8/I16, DBR = $80) - registra os efeitos para o proximo quadro
UiNmi:
    .a8
    .i16
    lda ui_mode
    cmp #UI_PANEL
    beq :+
    cmp #UI_TITULO
    bne @nochk
:
    ; xadrez do BG2: anda 1 pixel para a direita a cada 2 quadros (HOFS = -quadro/2)
    A16
    lda frame
    lsr a
    eor #$FFFF
    inc a
    A8
    sta BG2HOFS
    xba
    and #$03
    sta BG2HOFS
    lda #$FF
    sta BG2VOFS
    lda #$03
    sta BG2VOFS
@nochk:
    lda ui_open
    beq @normal
    lda bright
    bmi @normal            ; tela desligada: espera acender
    beq @normal
    ; ----- abertura elastica: canais 5/6 escrevem a rolagem vertical por linha
    lda ui_open
    dec a
    A16
    and #$00FF
    asl a
    tax
    lda f:UiOpenOfs,x
    clc
    adc #.loword(UiOpenTab)
    sta $4352
    sta $4362
    A8
    lda #^UiOpenTab
    sta $4354
    sta $4364
    lda #$02
    sta $4350
    sta $4360
    lda #<BG3VOFS
    sta $4351
    lda #<BG1VOFS
    sta $4361
    lda #$60
    sta HDMAEN
    lda #$07               ; BG1 + BG2 + BG3 (sprites aparecem quando a caixa abre)
    sta TM
    lda #$30
    sta CGWSEL
    stz CGADSUB
    inc ui_open
    lda ui_open
    cmp #(UI_N_OPEN+1)
    bcc :+
    stz ui_open
:   rts
@normal:
    lda #$FF
    sta BG1VOFS
    lda #$03
    sta BG1VOFS
    lda #$FF
    sta BG3VOFS
    lda #$03
    sta BG3VOFS
    lda #$15
    sta TM
    lda ui_mode
    cmp #UI_PANEL
    beq @panel
    cmp #UI_HUD
    beq @hud
    cmp #UI_TITULO
    bne :+
    lda #$17               ; titulo: BG1 + BG2 (xadrez) + BG3 + sprites
    sta TM
:   stz HDMAEN
    lda #$30
    sta CGWSEL
    stz CGADSUB
    rts
@panel:
    lda #$17               ; BG1 + BG2 (xadrez) + BG3 + sprites
    sta TM
    ; subtrai cor no BG1, BG2 e no fundo, so dentro do painel (janela 1)
    lda #$20
    sta WOBJSEL
    lda #14
    sta WH0
    lda #241
    sta WH1
    lda #$10
    sta CGWSEL
    lda #$A3
    sta CGADSUB
    lda #$20               ; vermelho = 0 (o HDMA escreve verde e azul)
    sta COLDATA
    ldx #.loword(hdma_tab)
    stx $4372
    stz $4374
    bra @ch7
@hud:
    stz WOBJSEL
    stz CGWSEL
    lda #$21               ; soma cor no BG1 e no fundo
    sta CGADSUB
    ldx #.loword(UiHudTab)
    stx $4372
    lda #^UiHudTab
    sta $4374
@ch7:
    lda #$02
    sta $4370
    lda #<COLDATA
    sta $4371
    lda #$80
    sta HDMAEN
    rts

; ---------------------------------------------------------------- quadro
; chamada pelo laco principal: texto letra por letra e faixa de selecao
UiUpdate:
    .a8
    .i16
    jsr TypeStep
    jsr TutSprites
    jsr BtnSprites
    jsr PillSprites
    lda ui_mode
    cmp #UI_PANEL
    beq :+
    rts
:   ; apaga a faixa do quadro anterior (volta o degrade)
    lda hl_old
    beq @nores
    sta ui_ln
    lda hl_oldh
    sta ui_cnt
@res:
    jsr UiLineOfs
    lda f:UiPanelTab,x
    sta hdma_tab,x
    lda f:UiPanelTab+1,x
    sta hdma_tab+1,x
    inc ui_ln
    dec ui_cnt
    bne @res
    stz hl_old
@nores:
    lda hl_y
    bne :+
    stz hl_cur
    rts
:   lda ui_open
    beq :+
    rts
:   ; desliza ate a linha escolhida (metade do caminho por quadro)
    lda hl_cur
    bne :+
    lda hl_y
    sta hl_cur
:   lda hl_y
    sec
    sbc hl_cur
    beq @pos
    cmp #$80
    ror a                  ; diferenca / 2 com sinal
    bne :+
    lda hl_y               ; falta 1: encosta
    sta hl_cur
    bra @pos
:   clc
    adc hl_cur
    sta hl_cur
@pos:
    ; faixa comeca 1 linha acima do texto, para envolver a letra com folga
    lda hl_cur
    dec a
    sta hl_old
    sta ui_ln
    lda hl_h
    sta hl_oldh
    sta ui_cnt
    ; origem: pulso * (altura * 2) dentro da tabela da altura certa
    A16
    lda frame
    lsr a
    and #$001F
    tax
    A8
    lda f:UiPulse,x
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a                  ; * 16 (8 linhas x 2 bytes)
    sta ui_src
    A8
    lda hl_h
    cmp #16
    bne @wr
    A16
    lda ui_src
    asl a                  ; * 32 (16 linhas x 2 bytes)
    clc
    adc #(UiBand16 - UiBand8)
    sta ui_src
    A8
@wr:
    jsr UiLineOfs          ; X = destino
    txy
    ldx ui_src
    lda f:UiBand8,x
    sta hdma_tab,y
    lda f:UiBand8+1,x
    sta hdma_tab+1,y
    inx
    inx
    stx ui_src
    inc ui_ln
    dec ui_cnt
    bne @wr
    rts

; linha ui_ln (0..223) -> X = deslocamento na tabela HDMA (2 blocos de 112 linhas)
UiLineOfs:
    .a8
    .i16
    A16
    lda ui_ln
    and #$00FF
    cmp #224
    bcc :+
    lda #223
:   asl a
    inc a
    cmp #(1 + 2*112)
    bcc :+
    inc a                  ; pula o cabecalho do 2o bloco
:   tax
    A8
    rts

; ---------------------------------------------------------------- texto animado
; como PrintStr/PrintStrB, mas a caixa vai sendo escrita letra por letra
TypeStart:
    .a8
    .i16
    lda #0
TypeStartB:
    .a8
    .i16
    sta tw_ptr+2
    stx tw_ptr
    A16
    lda txt_pos
    asl a
    sta tw_pos
    sta tw_line
    A8
    lda txt_attr
    sta tw_attr
    stz tw_n
    lda #1
    sta tw_on
    rts

; escreve a proxima letra (espacos e quebras de linha nao gastam quadro)
TypeStep:
    .a8
    .i16
    lda tw_on
    bne @lp
    rts
@lp:
    lda [tw_ptr]
    A16
    inc tw_ptr
    A8
    cmp #$FF
    bne :+
    stz tw_on
    rts
:   cmp #$FE
    bne :+
    A16
    lda tw_line
    clc
    adc #64
    sta tw_line
    sta tw_pos
    A8
    bra @lp
:   ldx tw_pos
    sta bg3_buf,x
    pha
    cmp #FONT_BTN0
    bcc @nobtn
    cmp #(FONT_BTN0+N_BTN)
    bcs @nobtn
    jsr BtnReg
@nobtn:
    lda tw_attr
    sta bg3_buf+1,x
    inx
    inx
    stx tw_pos
    lda #1
    sta bg3_dirty
    pla
    cmp #FONT_SPACE
    beq @lp
    ; tique baixinho a cada 3 letras
    inc tw_n
    lda tw_n
    cmp #3
    bcc :+
    stz tw_n
    SFX SFX_TEXTO
:   rts

; termina o texto na hora (botao A durante a escrita)
TypeFinish:
    .a8
    .i16
@l: lda tw_on
    beq :+
    jsr TypeStep
    bra @l
:   rts

; ---------------------------------------------------------------- botoes no texto
; Os textos marcam botoes com {A} {B} {X} {Y} {CIMA}...: o glifo e vazio e um
; sprite 8x8 colorido e desenhado por cima. PrintStr/TypeStep registram a posicao
; (BtnReg); a cada quadro BtnSprites confere se o glifo ainda esta la (o texto pode
; ter sido apagado ou sobrescrito) e escreve os ultimos slots da OAM.

; A = glifo, X = deslocamento no bg3_buf (preserva X e Y)
BtnReg:
    .a8
    .i16
    sta btn_tcode
    stx btn_tpos
    phx
    phy
    ; mesma posicao ja registrada: reaproveita
    ldy #0
@same:
    lda btn_tab+2,y
    beq @nsame
    A16
    lda btn_tab,y
    cmp btn_tpos
    A8
    beq @put
@nsame:
    iny
    iny
    iny
    iny
    cpy #(BTN_SLOTS*4)
    bne @same
    ; senao, o primeiro registro livre ou obsoleto
    ldy #0
@free:
    lda btn_tab+2,y
    beq @put
    A16
    lda btn_tab,y
    tax
    A8
    lda bg3_buf,x
    cmp btn_tab+2,y
    bne @put
    iny
    iny
    iny
    iny
    cpy #(BTN_SLOTS*4)
    bne @free
    bra @out               ; tudo ocupado: fica sem o sprite
@put:
    A16
    lda btn_tpos
    sta btn_tab,y
    A8
    lda btn_tcode
    sta btn_tab+2,y
@out:
    ply
    plx
    rts

; escreve os slots OAM_BTN.. (chamada todo quadro, depois da tela montar a OAM)
BtnSprites:
    .a8
    .i16
    ldx #0
@lp:
    lda btn_tab+2,x
    beq @hide
    lda ui_open            ; caixa abrindo (texto esticado): espera
    bne @hide
    phx
    A16
    lda btn_tab,x
    tax
    A8
    lda bg3_buf,x
    plx
    cmp btn_tab+2,x
    beq @show
    stz btn_tab+2,x        ; o texto mudou: libera
@hide:
    lda #$F0
    sta oam_buf+OAM_BTN+1,x
    bra @nx
@show:
    ; posicao = (linha*32 + coluna)*2  ->  x = coluna*8, y = linha*8
    A16
    lda btn_tab,x
    and #$003F
    asl a
    asl a
    A8
    sta oam_buf+OAM_BTN,x
    A16
    lda btn_tab,x
    lsr a
    lsr a
    lsr a
    and #$00F8
    A8                     ; y = linha * 8 exato: 1 px acima, a sombra das letras
    sta oam_buf+OAM_BTN+1,x ; da linha de cima (BG3, na frente) cobre o botao
    lda btn_tab+2,x
    sec
    sbc #FONT_BTN0
    A16
    and #$00FF
    asl a
    tay
    lda BtnSprTile,y
    A8
    sta oam_buf+OAM_BTN+2,x
    xba
    and #$01
    ora #$30               ; prioridade 3, paleta 0
    sta oam_buf+OAM_BTN+3,x
@nx:
    inx
    inx
    inx
    inx
    cpx #(BTN_SLOTS*4)
    bne @lp
    ; tabela alta: 8x8 e x < 256 para os slots 116..127
    stz oam_buf+512+(OAM_BTN/16)
    stz oam_buf+512+(OAM_BTN/16)+1
    stz oam_buf+512+(OAM_BTN/16)+2
    rts

; ---------------------------------------------------------------- rodape em pilula
; X = texto (banco 0), A = linha. Centraliza o texto na linha e desenha atras
; dele uma pilula creme com degrade (sprites 16x16 nos ultimos slots da OAM).
Footer:
    .a8
    .i16
    sta ft_y
    stx tmp3
    ldy #0                  ; tamanho do texto
:   lda a:0,x
    cmp #$FF
    beq :+
    inx
    iny
    bra :-
:   tya
    sta ft_x1
    lda #32                 ; coluna = (32 - tamanho) / 2
    sec
    sbc ft_x1
    lsr a
    sta ft_x0
    lda ft_y                ; txt_pos = linha * 32 + coluna
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    sta txt_pos
    lda ft_x0
    and #$00FF
    clc
    adc txt_pos
    sta txt_pos
    asl a
    sta ft_pos
    A8
    lda #((7<<2)|$20)
    sta txt_attr
    ldx tmp3
    jsr PrintStr
    ; x da pilula: uma coluna antes do texto ate uma depois
    lda ft_x0
    dec a
    asl a
    asl a
    asl a
    sta ft_x0
    lda ft_x1               ; peca da direita em x0 + (tamanho + 2) * 8 - 16
    asl a
    asl a
    asl a
    clc
    adc ft_x0
    sta ft_x1
    lda ft_y                ; y = linha * 8 - 4 (pilula de 16 px centrada no texto)
    asl a
    asl a
    asl a
    sec
    sbc #4
    sta ft_y
; liga a pilula com ft_pos (deslocamento no bg3_buf de um caractere que ja esta
; escrito), ft_x0, ft_x1 (x da peca da direita) e ft_y prontos. Ela some sozinha
; quando aquele caractere muda (o texto foi apagado ou reescrito)
PilulaLiga:
    .a8
    .i16
    ldx ft_pos
    lda bg3_buf,x
    sta ft_code
    lda #1
    sta ft_on
    rts

; icone emoji A (0..23, gerador/icones.py) em spr_x/spr_y; carry = 1: balanca
; (item escolhido). Precisa da folha de icones carregada (IconGfx/IconPal)
IconeSprite:
    .a8
    .i16
    php
    A16
    and #$00FF
    tax
    A8
    lda f:IconPalTab,x
    asl a
    ora #$30
    sta spr_attr
    txa                     ; tile = (i % 8) * 2 + (i / 8) * 32
    and #$07
    asl a
    sta spr_tile
    txa
    and #$F8
    asl a
    asl a
    clc
    adc spr_tile
    sta spr_tile
    stz spr_tile+1
    plp
    bcc :+
    A16
    lda frame
    lsr a
    and #$001F
    tax
    A8
    lda f:UiBob,x
    clc
    adc spr_y
    sta spr_y
:   lda #1
    sta spr_size
    jsr AddSprite
    stz spr_size
    rts

PillSprites:
    .a8
    .i16
    ldx #0
    lda ft_on
    beq @hide
    lda ui_open             ; caixa abrindo: espera
    bne @hide
    ldy ft_pos
    lda bg3_buf,y
    cmp ft_code
    beq :+
    stz ft_on               ; o texto do rodape sumiu
    bra @hide
:   ; esquerda, meio (repetido; pode sobrepor) e direita
    lda ft_x0
    sta tmp
    A16
    lda #SPR_PILULA_E
    sta tmp2
    A8
@lp:
    lda tmp
    cmp ft_x1
    bcc :+
    lda ft_x1
    A16
    ldy #SPR_PILULA_D
    sty tmp2
    A8
:   sta oam_buf+OAM_PILL,x
    lda ft_y
    sta oam_buf+OAM_PILL+1,x
    lda tmp2
    sta oam_buf+OAM_PILL+2,x
    lda tmp2+1
    and #$01
    ora #$32                ; prioridade 3, paleta 1
    sta oam_buf+OAM_PILL+3,x
    inx
    inx
    inx
    inx
    lda tmp
    cmp ft_x1
    bcs @hide               ; a direita ja foi
    clc
    adc #16
    sta tmp
    A16
    lda #SPR_PILULA_M
    sta tmp2
    A8
    cpx #(PILL_SLOTS*4)
    bne @lp
@hide:
    cpx #(PILL_SLOTS*4)
    beq @hi
    lda #$F0
    sta oam_buf+OAM_PILL+1,x
    inx
    inx
    inx
    inx
    bra @hide
@hi:
    ; tabela alta: todos 16x16, x < 256
    lda #$AA
    sta oam_buf+512+(OAM_PILL/16)
    sta oam_buf+512+(OAM_PILL/16)+1
    sta oam_buf+512+(OAM_PILL/16)+2
    sta oam_buf+512+(OAM_PILL/16)+3
    rts

; ---------------------------------------------------------------- balao do tutorial
; NMI com dim_on = 2: BG2 (balao) ligado; a janela 1 esconde o BG1 dentro do balao
; e o HDMA limita a janela as linhas do balao e escurece o BG3 (HUD) fora dele
TMW      = $212E
W12SEL   = $2123
TutNmi:
    .a8
    .i16
    lda #$17                ; BG1 + BG2 + BG3 + sprites
    sta TM
    lda #$02                ; BG1 na janela 1
    sta W12SEL
    lda #$01
    sta TMW
    stz BG2HOFS
    stz BG2HOFS
    lda #$FF
    sta BG2VOFS
    lda #$03
    sta BG2VOFS
    ; canal 6: WH0/WH1 por linha
    lda #$01
    sta $4360
    lda #<WH0
    sta $4361
    ldx #.loword(TutWinTab)
    stx $4362
    lda #^TutWinTab
    sta $4364
    ; canal 7: CGADSUB por linha (BG3 escurecido fora do balao)
    stz $4370
    lda #<CGADSUB
    sta $4371
    ldx #.loword(TutMathTab)
    stx $4372
    lda #^TutMathTab
    sta $4374
    lda #(VRAM_BG2MAP >> 8) ; mapa do balao (a ajuda usa os seus)
    sta BG2SC
    lda dim_on
    cmp #3
    bne :+
    jsl AjudaNmi            ; ajuda da pausa: balao grande (outras tabelas e mapa)
:   lda #$C0
    sta HDMAEN
    rts

TutWinTab:
    .byte TUT_Y0, 255, 0
    .byte TUT_H, TUT_X0, TUT_X1
    .byte 1, 255, 0
    .byte 0
TutMathTab:
    .byte TUT_Y0, $B5      ; subtrai em BG1, BG3, sprites e fundo
    .byte TUT_H, $B1       ; no balao: o texto (BG3) fica aceso
    .byte 1, $B5
    .byte 0

; com o balao aberto, os sprites do jogo que encostam na area do balao somem: os
; de dentro ja ficariam cobertos, e qualquer um nessas linhas conta no limite de
; sprites por linha do SNES (32 sprites / 34 tiles), cortando botoes e pilula.
; Os outros descem para a prioridade 2 (atras do balao, BG2 com prioridade alta).
; Botoes e pilula seguem na frente.
TutSprites:
    .a8
    .i16
    lda dim_on
    cmp #2
    bcs :+
    rts
:   ldx #0
@l: cpx oam_idx            ; so os sprites que a tela usou
    bcs @r
    lda dim_on              ; ajuda (3): o balao cobre a tela, todos somem
    cmp #3
    beq @some
    ; encosta no balao? (supondo 16x16: linhas y..y+15, colunas x..x+15)
    lda oam_buf+1,x
    cmp #(TUT_Y0-15)
    bcc @atras
    cmp #(TUT_Y0+TUT_H)
    bcs @atras
    lda oam_buf,x
    cmp #(TUT_X0-15)
    bcc @atras
    cmp #(TUT_X1+1)
    bcs @atras
@some:
    lda #$F0
    sta oam_buf+1,x
    bra @nx
@atras:
    lda oam_buf+3,x
    and #$EF
    sta oam_buf+3,x
@nx:
    inx
    inx
    inx
    inx
    bra @l
@r: lda d_paused            ; pausa: icones dos itens por cima do balao
    beq :+
    jmp PauseSprites
:   rts
