; Rotinas no banco 28 (o banco 0 esta cheio). Chamadas com JSL e voltam com RTL;
; rotinas do banco 0 sao chamadas com FAR0 (macros.inc).
.segment "BANK28"

; ---------------------------------------------------------------- impedimentos do dia
; Chamado no inicio de PreDayInit. C=1 se o dia nao pode comecar: ja preparou a
; carta de aviso (e o proximo estado). Hoje o unico impedimento e ficar sem estoque.
DiaBloqueado:
    .a8
    .i16
    lda s_tflags
    and #VENTO_BIT          ; pastel de vento nao gasta estoque
    bne @livre
    A16
    lda s_stock
    A8
    bne @livre
    FAR0 CardReset
    ; sem dinheiro nem para o estoque: o mestre da 10 porcoes e o dia segue
    A16
    lda s_money+2
    bne @compra
    lda s_money
    cmp #30
    bcs @compra
    lda #10
    sta s_stock
    A8
    lda #CARD_FALIU
    FAR0 CardAdd
    lda #ST_PREDAY
    bra @vai
@compra:
    ; da para comprar: aviso com {A} loja / {B} menu
    A8
    lda #CARD_SEMESTOQUE
    FAR0 CardAdd
    lda #ST_SHOP
@vai:
    FAR0 CardGo
    sec
    rtl
@livre:
    clc
    rtl

; A = carta mostrada agora
CartaAtual:
    .a8
    .i16
    A16
    lda card_i
    and #$00FF
    tax
    A8
    lda card_q,x
    rts

; {B} na carta de falta de estoque: volta ao menu principal
CardBotaoB:
    .a8
    .i16
    lda pad_new+1
    and #KH_B
    beq @r
    jsr CartaAtual
    cmp #CARD_SEMESTOQUE
    bne @r
    lda #SFX_CURSOR
    FAR0 PlaySfx
    lda #ST_TITLE
    sta next_state
    ldx #0                  ; {A} no mesmo quadro nao desfaz a escolha
    stx pad_new
@r: rtl

; rodape da carta: a de falta de estoque mostra as duas saidas
CardRodape:
    .a8
    .i16
    jsr CartaAtual
    ldx #TXT_C_A
    cmp #CARD_SEMESTOQUE
    bne :+
    ldx #TXT_C_LOJA
:   lda #26
    FAR0 Footer
    rtl

; ---------------------------------------------------------------- fim do dia (resultado)
; Pagina 1 do resultado: um icone emoji no lugar de cada rotulo (folha
; gen/icon_res_*, carregada nos tiles OBJ 0-95 como os icones da loja).
; Coluna da esquerda: entradas (verde); da direita: saidas (vermelho).
; Icones centrados na linha do texto (y = linha*8 - 4), como na loja.
ICR_DIA    = 0              ; ordem de ICONES_RES em gerador/icones.py
ICR_CLI    = 1
ICR_PERF   = 2
ICR_LIXO   = 3
ICR_ENTR   = 4
ICR_VEND   = 5
ICR_GORJ   = 6
ICR_UNID   = 7
ICR_ALUG   = 8
ICR_SAL    = 9
ICR_LUCRO  = 10
ICR_PREJ   = 11
ICR_CAIXA  = 12
ICR_REP    = 13
ICR_NIVEL  = 14
ICR_XP     = 15
ICR_SUBIU  = 16
ICR_DESAF  = 17
ICR_FALHOU = 18
ICR_MISSAO = 19
ICR_GRAF   = 20
ICR_MELHOR = 21
RES_XE = 20                 ; x do icone da coluna esquerda (texto na coluna 5)
RES_XD = 124                ; x do icone da coluna direita (texto na coluna 18)

; posicao e paleta do proximo texto (TxtEsq/NumEsq avancam a posicao)
.macro RPOS col, row, pal
    ldx #((row)*32+(col))
    stx txt_pos
    lda #(((pal)<<2)|$20)
    sta txt_attr
.endmacro
.macro RTXT str
    ldx #str
    jsr TxtEsq
.endmacro
.macro RNUM8 var
    A16
    lda var
    and #$00FF
    sta num
    stz num+2
    A8
    jsr NumEsq
.endmacro
.macro RNUM16 var
    A16
    lda var
    sta num
    stz num+2
    A8
    jsr NumEsq
.endmacro
.macro RICO ico, xx, row
    lda #ico
    ldx #xx
    ldy #((row)*8-4)
    jsr IcoRes
.endmacro

DrawResults:
    .a8
    .i16
    ; folha de icones do resultado (a tela esta desligada)
    ldx #VRAM_OBJ
    stx VMADDL
    ldx #.loword(IconResGfx)
    stx dma_src
    lda #^IconResGfx
    sta dma_src+2
    ldx #(IconResGfx_end - IconResGfx)
    stx dma_len
    FAR0 DmaVram
    ldx #.loword(IconResPal)
    stx dma_src
    lda #^IconResPal
    sta dma_src+2
    ldx #(176*2)            ; paletas OBJ 3..6
    ldy #128
    FAR0 CopyPal
    FAR0 OamClear
    ; titulo
    RICO ICR_DIA, RES_XE, 3
    RPOS 5, 3, 5
    RTXT TXT_R_FIM
    RNUM16 s_day
    ; o dia: clientes, perfeitos, desperdicio e entregas
    RICO ICR_CLI, RES_XE, 6
    RPOS 5, 6, 4
    RNUM8 d_served
    RTXT TXT_HUD_BAR
    RNUM8 d_total
    RICO ICR_PERF, RES_XD, 6
    RPOS 18, 6, 4
    RNUM8 d_perfect
    RICO ICR_LIXO, RES_XE, 8
    RPOS 5, 8, 4
    RNUM8 d_waste
    lda s_level
    cmp #TEL_LV
    bcc @noent
    RICO ICR_ENTR, RES_XD, 8
    RPOS 18, 8, 7
    RNUM8 d_deliv
    RTXT TXT_R_ENTR
    RNUM16 d_dvsales
@noent:
    ; entradas
    RICO ICR_VEND, RES_XE, 11
    RPOS 5, 11, 6
    RTXT TXT_R_MAIS
    RNUM16 d_sales
    RICO ICR_GORJ, RES_XE, 13
    RPOS 5, 13, 6
    RTXT TXT_R_MAIS
    RNUM16 d_tips
    A16
    lda r_other             ; sem outras lojas/franquias: nem mostra
    A8
    beq @nooutr
    RICO ICR_UNID, RES_XE, 15
    RPOS 5, 15, 6
    RTXT TXT_R_MAIS
    RNUM16 r_other
@nooutr:
    ; saidas
    RICO ICR_ALUG, RES_XD, 11
    RPOS 18, 11, 5
    RTXT TXT_R_MENOS
    RNUM16 r_rent
    A16
    lda r_salary            ; sem atendente nem motoboy: nem mostra
    A8
    beq @nosal
    RICO ICR_SAL, RES_XD, 13
    RPOS 18, 13, 5
    RTXT TXT_R_MENOS
    RNUM16 r_salary
@nosal:
    ; lucro ou prejuizo do dia e caixa
    A16
    lda r_profit
    bmi @neg
    A8
    RICO ICR_LUCRO, RES_XE, 18
    RPOS 5, 18, 6
    RTXT TXT_R_MAIS
    bra @lucro
@neg:
    .a16
    eor #$FFFF
    inc a
    sta r_profit
    A8
    RICO ICR_PREJ, RES_XE, 18
    RPOS 5, 18, 5
    RTXT TXT_R_MENOS
@lucro:
    RNUM16 r_profit
    RICO ICR_CAIXA, RES_XD, 18
    RPOS 18, 18, 7
    RTXT TXT_R_RS
    A16
    lda s_money
    sta num
    lda s_money+2
    sta num+2
    A8
    jsr NumEsq
    ; reputacao, nivel (confete se subiu) e experiencia
    RICO ICR_REP, RES_XE, 20
    RPOS 5, 20, 4
    RNUM8 s_rep
    RTXT TXT_R_100
    RICO ICR_NIVEL, RES_XD, 20
    lda r_levels
    beq @nv
    RPOS 18, 20, 6
    RNUM8 s_level
    RICO ICR_SUBIU, 164, 20  ; ao lado do numero (ate 2 digitos)
    bra @xp
@nv:
    RPOS 18, 20, 4
    RNUM8 s_level
@xp:
    RICO ICR_XP, RES_XE, 22
    RPOS 5, 22, 4
    RNUM16 s_xp
    RTXT TXT_HUD_BAR
    FAR0 XpNeed
    RNUM16 tmp
    ; desafio do dia (chefe ou duelo)
    lda r_bossres
    bne :+
    lda r_duel
    beq @nob
:   cmp #1
    bne @falhou
    RICO ICR_DESAF, RES_XD, 22
    RPOS 18, 22, 6
    RTXT TXT_R_META_OK
    bra @nob
@falhou:
    RICO ICR_FALHOU, RES_XD, 22
    RPOS 18, 22, 5
    RTXT TXT_R_META_NO
@nob:
    ; missao atual (ate 24 letras: build.js confere)
    RICO ICR_MISSAO, RES_XE, 24
    RPOS 5, 24, 6
    A16
    lda s_mission
    and #$00FF
    asl a
    tax
    lda MissionTxt,x
    tax
    A8
    jsr TxtEsq
    ldx #TXT_R_CONT
    lda #26
    FAR0 Footer
    rtl

; X = texto (banco 0): imprime em txt_pos/txt_attr e avanca txt_pos
TxtEsq:
    .a8
    .i16
    FAR0 PrintStr
    A16
    txa                     ; PrintStr termina com X = 2 * proxima posicao
    lsr a
    sta txt_pos
    A8
    rts

; num (32 bits) alinhado a esquerda (sem espacos) em txt_pos; avanca txt_pos
NumEsq:
    .a8
    .i16
    FAR0 NumConv
    ldx #0
@z: lda numdig,x            ; pula os zeros a esquerda (fica ao menos um digito)
    bne @c
    cpx #7
    beq @c
    inx
    bra @z
@c: ldy #0
@cp:
    lda numdig,x
    clc
    adc #FONT_0
    sta numstr,y
    iny
    inx
    cpx #8
    bne @cp
    lda #$FF
    sta numstr,y
    ldx #numstr
    bra TxtEsq

; icone A da folha do resultado em (X, Y)
IcoRes:
    .a8
    .i16
    stx spr_x
    pha
    tya
    sta spr_y
    pla
    A16
    and #$00FF
    tax
    A8
    lda f:IconResPalTab,x
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
    lda #1
    sta spr_size
    FAR0 AddSprite
    stz spr_size
    rts

; ---------------------------------------------------------------- grafico de lucro (resultado)
DrawChart:
    .a8
    .i16
    FAR0 ClearBg3
    FAR0 OamClear
    RICO ICR_GRAF, RES_XE, 3
    PRINT0 TXT_G_TIT, 5, 3, 5
    lda hist_n
    bne :+
    PRINT0 TXT_G_VAZIO, 3, 10, 4
    jmp @foot
:   ; maior valor absoluto -> passo = max/8 (minimo 1)
    ldx #0
    stx tmp2
    stx tmp4
@mx:
    A16
    lda hist,x
    bpl :+
    eor #$FFFF
    inc a
:   cmp tmp2
    bcc :+
    sta tmp2
:   A8
    inx
    inx
    cpx #14
    bne @mx
    A16
    lda tmp2
    lsr a
    lsr a
    lsr a
    bne :+
    lda #1
:   sta tmp2            ; passo
    lda #0
    sta tmp4            ; melhor dia
    A8
    ; barras: entradas 7-n..6
    lda #7
    sec
    sbc hist_n
    sta loop_i
@bar:
    lda loop_i
    cmp #7
    bcc :+
    jmp @foot
:   A16
    and #$00FF
    asl a
    tax
    lda hist,x
    sta tmp3
    bmi :+
    cmp tmp4
    bcc :+
    sta tmp4
:   ; altura = |v| / passo
    lda tmp3
    bpl :+
    eor #$FFFF
    inc a
:   ldy #0
@dv:
    cmp tmp2
    bcc @dvd
    sec
    sbc tmp2
    iny
    cpy #8
    bne @dv
@dvd:
    A8
    ; coluna = 4 + 3*(i - (7-n))
    lda #7
    sec
    sbc hist_n
    sta num_pad
    lda loop_i
    sec
    sbc num_pad
    stz num_pad
    sta num            ; k
    asl a
    clc
    adc num
    clc
    adc #4
    sta num            ; coluna
    lda tmp3+1
    bmi @neg
    ; positiva: linhas 16, 15, ... para cima
    lda #16
    sta num+1
@pl:
    cpy #0
    beq @lbl
    jsr ChartCell6
    dec num+1
    dey
    bra @pl
@neg:
    cpy #5
    bcc :+
    ldy #4
:   lda #17
    sta num+1
@nl:
    cpy #0
    beq @lbl
    jsr ChartCell5
    inc num+1
    dey
    bra @nl
@lbl:
    ; numero do dia embaixo (linha 22)
    lda num
    sta num_w+1
    A16
    lda s_day
    sec
    sbc #7
    sta num+2
    lda loop_i
    and #$00FF
    clc
    adc num+2
    sta num+2
    A8
    lda num_w+1
    A16
    and #$00FF
    clc
    adc #(22*32-1)          ; campo de 3 a partir da coluna antes da barra: o numero fica embaixo dela
    sta txt_pos
    lda num+2
    sta num
    stz num+2
    A8
    lda #((4<<2)|$20)
    sta txt_attr
    lda #3
    sta num_w
    A16
    lda tmp2                ; o passo: PrintStr usa tmp2
    pha
    A8
    FAR0 PrintNum
    A16
    pla
    sta tmp2
    A8
    inc loop_i
    jmp @bar
@foot:
    ; melhor dia
    RICO ICR_MELHOR, RES_XE, 24
    RPOS 5, 24, 6
    RTXT TXT_R_RS
    RNUM16 tmp4
    ldx #TXT_R_CONT
    lda #26
    FAR0 Footer
    rtl

; bloco cheio na coluna num (2 tiles) e linha num+1: paleta 6 (verde) / 5 (vermelho)
ChartCell6:
    .a8
    .i16
    lda #((6<<2)|$20)
    bra ChartCell
ChartCell5:
    .a8
    .i16
    lda #((5<<2)|$20)
ChartCell:
    sta txt_attr
    phy
    A16
    lda num+1
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    sta txt_pos
    lda num
    and #$00FF
    clc
    adc txt_pos
    asl a
    tax
    A8
    lda #FONT_BOX
    sta bg3_buf,x
    sta bg3_buf+2,x
    lda txt_attr
    sta bg3_buf+1,x
    sta bg3_buf+3,x
    lda #1
    sta bg3_dirty
    ply
    rts


; ---------------------------------------------------------------- mao do jogador
; Ao lado do cursor: mao (emoji) com o que o jogador segura em cima dos dedos
; (sabor 8x8 do pastel pronto e/ou a latinha do combo). Mao vazia nao mostra nada.
; Chamado por DayDraw logo depois do cursor: spr_x/spr_y ainda sao os do cursor
; (com a balancada), entao a mao acompanha o movimento. Termina com spr_size = 1.
MAO_DX = 11                 ; canto da mao em relacao ao cursor
MAO_DY = 3
MaoSprites:
    .a8
    .i16
    lda hold_flav
    cmp #$FF
    bne @tem
    lda hold_soda
    bne @tem
    rtl
@tem:
    A16
    lda spr_x
    clc
    adc #MAO_DX
    sta spr_x
    A8
    lda spr_y
    clc
    adc #MAO_DY
    sta spr_y
    lda #$30
    sta spr_attr
    stz spr_size
    ; itens antes da mao (slot menor fica na frente)
    lda hold_flav
    cmp #$FF
    beq @soda
    clc
    adc #<SPR_MINI
    sta spr_tile
    lda #>SPR_MINI
    adc #0
    sta spr_tile+1
    lda #7                  ; sabor sobre as pontas dos dedos
    ldy #$FFFB
    jsr MaoItem
@soda:
    lda hold_soda
    beq @mao
    A16
    lda #SPR_REFRI_P
    sta spr_tile
    A8
    lda #1                  ; latinha sobre o polegar
    ldy #$FFFC
    jsr MaoItem
@mao:
    A16
    lda #SPR_MAO
    sta spr_tile
    A8
    lda #1
    sta spr_size
    FAR0 AddSprite
    rtl

; sprite 8x8 em (mao + A, mao + Y), sem mexer na posicao da mao
MaoItem:
    .a8
    .i16
    sta tmp
    A16
    lda spr_x
    pha
    lda tmp
    and #$00FF
    clc
    adc spr_x
    sta spr_x
    A8
    lda spr_y
    pha
    tya
    clc
    adc spr_y
    sta spr_y
    FAR0 AddSprite
    pla
    sta spr_y
    A16
    pla
    sta spr_x
    A8
    rts

; folha de icones da tela de fim do dia (gerador/icones.py, ICONES_RES)
IconResGfx: .incbin "gen/icon_res_tiles.bin"
IconResGfx_end:
IconResPal: .incbin "gen/icon_res_pal.bin"
.include "gen/icon_res_pal.inc"

; ---------------------------------------------------------------- mapa da expansao
; Com a tela desligada (VMAIN = $80): escreve no mapa do BG1 o retangulo de cada
; unidade ja comprada (lojas 1..s_stores e franquias 1..s_fran) por cima do
; terreno em obra / da placa de venda. Dados: gen/map_obras.inc (gerador/mapa.js)
MapObras:
    .a8
    .i16
    ldy #0
@u: tya
    cmp #4
    bcs @fr
    cmp s_stores
    bcs @nx
    bra @ap
@fr:
    sec
    sbc #4
    cmp s_fran
    bcs @nx
@ap:
    phy
    A16
    tya
    asl a
    tax
    lda f:MapObraPtr,x
    tax
    lda f:MapObraDados,x    ; endereco do canto na VRAM
    sta tmp
    lda f:MapObraDados+2,x  ; largura, altura
    sta tmp2
    inx
    inx
    inx
    inx
    A8
@lin:
    ldy tmp
    sty VMADDL
    lda tmp2
    sta tmp3
@col:
    lda f:MapObraDados,x
    sta $2118
    lda f:MapObraDados+1,x
    sta $2119
    inx
    inx
    dec tmp3
    bne @col
    A16
    lda tmp
    clc
    adc #32
    sta tmp
    A8
    dec tmp2+1
    bne @lin
    ply
@nx:
    iny
    cpy #MAP_OBRAS_N
    bne @u
    rtl

; agua do mapa correndo: a cada 16 quadros troca as cores dos dois brilhos
; (cores 9 e 11 da paleta BG 2)
MapAgua:
    .a8
    .i16
    lda frame
    and #$0F
    bne @r
    A16
    lda cgram_buf+(41*2)
    pha
    lda cgram_buf+(43*2)
    sta cgram_buf+(41*2)
    pla
    sta cgram_buf+(43*2)
    A8
    lda #1
    sta pal_dirty
@r: rtl

.include "gen/map_obras.inc"

; ---------------------------------------------------------------- ajuda da pausa
; Opcao AJUDA da pausa: balao grande (BG2, mapas fixos na VRAM carregados com o
; cenario) com abas (L/R) e paginas (cima/baixo ou A). A aba CONTROLES mostra o
; controle do Super Famicom desenhado no BG2 (paleta 4); a NMI troca o BG2SC (aj_sc).
; Textos e tabelas em gen/ajuda.inc (banco 11, gerador/ajuda.js).
AJ_LINABA = 5               ; barra de abas
AJ_LINTIT = 7               ; nome da aba e numero da pagina
AJ_LIN0   = 9               ; primeira linha do texto (13 linhas)
AJ_LINROD = 23              ; rodape (pilula na borda de baixo)
AJ_ICO_Y  = AJ_LINABA*8 - 4

; com o cenario do expediente (tela desligada): tiles, os dois mapas e a paleta 4
AjudaCarrega:
    .a8
    .i16
    ldx #AJ_VRAM
    stx VMADDL
    ldx #.loword(AjTiles)
    stx dma_src
    lda #^AjTiles
    sta dma_src+2
    ldx #(AjTiles_end - AjTiles)
    stx dma_len
    FAR0 DmaVram
    ldx #AJ_MAPA_VRAM
    stx VMADDL
    ldx #.loword(AjMapA)
    stx dma_src
    lda #^AjMapA
    sta dma_src+2
    ldx #2048
    stx dma_len
    FAR0 DmaVram
    ldx #AJ_MAPB_VRAM
    stx VMADDL
    ldx #.loword(AjMapB)
    stx dma_src
    lda #^AjMapB
    sta dma_src+2
    ldx #2048
    stx dma_len
    FAR0 DmaVram
    ldx #.loword(AjPal)
    stx dma_src
    lda #^AjPal
    sta dma_src+2
    ldx #(64*2)
    ldy #32
    FAR0 CopyPal
    rtl

; NMI com dim_on = 3 (chamada pelo TutNmi): janela e escurecimento do balao grande
AjudaNmi:
    .a8
    .i16
    ldx #.loword(AjWinTab)
    stx $4362
    lda #^AjWinTab
    sta $4364
    ldx #.loword(AjMathTab)
    stx $4372
    lda #^AjMathTab
    sta $4374
    lda aj_sc
    sta BG2SC
    rtl
; HDMA: contagem ate 127 por bloco (bit 7 seria o modo repetido)
AjWinTab:
    .byte AJ_Y0, 255, 0
    .byte 127, AJ_X0, AJ_X1
    .byte AJ_H-127, AJ_X0, AJ_X1
    .byte 1, 255, 0
    .byte 0
AjMathTab:
    .byte AJ_Y0, $B5
    .byte 127, $B1
    .byte AJ_H-127, $B1
    .byte 1, $B5
    .byte 0

; AJUDA escolhida na pausa
AjudaAbre:
    .a8
    .i16
    lda #1
    sta aj_on
    lda #3
    sta dim_on
    stz aj_aba
    stz aj_pag
    lda #SFX_OK
    FAR0 PlaySfx
    jsr AjudaDraw
    rtl

; volta para a pausa
AjudaFecha:
    .a8
    .i16
    stz aj_on
    lda #2
    sta dim_on
    jsr AjLimpa
    lda #SFX_CURSOR
    FAR0 PlaySfx
    FAR0 PauseDraw
    rts

; apaga as linhas da ajuda (4..23)
AjLimpa:
    .a8
    .i16
    lda #4
@l: pha
    FAR0 ClearRow
    pla
    inc a
    cmp #(AJ_LINROD+1)
    bne @l
    rts

; A = indice da pagina atual (AjPagIni[aba] + pagina)
AjPagina:
    .a8
    .i16
    A16
    lda aj_aba
    and #$00FF
    tax
    A8
    lda f:AjPagIni,x
    clc
    adc aj_pag
    rts

; A = numero de paginas da aba atual
AjNPag:
    .a8
    .i16
    A16
    lda aj_aba
    and #$00FF
    tax
    A8
    lda f:AjPagIni+1,x
    sec
    sbc f:AjPagIni,x
    rts

AjudaDraw:
    .a8
    .i16
    jsr AjLimpa
    PRINT0 TXT_SH_L, 2, AJ_LINABA, 4
    PRINT0 TXT_SH_R, 29, AJ_LINABA, 4
    ; nome da aba
    A16
    lda aj_aba
    and #$00FF
    asl a
    tax
    lda f:AjNome,x
    tax
    A8
    ldy #(AJ_LINTIT*32+3)
    sty txt_pos
    lda #((5<<2)|$20)
    sta txt_attr
    lda #^AjNome
    FAR0 PrintStrB
    ; "1/3" e o texto da pagina
    jsr AjPagina
    A16
    and #$00FF
    pha
    asl a
    tax
    lda f:AjPagNum,x
    tax
    A8
    ldy #(AJ_LINTIT*32+26)
    sty txt_pos
    lda #((4<<2)|$20)
    sta txt_attr
    lda #^AjPagNum
    FAR0 PrintStrB
    A16
    lda 1,s
    asl a
    tax
    lda f:AjPagTxt,x
    tax
    A8
    ldy #(AJ_LIN0*32+3)
    sty txt_pos
    lda #^AjPagTxt
    FAR0 PrintStrB
    ; BG2: mapa com o desenho do controle ou so o balao
    A16
    pla
    tax
    A8
    lda f:AjPagDes,x
    beq :+
    lda #AJ_SC_A
    bra :++
:   lda #AJ_SC_B
:   sta aj_sc
    ; rodape: com mais de uma pagina, diz como trocar
    jsr AjNPag
    cmp #2
    ldx #TXT_AJ_ROD0
    bcc :+
    ldx #TXT_AJ_ROD1
:   lda #AJ_LINROD
    FAR0 Footer
    rts

; um quadro com a ajuda aberta (chamada pelo PauseMenu)
AjudaUpdate:
    .a8
    .i16
    lda pad_new+1
    and #(KH_B|KH_START)
    beq @nb
    jsr AjudaFecha
    rtl
@nb:
    ; L ou esquerda: aba anterior; R ou direita: proxima (dao a volta)
    lda pad_new
    and #KL_L
    bne @al
    lda pad_new+1
    and #KH_LEFT
    beq @nl
@al:
    lda aj_aba
    dec a
    bpl @aba
    lda #(AJ_ABAS-1)
    bra @aba
@nl:
    lda pad_new
    and #KL_R
    bne @ar
    lda pad_new+1
    and #KH_RIGHT
    beq @nr
@ar:
    lda aj_aba
    inc a
    cmp #AJ_ABAS
    bcc @aba
    lda #0
@aba:
    sta aj_aba
    stz aj_pag
    bra @muda
@nr:
    ; cima: pagina anterior; baixo ou A: proxima (dao a volta)
    jsr AjNPag
    sta tmp
    cmp #2
    bcc @r
    lda pad_new+1
    and #KH_UP
    beq @nu
    lda aj_pag
    dec a
    bpl @pag
    lda tmp
    dec a
    bra @pag
@nu:
    lda pad_new+1
    and #KH_DOWN
    bne @prox
    lda pad_new
    and #KL_A
    beq @r
@prox:
    lda aj_pag
    inc a
    cmp tmp
    bcc @pag
    lda #0
@pag:
    sta aj_pag
@muda:
    lda #SFX_CURSOR
    FAR0 PlaySfx
    jsr AjudaDraw
@r: rtl

; icones das abas, com a pilula atras da escolhida (chamada pelo PauseSprites)
AjudaSprites:
    .a8
    .i16
    lda #0
@l: pha
    A16
    and #$00FF
    asl a
    tax
    lda f:AjIcoX,x
    sta spr_x
    lda f:AjIcoTile,x
    sta spr_tile
    A8
    lda #AJ_ICO_Y
    sta spr_y
    lda 1,s
    cmp aj_aba
    bne :+
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
:   lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    FAR0 AddSprite
    pla
    inc a
    cmp #AJ_ABAS
    bne @l
    ; pilula (2 pecas de 16) centrada no icone escolhido; depois dos icones = atras
    A16
    lda aj_aba
    and #$00FF
    asl a
    tax
    lda f:AjIcoX,x
    sec
    sbc #8
    sta spr_x
    lda #SPR_PILULA_E
    sta spr_tile
    A8
    lda #AJ_ICO_Y
    sta spr_y
    lda #$32
    sta spr_attr
    FAR0 AddSprite
    A16
    lda spr_x
    clc
    adc #16
    sta spr_x
    lda #SPR_PILULA_D
    sta spr_tile
    A8
    FAR0 AddSprite
    stz spr_size
    rtl
AjIcoX:    .word 54, 98, 142, 186
AjIcoTile: .word SPR_AJ_CONTROLE, SPR_AJ_LIVRO, SPR_ESTRELA, SPR_AJ_GRAFICO

; ---------------------------------------------------------------- HUD do expediente
; Pilulas creme no topo (dia, dinheiro, nivel, hora) e painel creme no rodape
; (linha de avisos/missao e linha de numeros), desenhados no cenario por
; gerador/hud.js + arte.js. Aqui ficam o texto (BG3, paletas 4-7) e os emojis.

; parte fixa (DrawHudStatic): ':' da hora
HudFixo:
    .a8
    .i16
    lda #1                  ; o HUD foi redesenhado: os numeros tambem
    sta hud_forca
    PRINT0 TXT_HUD_DP, HUD_HORA_COL+2, HUD_LIN_TOPO, 4
    rtl

; numeros (todo quadro, DrawHud)
.macro HUDNUM8 var, col, lin, pal, larg
    A16
    lda var
    and #$00FF
    sta num
    stz num+2
    A8
    ldx #((lin)*32+(col))
    stx txt_pos
    lda #(((pal)<<2)|$20)
    sta txt_attr
    lda #larg
    jsr HudNum
.endmacro
.macro HUDNUM16 var, col, lin, pal, larg
    A16
    lda var
    sta num
    stz num+2
    A8
    ldx #((lin)*32+(col))
    stx txt_pos
    lda #(((pal)<<2)|$20)
    sta txt_attr
    lda #larg
    jsr HudNum
.endmacro

; o que o HUD mostra (um byte de cada): so reimprime quando algo muda
HudSig:
    .word s_day, s_day+1, s_money, s_money+1, s_money+2, s_money+3, s_level, d_hour
    .word d_min, s_stock, s_stock+1, s_rep, d_perfect, d_happy, d_boss, d_goal, d_event
HUD_SIG_N = 17
; grupo de cada byte (um bit por numero do HUD): dia, dinheiro, nivel, hora, estoque,
; reputacao, meta
HudGrp:
    .word 1, 1, 2, 2, 2, 2, 4, 8
    .word 8, 16, 16, 32, 64, 64, 64, 64, 64

HudValores:
    .a8
    .i16
    ; NumConv e PrintStr a cada quadro pesavam ~25% do quadro no fim do jogo (o tempo
    ; que sobra e o do envio do audio): cada numero so e reimpresso quando o valor
    ; dele muda, e todos a cada 32 quadros
    stz hud_muda
    ldx #0
@cmp:
    A16
    lda f:HudSig,x
    tay
    A8
    lda a:0,y
    cmp hud_ant,x
    beq :+
    sta hud_ant,x
    lda f:HudGrp,x
    tsb hud_muda
:   inx
    inx
    cpx #(HUD_SIG_N*2)
    bne @cmp
    lda hud_forca
    bne @tudo
    lda frame
    and #$1F
    bne :+
@tudo:
    stz hud_forca
    lda #$7F
    sta hud_muda
:   lda hud_muda
    bne @dia
    rtl
@dia:
    lda hud_muda
    and #1
    beq @din
    HUDNUM16 s_day, HUD_DIA_COL, HUD_LIN_TOPO, 4, HUD_DIA_W
@din:
    lda hud_muda
    and #2
    beq @niv
    A16
    lda s_money
    sta num
    lda s_money+2
    sta num+2
    A8
    ldx #(HUD_LIN_TOPO*32+HUD_RS_COL)
    stx txt_pos
    lda #((6<<2)|$20)
    sta txt_attr
    lda #HUD_RS_W
    jsr HudNum
@niv:
    lda hud_muda
    and #4
    beq @hora
    HUDNUM8 s_level, HUD_NV_COL, HUD_LIN_TOPO, 5, HUD_NV_W
@hora:
    lda hud_muda
    and #8
    beq @est
    ; hora: hh (com espaco) e mm (com zero)
    A16
    lda d_hour
    and #$00FF
    sta num
    stz num+2
    A8
    ldx #(HUD_LIN_TOPO*32+HUD_HORA_COL)
    stx txt_pos
    lda #((4<<2)|$20)
    sta txt_attr
    lda #2
    sta num_w
    FAR0 PrintNum
    A16
    lda d_min
    and #$00FF
    sta num
    A8
    ldx #(HUD_LIN_TOPO*32+HUD_HORA_COL+3)
    stx txt_pos
    lda #2
    sta num_w
    lda #FONT_0
    sta num_pad
    FAR0 PrintNum
@est:
    lda hud_muda
    and #16
    beq @rep
    HUDNUM16 s_stock, HUD_EST_COL, HUD_LIN_NUM, 4, HUD_EST_W
@rep:
    lda hud_muda
    and #32
    beq @meta
    HUDNUM8 s_rep, HUD_REP_COL, HUD_LIN_NUM, 4, HUD_REP_W
@meta:
    lda hud_muda
    and #64
    beq @r
    ; meta: perfeitos (desafio do sabor) ou satisfeitos, alinhado a direita do '/'
    FAR0 HasGoal
    bcc @r
    lda d_boss
    cmp #1
    bne :+
    lda d_perfect
    bra :++
:   lda d_happy
:   A16
    and #$00FF
    sta num
    stz num+2
    A8
    ldx #(HUD_LIN_NUM*32+HUD_META_COL)
    stx txt_pos
    lda #((6<<2)|$20)
    sta txt_attr
    lda #2
    sta num_w
    FAR0 PrintNum
    PRINT0 TXT_HUD_BAR, HUD_META_COL+2, HUD_LIN_NUM, 6
    HUDNUM8 d_goal, HUD_META_COL+3, HUD_LIN_NUM, 6, 2
@r: rtl

; num (32 bits) alinhado a esquerda em txt_pos/txt_attr, completado com espacos
; ate A casas (apaga os digitos que sobram quando o numero encolhe)
HudNum:
    .a8
    .i16
    sta hud_w
    FAR0 NumConv
    ldx #0
@z: lda numdig,x            ; pula os zeros a esquerda (fica ao menos um digito)
    bne @c
    cpx #7
    beq @c
    inx
    bra @z
@c: ldy #0
@cp:
    lda numdig,x
    clc
    adc #FONT_0
    sta numstr,y
    iny
    inx
    cpx #8
    bne @cp
@sp:
    tya
    cmp hud_w
    bcs @fim
    lda #FONT_SPACE
    sta numstr,y
    iny
    bra @sp
@fim:
    lda #$FF
    sta numstr,y
    ldx #numstr
    FAR0 PrintStr
    rts

; emojis do HUD: 16x16 na ponta de cada pilula do topo; 8x8 no rodape (estoque,
; reputacao, meta e a estrela da missao)
HudSprites:
    .a8
    .i16
    lda #$30                ; prioridade 3, paleta 0
    sta spr_attr
    lda #1
    sta spr_size
    lda #HUD_ICO_Y
    sta spr_y
    ldx #0
@t: phx
    A16
    lda f:HudIcoX,x
    sta spr_x
    lda f:HudIcoTile,x
    sta spr_tile
    A8
    FAR0 AddSprite
    plx
    inx
    inx
    cpx #8
    bne @t
    stz spr_size
    lda #(HUD_LIN_NUM*8)
    sta spr_y
    A16
    lda #((HUD_EST_COL-1)*8)
    sta spr_x
    lda #SPR_MINI_CAIXA
    sta spr_tile
    A8
    FAR0 AddSprite
    A16
    lda #((HUD_REP_COL-1)*8)
    sta spr_x
    lda #SPR_MINI_CORACAO
    sta spr_tile
    A8
    FAR0 AddSprite
    FAR0 HasGoal
    bcc :+
    A16
    lda #((HUD_META_COL-1)*8)
    sta spr_x
    lda #SPR_MINI_ALVO
    sta spr_tile
    A8
    FAR0 AddSprite
:   lda hud_mis
    beq @r
    lda #(HUD_LIN_MSG*8)
    sta spr_y
    A16
    lda #8
    sta spr_x
    lda #SPR_MINI_ESTRELA
    sta spr_tile
    A8
    FAR0 AddSprite
@r: rtl
HudIcoX:    .word HUD_DIA_ICOX, HUD_RS_ICOX, HUD_NV_ICOX, HUD_HORA_ICOX
HudIcoTile: .word SPR_CALENDARIO, SPR_MOEDA, SPR_ESTRELA, SPR_RELOGIO

; ---------------------------------------------------------------- animacoes grandes (BG2)
; Player generico das animacoes grandes do expediente (gerador/anim.js): um cartao
; creme no BG2 (mapa ANIM_MAPA_VRAM, paleta 5, prioridade alta) cujo miolo (8x6
; tiles) recebe o quadro atual pela NMI (AnimDma) so quando ele muda. Uso:
;   lda #quadro : jsl AnimMostra   mostra o cartao ja nesse quadro (indice global)
;   lda #quadro : jsl AnimVai      anda ate esse quadro (para frente ou para tras)
;   lda #n      : jsl AnimSome     some n quadros de video depois de chegar ao alvo
;   jsl AnimEsconde                some ja
; Os quadros de uma animacao vao de ANIM_<NOME> a ANIM_<NOME>+ANIM_<NOME>_N-1;
; Anim<Nome>Chaves tem os quadros-chave (relativos). AnimSprites (fim do DayDraw)
; anda a animacao e poe atras do cartao os sprites que encostam nele.
ANIM_VEL = 3                ; quadros de video por quadro de animacao

; com o cenario do expediente (tela desligada): borda do cartao, mapa e paleta 5
AnimCarrega:
    .a8
    .i16
    stz anim_vis
    stz anim_sujo
    ldx #ANIM_VRAM
    stx VMADDL
    ldx #.loword(AnimBorda)
    stx dma_src
    lda #^AnimBorda
    sta dma_src+2
    ldx #ANIM_BORDA_BYTES
    stx dma_len
    FAR0 DmaVram
    ldx #ANIM_MAPA_VRAM
    stx VMADDL
    ldx #.loword(AnimMapa)
    stx dma_src
    lda #^AnimMapa
    sta dma_src+2
    ldx #2048
    stx dma_len
    FAR0 DmaVram
    ldx #.loword(AnimPal)
    stx dma_src
    lda #^AnimPal
    sta dma_src+2
    ldx #(80*2)
    ldy #32
    FAR0 CopyPal
    rtl

AnimMostra:
    .a8
    .i16
    sta anim_cur
    sta anim_tgt
    lda #1
    sta anim_vis
    sta anim_sujo
    stz anim_ok
    stz anim_fim
    lda #ANIM_VEL
    sta anim_t
    rtl

AnimVai:
    .a8
    .i16
    sta anim_tgt
    rtl

AnimSome:
    .a8
    .i16
    sta anim_fim
    rtl

AnimEsconde:
    .a8
    .i16
    lda anim_vis
    beq :+
    lda #2
    sta anim_vis
:   rtl

; um quadro do expediente (chamada no fim do DayDraw): anda a animacao, poe atras
; do cartao (prioridade 2; o BG2 de prioridade alta fica na frente) os sprites que
; encostam nele e desenha os extras da animacao (o recheio da montagem)
AnimSprites:
    .a8
    .i16
    lda anim_vis
    cmp #1
    beq :+
    rtl
:   lda dim_on              ; pausa/tutorial aberto: a animacao espera
    bne @spr
    lda anim_sujo           ; espera a NMI mandar o quadro anterior
    bne @spr
    lda anim_cur
    cmp anim_tgt
    beq @parado
    dec anim_t
    bne @spr
    lda #ANIM_VEL
    sta anim_t
    lda anim_cur
    cmp anim_tgt
    bcc :+
    dec a
    dec a
:   inc a
    sta anim_cur
    lda #1
    sta anim_sujo
    bra @spr
@parado:
    lda anim_fim
    beq @spr
    dec anim_fim
    bne @spr
    lda #2
    sta anim_vis
    rtl
@spr:
    lda anim_ok
    bne :+
    rtl
:   ldx #0
@l: cpx oam_idx
    bcs @extra
    ; encosta no cartao? (supondo 16x16: linhas y..y+15, colunas x..x+15)
    lda oam_buf+1,x
    cmp #(ANIM_Y0-15)
    bcc @nx
    cmp #(ANIM_Y1+1)
    bcs @nx
    lda oam_buf,x
    cmp #(ANIM_X0-15)
    bcc @nx
    cmp #(ANIM_X1+1)
    bcs @nx
    lda oam_buf+3,x
    and #$CF
    ora #$20
    sta oam_buf+3,x
@nx:
    inx
    inx
    inx
    inx
    bra @l
@extra:
    jmp MgaSprites

; NMI, no envio (nmi_ready): tiles do quadro atual para o miolo do cartao
AnimDma:
    .a8
    .i16
    lda #$80
    sta VMAIN
    ldx #ANIM_SLOT_VRAM
    stx VMADDL
    lda #$01
    sta $4300
    lda #$18
    sta $4301
    A16
    lda anim_cur            ; x = quadro * 3 (na NMI nada de tmp: usa a pilha)
    and #$00FF
    pha
    asl a
    clc
    adc 1,s
    tax
    pla
    lda f:AnimQuadro,x
    sta $4302
    A8
    lda f:AnimQuadro+2,x
    sta $4304
    ldx #ANIM_BYTES
    stx $4305
    lda #$01
    sta MDMAEN
    stz anim_sujo
    lda #1
    sta anim_ok
    rtl

; NMI sem pausa/tutorial (depois da UiNmi): liga o BG2 com o cartao. Fora do
; expediente, ou sumindo, volta o BG2SC do xadrez dos menus
AnimNmi:
    .a8
    .i16
    lda state
    cmp #ST_DAY
    bne @off
    lda anim_vis
    cmp #1
    bne @off
    lda anim_ok
    beq @r
    lda #$17                ; BG1 + BG2 + BG3 + sprites
    sta TM
    lda #(ANIM_MAPA_VRAM >> 8)
    sta BG2SC
    stz BG2HOFS
    stz BG2HOFS
    lda #$FF
    sta BG2VOFS
    lda #$03
    sta BG2VOFS
@r: rtl
@off:
    stz anim_vis
    lda #(VRAM_BG2MAP >> 8)
    sta BG2SC
    rtl

; ---------------------------------------------------------------- montagem do pastel (minijogo)
; Quadros-chave: 0 massa, 1 recheio, 2 dobra, 3 fechando com o garfo, 4 pronto.
; Cada acerto anda ate a chave proporcional ao progresso (mg_pos / mg_len).
MGA_CHAVES = 5

; minijogo de fechar o pastel comecou (o conserto do cesto nao tem animacao)
MgaInicio:
    .a8
    .i16
    lda mg_mode
    bne :+
    lda #ANIM_MONTAGEM
    jsl AnimMostra
:   rtl

; acertou um botao: chave = arredonda(mg_pos * 4 / mg_len); na ultima, some depois
MgaAcerto:
    .a8
    .i16
    lda mg_mode
    bne @r
    lda mg_pos              ; (mg_pos * 8 + mg_len) / (mg_len * 2)
    asl a
    asl a
    asl a
    clc
    adc mg_len
    sta tmp
    lda mg_len
    asl a
    sta tmp+1
    ldx #0
:   lda tmp
    cmp tmp+1
    bcc :+
    sbc tmp+1
    sta tmp
    inx
    bra :-
:   cpx #MGA_CHAVES
    bcc :+
    ldx #(MGA_CHAVES-1)
:   lda f:AnimMontagemChaves,x
    clc
    adc #ANIM_MONTAGEM
    jsl AnimVai
    cpx #(MGA_CHAVES-1)
    bne @r
    lda #24                 ; pastel pronto aparece um pouco e o cartao some
    jsl AnimSome
@r: rtl

; errou ou acabou o tempo: desfecho de erro. Por enquanto so some; a melhoria 11
; (pastel indo para a lixeira) toca aqui a sua animacao a partir de anim_cur
MgaErro:
    .a8
    .i16
    lda mg_mode             ; conserto do cesto: sem pastel, sem animacao
    bne :+
    ; o pastel abriu: cai na lixeira (do primeiro ao ultimo quadro) e o cartao
    ; some depois de LIX_FIM quadros parado na tampa fechada
    lda #ANIM_LIXEIRA
    jsl AnimMostra
    lda #(ANIM_LIXEIRA+ANIM_LIXEIRA_N-1)
    jsl AnimVai
    lda #LIX_FIM
    jsl AnimSome
:   rtl
LIX_FIM = 30

; recheio: o emoji do sabor (mg_flav) em cima do monte, nos quadros marcados em
; AnimMontagemExtra (chamada pelo AnimSprites, depois de por os outros atras)
MgaSprites:
    .a8
    .i16
    lda anim_cur
    sec
    sbc #ANIM_MONTAGEM
    cmp #ANIM_MONTAGEM_N
    bcs @r
    A16
    and #$00FF
    tax
    A8
    lda f:AnimMontagemExtra,x
    beq @r
    A16
    lda mg_flav
    and #$00FF
    asl a
    tax
    lda IconTiles,x
    sta spr_tile
    lda #(ANIM_MONTAGEM_PX-8)
    sta spr_x
    A8
    lda #(ANIM_MONTAGEM_PY-8)
    sta spr_y
    lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    FAR0 AddSprite
    stz spr_size
@r: rtl

.segment "BANK28"
AnimBorda: .incbin "gen/anim_borda.bin"
AnimMapa:  .incbin "gen/anim_map.bin"
AnimPal:   .incbin "gen/anim_pal.bin"
.include "gen/anim.inc"

; ---------------------------------------------------------------- password
; Salvar sem SRAM (gerador/senha.js): o save vira um numero em base mista (cada
; campo e um digito com a base exata da sua faixa), P. Os bits do password sao P
; (SENHA_BITS_P, embaralhados por um LFSR semeado pela verificacao) e depois a
; verificacao (CRC-16 CCITT, SENHA_BITS_VER bits) XOR chave; 5 bits por simbolo.
.include "gen/senha.inc"
SENHA_BANCO_TAB = (^SenhaCampos) << 16  ; as tabelas de degraus estao neste banco

SRAM_TESTE = $7007FE        ; 2 ultimos bytes da SRAM de 2 KB (sem uso nos saves)

; no boot: grava $55 e $AA em dois enderecos e so depois rele os dois. Sem SRAM
; o barramento aberto devolve o ultimo valor que passou por ele (o $AA gravado
; ou um byte da instrucao), entao o primeiro nunca volta $55. Os bytes originais
; sao devolvidos. tem_sram = 1 se a SRAM respondeu
SramDetecta:
    .a8
    .i16
    stz tem_sram
    lda f:SRAM_TESTE
    pha
    lda f:SRAM_TESTE+1
    pha
    lda #$55
    sta f:SRAM_TESTE
    lda #$AA
    sta f:SRAM_TESTE+1
    lda f:SRAM_TESTE
    cmp #$55
    bne @nao
    lda f:SRAM_TESTE+1
    cmp #$AA
    bne @nao
    lda #$AA                ; troca os dois e confere de novo
    sta f:SRAM_TESTE
    lda #$55
    sta f:SRAM_TESTE+1
    lda f:SRAM_TESTE
    cmp #$AA
    bne @nao
    inc tem_sram
@nao:
    pla
    sta f:SRAM_TESTE+1
    pla
    sta f:SRAM_TESTE
    rtl

PwMascTab: .byte $80, $40, $20, $10, $08, $04, $02, $01
PwMascBig: .byte $01, $02, $04, $08, $10, $20, $40, $80

; pw_pos -> Y = byte em pw_buf, A = mascara do bit (o bit 0 e o mais alto do byte 0)
PwMasc:
    .a8
    .i16
    A16
    lda pw_pos
    lsr a
    lsr a
    lsr a
    tay
    lda pw_pos
    and #$0007
    tax
    A8
    lda f:PwMascTab,x
    rts

; pw_i -> Y = byte em pw_big, A = mascara do bit (pw_big e little endian)
PwMascI:
    .a8
    .i16
    A16
    lda pw_i
    lsr a
    lsr a
    lsr a
    tay
    lda pw_i
    and #$0007
    tax
    A8
    lda f:PwMascBig,x
    rts

; escreve os pw_n bits de baixo de pw_v (o mais alto primeiro) em pw_pos
; (pw_buf ja zerado: so liga bits)
PwPoe:
    .a8
    .i16
    lda #32
    sec
    sbc pw_n
    beq @pronto
    sta tmp
@al:
    A16
    asl pw_v
    rol pw_v+2
    A8
    dec tmp
    bne @al
@pronto:
    lda pw_n
    beq @fim
    sta tmp
@b: A16
    asl pw_v
    rol pw_v+2
    A8
    bcc @zero
    jsr PwMasc
    ora pw_buf,y
    sta pw_buf,y
@zero:
    A16
    inc pw_pos
    A8
    dec tmp
    bne @b
@fim:
    rts

; le pw_n bits de pw_pos para pw_v
PwTira:
    .a8
    .i16
    A16
    stz pw_v
    stz pw_v+2
    A8
    lda pw_n
    beq @fim
    sta tmp
@b: jsr PwMasc
    and pw_buf,y
    cmp #1                  ; carry = bit
    A16
    rol pw_v
    rol pw_v+2
    inc pw_pos
    A8
    dec tmp
    bne @b
@fim:
    rts

; CRC-16 CCITT de pw_buf -> pw_crc
PwCrc:
    .a8
    .i16
    A16
    lda #$FFFF
    sta pw_crc
    A8
    ldx #0
@b: lda pw_buf,x
    eor pw_crc+1
    sta pw_crc+1
    ldy #8
@bit:
    A16
    asl pw_crc
    bcc :+
    lda pw_crc
    eor #$1021
    sta pw_crc
:   A8
    dey
    bne @bit
    inx
    cpx #SENHA_BYTES
    bne @b
    rts

; XOR dos bits de P com o LFSR semeado por pw_ver (embaralha e desembaralha)
PwEmbaralha:
    .a8
    .i16
    A16
    lda pw_ver
    eor #SENHA_CHAVE_LFSR
    ora #$0001
    sta pw_lfsr
    A8
    ldx #0
@b: ldy #8
@s: A16
    lda pw_lfsr
    lsr a
    bcc :+
    eor #$B400
:   sta pw_lfsr
    A8
    rol tmp
    dey
    bne @s
    lda tmp
    cpx #(SENHA_BYTES_P-1)
    bne :+
    and #SENHA_MASC_P       ; no ultimo byte, so os bits que sao de P
:   eor pw_buf,x
    sta pw_buf,x
    inx
    cpx #SENHA_BYTES_P
    bne @b
    rts

PwZera:
    .a8
    .i16
    ldx #0
:   stz pw_buf,x
    inx
    cpx #SENHA_BYTES
    bne :-
    ldx #0
    stx pw_pos
    rts

; ---- numero grande (SENHA_BIG bytes)
BigZera:
    .a8
    .i16
    ldx #0
:   stz pw_big,x
    inx
    cpx #SENHA_BIG
    bne :-
    rts

; pw_big = pw_big * pw_rad + pw_dig
BigMulAdd:
    .a8
    .i16
    A16
    ldx #0
:   lda pw_big,x
    sta pw_t,x
    stz pw_big,x
    inx
    inx
    cpx #SENHA_BIG
    bne :-
    lda pw_rad
    sta pw_r2
    lda #16
    sta pw_cnt
@b: ldx #0                  ; big *= 2
    ldy #(SENHA_BIG/2)
    clc
:   rol pw_big,x
    inx
    inx
    dey
    bne :-
    asl pw_r2               ; bit da base (do mais alto)
    bcc @n
    ldx #0                  ; big += t
    ldy #(SENHA_BIG/2)
    clc
:   lda pw_big,x
    adc pw_t,x
    sta pw_big,x
    inx
    inx
    dey
    bne :-
@n: dec pw_cnt
    bne @b
    ldx #0                  ; big += digito
    ldy #(SENHA_BIG/2)
    lda pw_dig
    clc
:   adc pw_big,x
    sta pw_big,x
    lda #0
    inx
    inx
    dey
    bne :-
    A8
    rts

; pw_dig = pw_big mod pw_rad; pw_big = pw_big / pw_rad
BigDivMod:
    .a8
    .i16
    A16
    stz pw_rem
    stz pw_rem+2
    lda #(SENHA_BIG*8)
    sta pw_cnt
@b: ldx #0                  ; big <<= 1, o bit de cima vai para o resto
    ldy #(SENHA_BIG/2)
    clc
:   rol pw_big,x
    inx
    inx
    dey
    bne :-
    rol pw_rem
    rol pw_rem+2
    lda pw_rem+2
    bne @sub
    lda pw_rem
    cmp pw_rad
    bcc @n
@sub:
    sec
    lda pw_rem
    sbc pw_rad
    sta pw_rem
    lda pw_rem+2
    sbc #0
    sta pw_rem+2
    inc pw_big              ; o bit 0 acabou de entrar zerado
@n: dec pw_cnt
    bne @b
    lda pw_rem
    sta pw_dig
    A8
    rts

; os SENHA_BITS_P bits de baixo de pw_big -> pw_buf a partir do bit 0 (o mais alto primeiro)
BigParaBits:
    .a8
    .i16
    ldx #0
    stx pw_pos
    ldx #(SENHA_BITS_P-1)
    stx pw_i
@b: jsr PwMascI
    and pw_big,y
    beq @z
    jsr PwMasc
    ora pw_buf,y
    sta pw_buf,y
@z: A16
    inc pw_pos
    dec pw_i
    A8
    bpl @b                  ; (pw_i < 128: o byte de cima e 0 ate passar de 0)
    rts

; o contrario: os bits 0..SENHA_BITS_P-1 de pw_buf -> pw_big
BitsParaBig:
    .a8
    .i16
    jsr BigZera
    ldx #0
    stx pw_pos
    ldx #(SENHA_BITS_P-1)
    stx pw_i
@b: jsr PwMasc
    and pw_buf,y
    beq @z
    jsr PwMascI
    ora pw_big,y
    sta pw_big,y
@z: A16
    inc pw_pos
    dec pw_i
    A8
    bpl @b
    rts

; X = deslocamento do campo na tabela (10 bytes): pw_tipo, pw_tam, pw_adr, pw_rad
PwMeta:
    .a8
    .i16
    stx pw_x
    lda f:SenhaCampos,x
    sta pw_tipo
    lda f:SenhaCampos+1,x
    sta pw_tam
    stz pw_tam+1
    A16
    lda f:SenhaCampos+2,x
    sta pw_adr
    lda f:SenhaCampos+4,x
    sta pw_rad
    A8
    rts

; valor do campo (1, 2 ou 4 bytes) -> pw_v
PwLe:
    .a8
    .i16
    A16
    stz pw_v
    stz pw_v+2
    A8
    ldy pw_adr
    ldx #0
:   lda a:0,y
    sta pw_v,x
    iny
    inx
    cpx pw_tam
    bne :-
    rts

; pw_v -> campo (pw_tam bytes)
PwGrava:
    .a8
    .i16
    ldy pw_adr
    ldx #0
:   lda pw_v,x
    sta a:0,y
    iny
    inx
    cpx pw_tam
    bne :-
    rts

; ---- digito de cada tipo (gerar): campo -> pw_dig
PwDigito:
    .a8
    .i16
    jsr PwLe
    lda pw_tipo
    cmp #SENHA_T_TAB
    bne :+
    jmp PwDigTab
:   cmp #SENHA_T_DIN
    bne :+
    jmp PwDigDin
:   cmp #SENHA_T_LVXP
    bne :+
    jmp PwDigLvxp
:   ; faixa: teto, piso, tira o piso e desloca
    ldx pw_x
    lda f:SenhaCampos+7,x   ; maximo
    A16
    and #$00FF
    cmp pw_v
    bcs :+
    sta pw_v
:   A8
    lda f:SenhaCampos+6,x   ; minimo
    A16
    and #$00FF
    sta pw_dig
    lda pw_v
    cmp pw_dig
    bcs :+
    lda pw_dig
:   sec
    sbc pw_dig
    sta pw_dig
    A8
    A16
    lda f:SenhaCampos+8,x   ; deslocamento
    and #$00FF
    beq @r
    tay
:   lsr pw_dig
    dey
    bne :-
@r: A8
    rts

; degraus: o maior indice com tabela[i] <= valor
PwDigTab:
    .a8
    .i16
    ldx pw_x
    A16
    lda f:SenhaCampos+6,x
    tax
    stz pw_dig
@l: lda pw_dig
    inc a
    cmp pw_rad
    bcs @r
    lda f:SENHA_BANCO_TAB+2,x
    cmp pw_v
    beq :+
    bcs @r
:   inc pw_dig
    inx
    inx
    bra @l
@r: A8
    rts

; dinheiro: < 1024 exato; senao 512 * k + (v >> k), com 512 <= v >> k < 1024
PwDigDin:
    .a8
    .i16
    A16
    lda pw_v+2              ; teto: $FF0000 (o expoente vai ate SENHA_DIN_EXP-1)
    cmp #$00FF
    bcc :+
    stz pw_v
    lda #$00FF
    sta pw_v+2
:   stz pw_dig              ; 512 * k
@k: lda pw_v+2
    bne @desl
    lda pw_v
    cmp #1024
    bcc @fim
@desl:
    lsr pw_v+2
    ror pw_v
    lda pw_dig
    clc
    adc #SENHA_DIN_MANT
    sta pw_dig
    bra @k
@fim:
    clc
    adc pw_dig
    sta pw_dig
    A8
    rts

; desafios + nivel + xp -> indice na tabela SenhaLv* (nivel preso a faixa dos desafios)
PwDigLvxp:
    .a8
    .i16
    lda s_boss
    cmp #5
    bcc :+
    lda #4
:   sta pw_v                ; desafios
    ldx #0
:   lda f:SenhaLvDes,x      ; primeira entrada desses desafios
    cmp pw_v
    beq :+
    inx
    bra :-
:   lda s_level
    cmp f:SenhaLvNiv,x
    bcc @ok                 ; abaixo da faixa: a primeira
@prox:
    cmp f:SenhaLvNiv,x
    beq @ok
    lda f:SenhaLvDes+1,x    ; ultima entrada desses desafios: para
    cmp pw_v
    bne @ok
    inx
    lda s_level
    bra @prox
@ok:
    A16
    txa
    asl a
    tax
    lda f:SenhaLvIni+2,x    ; xp maximo nesse nivel (em passos)
    sec
    sbc f:SenhaLvIni,x
    dec a
    sta pw_rem
    lda s_xp
    ldy #SENHA_XP_DESL
:   lsr a
    dey
    bne :-
    cmp pw_rem
    bcc :+
    lda pw_rem
:   clc
    adc f:SenhaLvIni,x
    sta pw_dig
    A8
    rts

; ---- digito -> campo (ler): pw_dig -> RAM
PwPoeCampo:
    .a8
    .i16
    lda pw_tipo
    cmp #SENHA_T_TAB
    bne :+
    ldx pw_x
    A16
    lda f:SenhaCampos+6,x
    sta pw_rem
    lda pw_dig
    asl a
    clc
    adc pw_rem
    tax
    lda f:SENHA_BANCO_TAB,x
    sta pw_v
    stz pw_v+2
    A8
    jmp PwGrava
:   cmp #SENHA_T_DIN
    bne @nd
    A16
    stz pw_v+2
    lda pw_dig
    cmp #1024
    bcs :+
    sta pw_v
    A8
    jmp PwGrava
:   .a16
    xba                     ; k = digito / 512 - 1 (A16: alto = digito >> 8)
    lsr a
    and #$007F
    dec a
    tay
    lda pw_dig
    and #(SENHA_DIN_MANT-1)
    ora #SENHA_DIN_MANT
    sta pw_v
    cpy #0
    beq :++
:   asl pw_v
    rol pw_v+2
    dey
    bne :-
:   A8
    jmp PwGrava
@nd:
    cmp #SENHA_T_LVXP
    bne @faixa
    ldx #0                  ; maior entrada com inicio <= digito
:   A16
    lda f:SenhaLvIni+2,x
    cmp pw_dig
    beq :+
    bcs :++
:   inx
    inx
    bra :--
:   lda pw_dig
    sec
    sbc f:SenhaLvIni,x
    ldy #SENHA_XP_DESL
:   asl a
    dey
    bne :-
    sta s_xp
    txa
    lsr a
    tax
    A8
    lda f:SenhaLvDes,x
    sta s_boss
    lda f:SenhaLvNiv,x
    sta s_level
    rts
@faixa:
    ldx pw_x
    A16
    lda f:SenhaCampos+8,x   ; deslocamento
    and #$00FF
    tay
    lda pw_dig
    cpy #0
    beq :++
:   asl a
    dey
    bne :-
:   sta pw_v
    A8
    lda f:SenhaCampos+6,x   ; minimo
    A16
    and #$00FF
    clc
    adc pw_v
    sta pw_v
    stz pw_v+2
    A8
    jmp PwGrava

; RAM -> pw_sym (jogo atual -> password)
SenhaGera:
    .a8
    .i16
    lda s_trof
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    and #$07
    sta pw_trof
    lda s_tflags
    and #$07
    sta pw_tflags
    lda #SENHA_VERSAO
    sta pw_versao
    jsr BigZera
    ldx #0
@c: jsr PwMeta
    jsr PwDigito
    jsr BigMulAdd
    A16
    lda pw_x
    clc
    adc #10
    tax
    A8
    cpx #(SENHA_CAMPOS*10)
    bne @c
    ; bits: P, verificacao (com a chave) e embaralha P
    jsr PwZera
    jsr BigParaBits
    jsr PwCrc
    A16
    lda pw_crc
    and #SENHA_MASC_VER
    sta pw_ver
    A8
    jsr PwEmbaralha
    A16
    lda pw_ver
    eor #SENHA_CHAVE_VER
    and #SENHA_MASC_VER
    sta pw_v
    stz pw_v+2
    lda #SENHA_BITS_P
    sta pw_pos
    A8
    lda #SENHA_BITS_VER
    sta pw_n
    jsr PwPoe
    ; 5 bits por simbolo
    ldx #0
    stx pw_pos
@s: phx
    lda #5
    sta pw_n
    jsr PwTira
    plx
    lda pw_v
    sta pw_sym,x
    inx
    cpx #SENHA_N
    bne @s
    rtl

; pw_sym -> RAM. carry = 1 se o password e valido (so entao grava o jogo)
SenhaLe:
    .a8
    .i16
    jsr PwZera
    ldx #0
@s: phx
    lda pw_sym,x
    sta pw_v
    stz pw_v+1
    A16
    stz pw_v+2
    A8
    lda #5
    sta pw_n
    jsr PwPoe
    plx
    inx
    cpx #SENHA_N
    bne @s
    ; verificacao (tira a chave) e zera os bits dela antes do CRC
    A16
    lda #SENHA_BITS_P
    sta pw_pos
    A8
    lda #SENHA_BITS_VER
    sta pw_n
    jsr PwTira
    A16
    lda pw_v
    eor #SENHA_CHAVE_VER
    and #SENHA_MASC_VER
    sta pw_ver
    lda #SENHA_BITS_P
    sta pw_pos
    A8
@zv:
    jsr PwMasc
    eor #$FF
    and pw_buf,y
    sta pw_buf,y
    A16
    inc pw_pos
    lda pw_pos
    cmp #(SENHA_N*5)
    A8
    bne @zv
    jsr PwEmbaralha
    jsr PwCrc
    A16
    lda pw_crc
    and #SENHA_MASC_VER
    cmp pw_ver
    A8
    beq :+
    jmp @inv
:   ; P em base mista: os digitos saem do ultimo campo para o primeiro
    jsr BitsParaBig
    ldx #((SENHA_CAMPOS-1)*2)
    stx pw_i                ; pw_digs[campo]
    ldx #((SENHA_CAMPOS-1)*10)
@d: jsr PwMeta
    jsr BigDivMod
    ldy pw_i
    A16
    lda pw_dig
    sta pw_digs,y
    dec pw_i
    dec pw_i
    lda pw_x
    sec
    sbc #10
    tax
    A8
    bpl @d
    ; sobrou algo: o numero passou do maior valido
    ldx #0
:   lda pw_big,x
    beq :+
    jmp @inv
:   inx
    cpx #SENHA_BIG
    bne :--
    ; versao (1o campo)
    lda pw_digs
    cmp #SENHA_VERSAO
    beq :+
    jmp @inv
:   ; grava todos os campos
    ldx #0
    stx pw_i
@g: jsr PwMeta
    ldy pw_i
    A16
    lda pw_digs,y
    sta pw_dig
    inc pw_i
    inc pw_i
    A8
    jsr PwPoeCampo
    A16
    lda pw_x
    clc
    adc #10
    tax
    A8
    cpx #(SENHA_CAMPOS*10)
    bne @g
    jsr SenhaDeriva
    sec
    rtl
@inv:
    clc
    rtl

; o que nao vai no password: deduzido do resto
SenhaDeriva:
    .a8
    .i16
    lda #'L'
    sta s_magic
    lda #'P'
    sta s_magic+1
    lda #'S'
    sta s_magic+2
    lda #'T'
    sta s_magic+3
    ; pasteis fritos e vendas so contam para as missoes 0 e 1
    ldx #0
    stx s_tot_fried
    stx s_tot_sales
    stx s_tot_sales+2
    lda s_mission
    beq :+
    ldx #5
    stx s_tot_fried
    cmp #2
    bcc :+
    ldx #100
    stx s_tot_sales
:   ; melhorias compradas = fritadeira + balcao acima do 1
    lda s_fryer
    clc
    adc s_counter
    sec
    sbc #2
    sta s_upgrades
    lda s_boss              ; capitulos ja anunciados
    sta s_chapter
    stz s_ending            ; final: 10 unidades (1 + lojas + franquias)
    lda s_stores
    clc
    adc s_fran
    cmp #9
    bcc :+
    inc s_ending
:   ; tutorial: a loja so abre depois do 1o dia
    lda pw_tflags
    ldx s_day
    cpx #2
    bcc :+
    ora #TUT_BIT
:   sta s_tflags
    A16
    lda pw_trof
    and #$0007
    asl a
    asl a
    asl a
    asl a
    asl a
    sta s_trof
    A8
    stz hist_n
    stz menu_sel
    stz d_total             ; (TC5 olha o dia: nao vale aqui)
    FAR0 TrophyCheck        ; refaz os trofeus que dependem so do estado
    ldx #0
    stx r_newtrof
    rts

; ---------------------------------------------------------------- tela do password
; senha_modo 0: digitar (do titulo). Teclado 8x4 com o alfabeto; {A} digita,
; {B} apaga (vazio: volta ao titulo), START confere. Valido: com SRAM escolhe
; onde salvar (ST_SLOTS, sl_mode 3); sem SRAM vai direto para o dia. Com o
; codigo secreto digitado antes (pw_festa), passa primeiro pelo menu secreto.
; senha_modo 1/2: mostra o password do jogo atual (1 volta a loja, 2 ao titulo).
PW_LIN   = 7                ; linha do password
PW_COL   = 4                ; 5 blocos de 4 + 4 espacos = 24 colunas
PW_TECL0 = 12               ; 1a linha do teclado (a cada 2)
PW_TECC0 = 5                ; 1a coluna do teclado (a cada 3)
PW_LINMSG = 21

SenhaInitL:
    .a8
    .i16
    FAR0 FadeOut
    FAR0 ScreenOff
    FAR0 LoadMenuScene
    ; tecla escolhida (16x16) nos tiles 0, 1, 16 e 17 dos sprites (os icones dos
    ; menus ficam ai; quem usa os icones recarrega a folha)
    ldx #VRAM_OBJ
    stx VMADDL
    ldx #.loword(SenhaTecla)
    stx dma_src
    lda #^SenhaTecla
    sta dma_src+2
    ldx #64
    stx dma_len
    FAR0 DmaVram
    ldx #(VRAM_OBJ + 16*16)
    stx VMADDL
    ldx #.loword(SenhaTecla+64)
    stx dma_src
    lda #^SenhaTecla
    sta dma_src+2
    ldx #64
    stx dma_len
    FAR0 DmaVram
    lda senha_modo
    bne @mostra
    stz pw_cur
    stz pw_tecla
    stz pw_msg              ; pw_festa vem do titulo (codigo secreto sem SRAM)
    stz pw_bdel
    stz code_pos
    bra @d
@mostra:
    jsl SenhaGera
    lda #SENHA_N
    sta pw_cur
@d: jsr SenhaDesenha
    jsr SenhaSprite
    FAR0 ScreenOn
    FAR0 FadeIn
    rtl

SenhaDesenha:
    .a8
    .i16
    FAR0 ClearBg3
    lda senha_modo
    beq @dig
    PRINT0 TXT_PW_TIT_M, 3, 3, 5
    PRINT0 TXT_PW_INFO, 3, 13, 4
    jsr SenhaLinhas
    lda senha_modo
    cmp #2
    ldx #TXT_PW_AJ_M
    bcc :+
    ldx #TXT_PW_AJ_S
:   lda #26
    FAR0 Footer
    rts
@dig:
    PRINT0 TXT_PW_TIT_D, 3, 3, 5
    PRINT0 TXT_PW_START, 8, 24, 7
    jsr SenhaLinhas
    jsr SenhaTeclado
    lda pw_msg
    beq @sec
    PRINT0 TXT_PW_INV, 3, PW_LINMSG, 5
    bra @rod
@sec:
    lda pw_festa
    beq @rod
    PRINT0 TXT_PW_SEC, 3, PW_LINMSG, 6
@rod:
    ldx #TXT_PW_AJ_D
    lda #26
    FAR0 Footer
    rts

; as 2 linhas do password (digitando: '-' no que falta e o cursor piscando)
SenhaLinhas:
    .a8
    .i16
    ldx #0                  ; simbolo
    ldy #0                  ; posicao no texto
@l: txa
    cmp pw_cur
    bcc @tem
    bne @traco
    lda frame
    and #$10
    beq @traco
    lda #SENHA_BLOCO
    bra @poe
@traco:
    lda #SENHA_TRACO
    bra @poe
@tem:
    phx
    lda pw_sym,x
    A16
    and #$001F
    tax
    A8
    lda f:SenhaAlfa,x
    plx
@poe:
    sta pw_str,y
    iny
    inx
    cpx #SENHA_N
    beq @fim
    txa
    and #$03
    bne @l
    lda #FONT_SPACE
    sta pw_str,y
    iny
    bra @l
@fim:
    lda #$FF
    sta pw_str,y
    ldx #(PW_LIN*32+PW_COL)
    stx txt_pos
    lda #((5<<2)|$20)
    sta txt_attr
    ldx #pw_str
    FAR0 PrintStr
    rts

; teclado: a tecla escolhida em vermelho, sobre o fundo de tecla (SenhaSprite)
SenhaTeclado:
    .a8
    .i16
    lda #0
@k: pha
    ; posicao: linha PW_TECL0 + 2*(k/8), coluna PW_TECC0 + 3*(k%8)
    lsr a
    lsr a
    and #$FE
    clc
    adc #PW_TECL0
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    sta txt_pos
    lda 1,s
    and #$0007
    sta pw_ch
    asl a
    clc
    adc pw_ch
    clc
    adc #PW_TECC0
    clc
    adc txt_pos
    sta txt_pos
    lda 1,s
    and #$001F
    tax
    A8
    lda f:SenhaAlfa,x
    sta pw_ch
    lda #$FF
    sta pw_ch+1
    ldy #((4<<2)|$20)
    lda 1,s
    cmp pw_tecla
    bne :+
    ldy #((5<<2)|$20)
:   sty txt_attr
    ldx #pw_ch
    FAR0 PrintStr
    pla
    inc a
    cmp #32
    bne @k
    stz hl_y                ; sem faixa: o destaque e o fundo da tecla (SenhaSprite)
    rts

SenhaTecla: .incbin "gen/tecla_tiles.bin"

; fundo da tecla escolhida: sprite 16x16 centrado na letra (o texto fica por cima)
SenhaSprite:
    .a8
    .i16
    FAR0 OamClear
    lda senha_modo
    bne @r
    lda pw_tecla            ; x = (PW_TECC0 + 3 * (k % 8)) * 8 - 4
    and #$07
    sta tmp
    asl a
    clc
    adc tmp
    clc
    adc #PW_TECC0
    asl a
    asl a
    asl a
    sec
    sbc #4
    A16
    and #$00FF
    sta spr_x
    stz spr_tile
    A8
    lda pw_tecla            ; y = (PW_TECL0 + 2 * (k / 8)) * 8 - 4
    lsr a
    lsr a
    and #$FE
    clc
    adc #PW_TECL0
    asl a
    asl a
    asl a
    sec
    sbc #4
    sta spr_y
    lda #$30                ; prioridade 3, paleta 0
    sta spr_attr
    lda #1
    sta spr_size
    FAR0 AddSprite
    stz spr_size
@r: rts

SenhaUpdateL:
    .a8
    .i16
    jsr SenhaSprite
    lda senha_modo
    beq @dig
    lda pad_new
    and #KL_A
    bne @sai
    lda pad_new+1
    and #(KH_B|KH_START)
    bne @sai
    rtl
@sai:
    lda #SFX_CURSOR
    FAR0 PlaySfx
    lda senha_modo
    cmp #2
    lda #ST_SHOP
    bcc :+
    lda #ST_TITLE
:   sta next_state
    rtl
@dig:
    lda frame               ; cursor piscando
    and #$0F
    bne :+
    jsr SenhaLinhas
:   ; codigo secreto (o mesmo do titulo): START com o password abre o menu
    ; secreto. As setas se anulam no teclado, o B do codigo nao apaga nada e o A
    ; final nao digita.
    FAR0 CodeCheck
    bcc @ncod
    lda pw_bdel
    beq :+
    inc pw_cur
:   stz pw_bdel
    lda #1
    sta pw_festa
    stz pw_msg
    lda #SFX_NIVEL
    FAR0 PlaySfx
    jsr SenhaDesenha
    rtl
@ncod:
    ; cruz: anda no teclado (da a volta nas bordas)
    lda pad_new+1
    and #KH_LEFT
    beq @nl
    lda pw_tecla
    and #$07
    bne :+
    lda pw_tecla
    clc
    adc #8
    bra :++
:   lda pw_tecla
:   dec a
    bra @tecla
@nl:
    lda pad_new+1
    and #KH_RIGHT
    beq @nr
    lda pw_tecla
    inc a
    bit #$07
    bne @tecla
    sec
    sbc #8
    bra @tecla
@nr:
    lda pad_new+1
    and #KH_UP
    beq @nu
    lda pw_tecla
    sec
    sbc #8
    and #$1F
    bra @tecla
@nu:
    lda pad_new+1
    and #KH_DOWN
    beq @nd
    lda pw_tecla
    clc
    adc #8
    and #$1F
@tecla:
    sta pw_tecla
    lda #SFX_CURSOR
    FAR0 PlaySfx
    jsr SenhaTeclado
    rtl
@nd:
    lda pad_new
    and #KL_A
    beq @na
    lda pw_cur
    cmp #SENHA_N
    bcc :+
    jmp @erro
:   A16
    and #$00FF
    tax
    A8
    lda pw_tecla
    sta pw_sym,x
    inc pw_cur
    lda #SFX_CURSOR
    FAR0 PlaySfx
    jmp @redes
@na:
    lda pad_new+1
    and #KH_B
    beq @nb
    stz pw_bdel
    lda code_pos            ; B do codigo secreto (so falta o A)?
    cmp #9
    bne @bnor
    lda pw_cur
    beq @bcod               ; vazio: nao sai para o titulo
    inc pw_bdel             ; apaga, e o A do codigo devolve
    bra @apaga
@bcod:
    lda #SFX_CURSOR
    FAR0 PlaySfx
    rtl
@bnor:
    lda pw_cur
    bne @apaga
    lda #SFX_CURSOR         ; nada digitado: volta ao titulo
    FAR0 PlaySfx
    stz pw_festa
    lda #ST_TITLE
    sta next_state
    rtl
@apaga:
    dec pw_cur
    lda #SFX_CURSOR
    FAR0 PlaySfx
    bra @redes
@nb:
    lda pad_new+1
    and #KH_START
    beq @r
    lda pw_cur
    cmp #SENHA_N
    bcs :+
    jmp @erro
:   jsl SenhaLe
    bcc @inv
    lda #SFX_OK
    FAR0 PlaySfx
    lda pw_festa            ; codigo secreto: turbinar antes (o menu segue o jogo)
    beq :+
    lda #ST_SECRET
    sta next_state
    rtl
:   lda tem_sram
    beq :+
    lda #3                  ; com SRAM: escolher onde salvar
    sta sl_mode
    lda #ST_SLOTS
    sta next_state
    rtl
:   lda #ST_PREDAY
    sta next_state
    rtl
@inv:
    lda #1
    sta pw_msg
@erro:
    lda #SFX_ERRO
    FAR0 PlaySfx
    jsr SenhaDesenha
    rtl
@redes:
    lda pw_msg
    beq :+
    stz pw_msg
    jsr SenhaDesenha
    rtl
:   jsr SenhaLinhas
@r: rtl

; ================================================================ ABERTURA "RAMON"
; Homenagem as aberturas da Konami (a do Sunset Riders), com RAMON no lugar de
; KONAMI (gerador/abertura.js). BG1 (tiles 16x16) e a cortina preta com o laser:
; ele entra pela esquerda (HOFS 256 -> 0, 8 px por quadro) e depois desce (VOFS
; -1 -> -259, 2 px por quadro), revelando a logo no BG2 em contorno azul. O resto
; (enchimento com brilho, fundo branco e escurecimento) e so paleta: AbPalQ diz
; em que quadro entra cada uma das AB_NPAL paletas (cores 0..63). A perna do R sao
; AB_NOBJ sprites 16x16 com prioridade 1 (atras do BG2 e da cortina), na paleta OBJ
; 0, que acompanha a paleta 2 (AbPalObj). START ou A pula.
AB_LASER_T  = 42            ; quadro em que o laser comeca a descer
AB_LASER_V  = $3FF - 258    ; VOFS final (a cortina saiu toda por baixo)
AB_FAISCA_XY = VRAM_BG1MAP + 1*32 + 16   ; entrada do mapa da faisca (ponta do laser)
AB_SOM_T    = 177           ; jingle (VOZ_ABERTURA): pedido 4 quadros antes (o anel enche), liga junto com o enchimento de cor

AbInitL:
    .a8
    .i16
    FAR0 ScreenOff
    FAR0 OamClear
    lda #$80
    sta VMAIN
    ldx #VRAM_BG1TILES      ; BG1 e BG2 usam os mesmos tiles (BG12NBA = 0)
    stx VMADDL
    ldx #.loword(AbTiles)
    stx dma_src
    lda #^AbTiles
    sta dma_src+2
    ldx #(AbTiles_end - AbTiles)
    stx dma_len
    FAR0 DmaVram
    ldx #VRAM_BG1MAP
    stx VMADDL
    ldx #.loword(AbBg1)
    stx dma_src
    ldx #2048
    stx dma_len
    FAR0 DmaVram
    ldx #VRAM_BG2MAP
    stx VMADDL
    ldx #.loword(AbBg2)
    stx dma_src
    FAR0 DmaVram
    ldx #VRAM_OBJ           ; perna do R (os sprites do jogo voltam em AbFim)
    stx VMADDL
    ldx #.loword(AbObjTiles)
    stx dma_src
    ldx #(AbObjTiles_end - AbObjTiles)
    stx dma_len
    FAR0 DmaVram
    lda #$19                ; modo 1, BG3 com prioridade, BG1 com tiles 16x16
    sta BGMODE
    ldx #.loword(AbPal)     ; primeira paleta (tudo preto, o contorno azul escondido)
    stx dma_src
    ldx #0
    ldy #128
    FAR0 CopyPal
    jsr AbPalObj
    ; sprites da perna: x, y, tile (AbObj)
    lda #1
    sta spr_size
    lda #$10                ; prioridade 1, paleta OBJ 0
    sta spr_attr
    ldx #0
@obj:
    phx
    lda f:AbObj,x
    sta spr_x
    stz spr_x+1
    lda f:AbObj+1,x
    sta spr_y
    lda f:AbObj+2,x
    sta spr_tile
    stz spr_tile+1
    FAR0 AddSprite
    plx
    inx
    inx
    inx
    cpx #(AB_NOBJ * 3)
    bne @obj
    stz spr_size
    ldx #0
    stx ab_t
    lda #1
    sta ab_pal
    sta ab_on
    jsr AbRolagem
    stz bright              ; acende no primeiro quadro, com a paleta ja enviada
    FAR0 ScreenOn
    FAR0 WaitFrame          ; (a NMI deste quadro ja acha o quadro pronto)
    rtl

; cortina no quadro ab_t: HOFS = max(0, 256 - 8t); VOFS = -1 ate AB_LASER_T,
; depois desce 2 px por quadro ate AB_LASER_V. Faisca: forma 0 ate o quadro 4,
; depois 1, 2, 3, 0... trocando a cada 2 quadros; do 33 em diante fica na 3
AbRolagem:
    .a8
    .i16
    A16
    lda ab_t
    cmp #4
    bcc @f0
    cmp #33
    bcs @f3
    sec
    sbc #4
    lsr a
    inc a
    and #3
    bra @fk
@f0:
    lda #0
    bra @fk
@f3:
    lda #3
@fk:
    asl a
    clc
    adc #AB_FAISCA
    sta ab_fx
    lda ab_t
    cmp #32
    bcc :+
    lda #32
:   asl a
    asl a
    asl a
    eor #$FFFF
    sec
    adc #256
    sta ab_h
    lda ab_t
    sec
    sbc #AB_LASER_T
    bcs :+
    lda #0
:   asl a
    eor #$FFFF
    sec
    adc #$3FF
    cmp #AB_LASER_V
    bcs :+
    lda #AB_LASER_V
:   sta ab_v
    A8
    rts

; paleta OBJ 0 = paleta 2 (a perna do R)
AbPalObj:
    .a8
    .i16
    ldx #30
:   lda cgram_buf+64,x
    sta cgram_buf+256,x
    lda cgram_buf+65,x
    sta cgram_buf+257,x
    dex
    dex
    bpl :-
    rts

AbUpdateL:
    .a8
    .i16
    lda #$0F
    sta bright
    jsr AbRolagem
    ; paletas que entram neste quadro
@pal:
    lda ab_pal
    cmp #AB_NPAL
    bcs @sem
    A16
    and #$00FF
    asl a
    tax
    lda f:AbPalQ,x
    cmp ab_t
    A8
    bne @sem
    A16
    txa
    asl a                   ; indice * 128
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #.loword(AbPal)
    sta dma_src
    A8
    lda #^AbPal
    sta dma_src+2
    ldx #0
    ldy #128
    FAR0 CopyPal
    jsr AbPalObj
    inc ab_pal
    bra @pal
@sem:
    ; jingle: segue a opcao MUSICA (nao a de falas, embora toque como uma fala)
    A16
    lda ab_t
    cmp #AB_SOM_T
    A8
    bne @nsom
    lda opt_music
    beq @nsom
    lda opt_falas
    pha
    lda #1
    sta opt_falas
    lda #VOZ_ABERTURA
    FAR0 VozToca
    pla
    sta opt_falas
@nsom:
    lda pad_new+1
    and #KH_START
    bne @pula
    lda pad_new
    and #KL_A
    bne @pula
    A16
    inc ab_t
    lda ab_t
    cmp #AB_FIM
    A8
    bcs @fim
    rtl
@pula:
    FAR0 VozPara            ; pulou: o jingle para junto
@fim:
    lda #ST_SPLASH
    sta next_state
    rtl

; NMI (depois da UiNmi): BG1 + BG2 + sprites, com a rolagem da cortina
AbNmi:
    .a8
    .i16
    lda #$13
    sta TM
    lda ab_h
    sta BG1HOFS
    lda ab_h+1
    sta BG1HOFS
    lda ab_v
    sta BG1VOFS
    lda ab_v+1
    sta BG1VOFS
    stz BG2HOFS
    stz BG2HOFS
    lda #$FF
    sta BG2VOFS
    lda #$03
    sta BG2VOFS
    lda #$80
    sta VMAIN
    ldx #AB_FAISCA_XY
    stx VMADDL
    ldx ab_fx
    stx $2118               ; VMDATA (palavra)
    rtl

; volta os registradores do resto do jogo (tela ja desligada)
AbFim:
    .a8
    .i16
    stz ab_on
    lda #$09
    sta BGMODE
    stz BG1HOFS
    stz BG1HOFS
    lda #$80                ; os sprites do jogo (a perna do R estava no lugar)
    sta VMAIN
    ldx #VRAM_OBJ
    stx VMADDL
    ldx #.loword(SprTiles)
    stx dma_src
    lda #^SprTiles
    sta dma_src+2
    ldx #16384
    stx dma_len
    FAR0 DmaVram
    rtl
