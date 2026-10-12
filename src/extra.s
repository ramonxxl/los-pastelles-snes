; =====================================================================
;  Opcoes (dificuldade / musica) e escolha da loja do dia
; =====================================================================

OPT_SRAM = $700200

; ---------------------------------------------------------------- opcoes salvas
LoadOptions:
    .a8
    .i16
    lda #1
    sta opt_diff
    sta opt_music
    sta opt_falas
    lda f:OPT_SRAM
    cmp #'O'
    bne @rts
    lda f:OPT_SRAM+1
    cmp #'P'
    bne @rts
    lda f:OPT_SRAM+2
    cmp #3
    bcs @rts
    sta opt_diff
    lda f:OPT_SRAM+3
    and #$01
    sta opt_music
    lda f:OPT_SRAM+4        ; falas: $A0/$A1 (antes de existir a opcao: ligadas)
    and #$FE
    cmp #$A0
    bne @rts
    lda f:OPT_SRAM+4
    and #$01
    sta opt_falas
@rts:
    rts

SaveOptions:
    .a8
    .i16
    lda #'O'
    sta f:OPT_SRAM
    lda #'P'
    sta f:OPT_SRAM+1
    lda opt_diff
    sta f:OPT_SRAM+2
    lda opt_music
    sta f:OPT_SRAM+3
    lda opt_falas
    ora #$A0
    sta f:OPT_SRAM+4
    rts

; ================================================================ TELA DE OPCOES
; caixa com um item por linha: icone (emoji) + nome + valor entre os botoes da
; cruz; o escolhido fica vermelho, com a faixa pulsante e o icone balancando;
; embaixo, a explicacao do item; rodape em pilula
OPT_N    = 4                ; dificuldade, musica, falas, voltar
OPT_LIN0 = 7                ; linha do 1o item (a cada 3 linhas)

OptInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadMenuScene
    VRAM_LOAD IconGfx, VRAM_OBJ, (IconGfx_end - IconGfx)
    PAL_LOAD IconPal, 176, 128
    jsr OamClear
    stz menu_sel
    jsr OptDraw
    jsr OptSprites
    jsr ScreenOn
    jsr FadeIn
    rts

OptNome:    .word TXT_OP_DIF, TXT_OP_MUS, TXT_OP_FAL, TXT_OP_VOLTAR
OptIcone:   .byte ICO_DIF, ICO_MUSICA, ICO_FALAS, ICO_VOLTAR
OptDiffTxt: .word TXT_OP_D0, TXT_OP_D1, TXT_OP_D2
OptDiffDesc:.word TXT_OPD_0, TXT_OPD_1, TXT_OPD_2

; linha do item A -> A
OptLinha:
    .a8
    .i16
    sta tmp
    asl a
    clc
    adc tmp
    clc
    adc #OPT_LIN0
    rts

; txt_pos = linha A, coluna X
OptPos:
    .a8
    .i16
    stx tmp
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc tmp
    sta txt_pos
    A8
    rts

OptDraw:
    .a8
    .i16
    jsr ClearBg3
    PRINT TXT_OP_TIT, 6, 3, 5
    stz loop_i
@it:
    lda loop_i
    jsr OptLinha
    sta loop_i+1
    ldx #5
    jsr OptPos
    ldy #((4<<2)|$20)       ; nome: marrom; o escolhido em vermelho
    lda loop_i
    cmp menu_sel
    bne :+
    ldy #((5<<2)|$20)
:   sty txt_attr
    A16
    lda loop_i
    and #$00FF
    asl a
    tax
    lda OptNome,x
    tax
    A8
    jsr PrintStr
    lda loop_i              ; valor (menos no "voltar"): {ESQ} valor {DIR}
    cmp #3
    bcs @prox
    lda #((7<<2)|$20)
    sta txt_attr
    lda loop_i+1
    ldx #17
    jsr OptPos
    ldx #TXT_OP_ESQ
    jsr PrintStr
    lda loop_i+1
    ldx #28
    jsr OptPos
    ldx #TXT_OP_DIR
    jsr PrintStr
    lda loop_i+1
    ldx #18
    jsr OptPos
    jsr OptValor
    jsr PrintStr
@prox:
    inc loop_i
    lda loop_i
    cmp #OPT_N
    bne @it
    ; explicacao do item escolhido
    lda #((6<<2)|$20)
    sta txt_attr
    lda #20
    ldx #3
    jsr OptPos
    jsr OptAjuda
    jsr PrintStr
    ; faixa pulsante de 16 linhas no item escolhido
    lda menu_sel
    jsr OptLinha
    asl a
    asl a
    asl a
    sec
    sbc #4
    sta hl_y
    lda #16
    sta hl_h
    ldx #TXT_OP_AJ
    lda #26
    jmp Footer

; X = texto do valor do item loop_i
OptValor:
    .a8
    .i16
    lda loop_i
    bne :+
    A16
    lda opt_diff
    and #$00FF
    asl a
    tax
    lda OptDiffTxt,x
    tax
    A8
    rts
:   cmp #1
    bne :+
    ldx #TXT_OP_M0
    lda opt_music
    beq @r
    ldx #TXT_OP_M1
    rts
:   ldx #TXT_OP_F0
    lda opt_falas
    beq @r
    ldx #TXT_OP_F1
@r: rts

; X = explicacao do item escolhido
OptAjuda:
    .a8
    .i16
    lda menu_sel
    bne :+
    A16
    lda opt_diff
    and #$00FF
    asl a
    tax
    lda OptDiffDesc,x
    tax
    A8
    rts
:   ldx #TXT_OPH_MUS
    cmp #1
    beq @r
    ldx #TXT_OPH_FAL
    cmp #2
    beq @r
    ldx #TXT_OPH_VOL
@r: rts

; icones dos itens (o escolhido balanca) e o do titulo
OptSprites:
    .a8
    .i16
    jsr OamClear
    A16
    lda #22
    sta spr_x
    A8
    lda #(3*8 - 4)
    sta spr_y
    lda #ICO_OPC
    clc
    jsr IconeSprite
    stz loop_j
@l: A16
    lda #18
    sta spr_x
    A8
    lda loop_j
    jsr OptLinha
    asl a
    asl a
    asl a
    sec
    sbc #4
    sta spr_y
    A16
    lda loop_j
    and #$00FF
    tax
    A8
    lda loop_j
    cmp menu_sel
    beq :+
    clc
:   lda OptIcone,x
    jsr IconeSprite
    inc loop_j
    lda loop_j
    cmp #OPT_N
    bne @l
    rts

OptUpdate:
    .a8
    .i16
    jsr OptSprites
    lda pad_new+1
    and #KH_UP
    beq @nu
    lda menu_sel
    beq @nu
    dec menu_sel
    SFX SFX_CURSOR
    jsr OptDraw
@nu:
    lda pad_new+1
    and #KH_DOWN
    beq @nd
    lda menu_sel
    cmp #(OPT_N-1)
    bcs @nd
    inc menu_sel
    SFX SFX_CURSOR
    jsr OptDraw
@nd:
    lda pad_new+1
    and #(KH_B|KH_START)
    bne @back
    lda pad_new
    and #KL_A
    bne @act
    lda pad_new+1
    and #(KH_LEFT|KH_RIGHT)
    bne @chg
    rts
@act:
    lda menu_sel
    cmp #3
    beq @back
@chg:
    lda menu_sel
    bne @mus
    ; dificuldade: esquerda desce, direita/A sobe (circular)
    lda pad_new+1
    and #KH_LEFT
    beq @up
    lda opt_diff
    bne :+
    lda #3
:   dec a
    sta opt_diff
    bra @done
@up:
    lda opt_diff
    inc a
    cmp #3
    bcc :+
    lda #0
:   sta opt_diff
    bra @done
@mus:
    cmp #1
    bne @fal
    lda opt_music
    eor #1
    sta opt_music
    beq @off
    jsr MusToca             ; a musica do titulo (gravada) volta
    bra @done
@off:
    jsr StopMusic
    bra @done
@fal:
    cmp #2
    bne @rts
    lda opt_falas
    eor #1
    sta opt_falas
    beq :+
    jsr SaveOptions
    lda #VOZ_TOP            ; amostra: "top demais!"
    jsr VozToca
    jmp OptDraw
:   jsr VozPara
@done:
    SFX SFX_OK
    jsr SaveOptions
    jmp OptDraw
@back:
    jsr SaveOptions
    SFX SFX_CURSOR
    lda #ST_TITLE
    sta next_state
@rts:
    rts

; ================================================================ ESCOLHA DA LOJA DO DIA
UnitName: .word TXT_U_0, TXT_U_1, TXT_U_2, TXT_U_3, TXT_U_4
UnitDesc: .word TXT_UD_0, TXT_UD_1, TXT_UD_2, TXT_UD_3, TXT_UD_4

ChooseInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    lda #$80
    sta VMAIN
    jsr UiOff
    VRAM_LOAD MapTiles, VRAM_BG1TILES, (MapTiles_end - MapTiles)
    VRAM_LOAD MapMap, VRAM_BG1MAP, 2048
    jsr LoadBasePalettes
    PAL_LOAD MapPal, 32, 32
    jsr ClearBg3
    lda d_unit
    cmp #5
    bcc :+
    stz d_unit
:   jsr ChooseDraw
    jsr ChooseSprites
    jsr ScreenOn
    jsr FadeIn
    rts

ChooseDraw:
    .a8
    .i16
    lda #1
    jsr ClearRow
    PRINT TXT_CH_TIT, 6, 1, 1
    lda #25
    jsr ClearRow
    lda #26
    jsr ClearRow
    A16
    lda d_unit
    and #$00FF
    asl a
    tax
    lda UnitName,x
    tax
    A8
    ldy #(25*32+3)
    sty txt_pos
    lda #((1<<2)|$20)
    sta txt_attr
    jsr PrintStr
    A16
    lda d_unit
    and #$00FF
    asl a
    tax
    lda UnitDesc,x
    tax
    A8
    ldy #(26*32+3)
    sty txt_pos
    lda #((0<<2)|$20)
    sta txt_attr
    jsr PrintStr
    ; setas laterais
    PRINT TXT_CH_ESQ, 1, 25, 1
    PRINT TXT_CH_DIR, 30, 25, 1
    rts

; todas as lojas abertas; a escolhida pula e ganha o cursor
ChooseSprites:
    .a8
    .i16
    jsr OamClear
    lda #1
    sta spr_size
    ldy #0
@st:
    tya
    beq :+
    dec a
    cmp s_stores
    bcs @done
:   phy
    A16
    tya
    asl a
    tax
    A8
    lda StoreXY,x
    sta spr_x
    stz spr_x+1
    lda StoreXY+1,x
    sta spr_y
    A16
    lda #SPR_LOJA
    sta spr_tile
    A8
    lda #$30
    sta spr_attr
    tya
    cmp d_unit
    bne @nosel
    ; loja escolhida: pula + seta em cima
    lda frame
    lsr a
    lsr a
    and #$03
    eor #$FF
    clc
    adc spr_y
    sta spr_y
    jsr AddSprite
    lda spr_y
    sec
    sbc #16
    sta spr_y
    A16
    lda #SPR_CURSOR
    sta spr_tile
    A8
@nosel:
    jsr AddSprite
    ply
    iny
    cpy #5
    bne @st
@done:
    rts

ChooseUpdate:
    .a8
    .i16
    jsr ChooseSprites
    lda pad_new+1
    and #(KH_RIGHT|KH_DOWN)
    beq @nr
    lda d_unit
    cmp s_stores
    bcs :+
    inc d_unit
    bra @mv
:   stz d_unit
@mv:
    SFX SFX_CURSOR
    jsr ChooseDraw
@nr:
    lda pad_new+1
    and #(KH_LEFT|KH_UP)
    beq @nl
    lda d_unit
    bne :+
    lda s_stores
    sta d_unit
    bra @mv2
:   dec d_unit
@mv2:
    SFX SFX_CURSOR
    jsr ChooseDraw
@nl:
    lda pad_new+1
    and #KH_START
    bne @go
    lda pad_new
    and #KL_A
    beq @rts
@go:
    SFX SFX_OK
    lda #ST_DAY
    sta next_state
@rts:
    rts

; ---------------------------------------------------------------- cenario da loja do dia
; tabela: blocos (24 bits), tamanho (16), mapa (24), paleta (24), 5 de folga = 16 bytes
LoadShopScene:
    .a8
    .i16
    jsr UiHudOn
    lda #$80
    sta VMAIN
    ; cenario = (bairro * 3 + nivel da reforma) * 16
    lda d_unit
    asl a
    clc
    adc d_unit
    clc
    adc s_reforma
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    tax
    A8
    phx
    ldy #VRAM_BG1TILES
    sty VMADDL
    ldy UnitScenes,x
    sty dma_src
    lda UnitScenes+2,x
    sta dma_src+2
    ldy UnitScenes+3,x
    sty dma_len
    jsr DmaVram
    plx
    phx
    ldy #VRAM_BG1MAP
    sty VMADDL
    ldy UnitScenes+5,x
    sty dma_src
    lda UnitScenes+7,x
    sta dma_src+2
    ldy #2048
    sty dma_len
    jsr DmaVram
    jsr LoadBasePalettes
    plx
    ldy UnitScenes+8,x
    sty dma_src
    lda UnitScenes+10,x
    sta dma_src+2
    ldx #(32*2)
    ldy #32
    jsr CopyPal
    ; balao do tutorial (BG2, so aparece com a caixa do tutorial aberta)
    VRAM_LOAD TutTiles, TUT_VRAM, (TutTiles_end - TutTiles)
    VRAM_LOAD TutMap, VRAM_BG2MAP, 2048
    PAL_LOAD TutPal, 48, 32
    rts

.macro UNIT_SCENE n, r
    .faraddr .ident(.sprintf("Shop%d_%dTiles", n, r))
    .word .ident(.sprintf("Shop%d_%dTiles_end", n, r)) - .ident(.sprintf("Shop%d_%dTiles", n, r))
    .faraddr .ident(.sprintf("Shop%d_%dMap", n, r))
    .faraddr .ident(.sprintf("Shop%d_%dPal", n, r))
    .res 5
.endmacro
UnitScenes:
    UNIT_SCENE 0, 0
    UNIT_SCENE 0, 1
    UNIT_SCENE 0, 2
    UNIT_SCENE 1, 0
    UNIT_SCENE 1, 1
    UNIT_SCENE 1, 2
    UNIT_SCENE 2, 0
    UNIT_SCENE 2, 1
    UNIT_SCENE 2, 2
    UNIT_SCENE 3, 0
    UNIT_SCENE 3, 1
    UNIT_SCENE 3, 2
    UNIT_SCENE 4, 0
    UNIT_SCENE 4, 1
    UNIT_SCENE 4, 2

; ================================================================ JOGOS SALVOS (3 espacos)
SlotsInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadMenuScene
    jsr OamClear
    stz sl_conf
    stz menu_sel
    jsr SlotsDraw
    jsr ScreenOn
    jsr FadeIn
    rts

SlotsDraw:
    .a8
    .i16
    jsr ClearBg3
    PRINT TXT_SL_TIT, 3, 3, 5
    lda #0
@s: sta loop_i
    ; linha = 7 + 3*espaco
    asl a
    clc
    adc loop_i
    clc
    adc #7
    sta loop_i+1
    ; "JOGO n"
    A16
    lda loop_i+1
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    sta lock_lv            ; inicio da linha (linha*32)
    clc
    adc #5
    sta txt_pos
    A8
    lda #((4<<2)|$20)
    sta txt_attr
    ldx #TXT_SL_JOGO
    jsr PrintStr
    A16
    lda lock_lv
    clc
    adc #10
    sta txt_pos
    lda loop_i
    and #$00FF
    inc a
    sta num
    stz num+2
    A8
    lda #1
    sta num_w
    jsr PrintNum
    lda loop_i
    jsr HasSaveSlot
    bcs @tem
    A16
    lda lock_lv
    clc
    adc #13
    sta txt_pos
    A8
    lda #((6<<2)|$20)
    sta txt_attr
    ldx #TXT_SL_VAZIO
    jsr PrintStr
    jmp @next
@tem:
    ; DIA ddd   NV nn  /  R$ dinheiro (linha de baixo)
    A16
    lda lock_lv
    clc
    adc #13
    sta txt_pos
    A8
    lda #((7<<2)|$20)
    sta txt_attr
    ldx #TXT_SL_DIA
    jsr PrintStr
    lda loop_i
    jsr SlotAddr
    ldx tmp2
    A16
    lda f:SRAM+4,x
    sta num
    stz num+2
    lda lock_lv
    clc
    adc #17
    sta txt_pos
    A8
    lda #3
    sta num_w
    jsr PrintNum
    A16
    lda lock_lv
    clc
    adc #22
    sta txt_pos
    A8
    ldx #TXT_SL_NV
    jsr PrintStr
    lda loop_i
    jsr SlotAddr
    ldx tmp2
    lda f:SRAM+12,x
    A16
    and #$00FF
    sta num
    stz num+2
    lda lock_lv
    clc
    adc #25
    sta txt_pos
    A8
    lda #2
    sta num_w
    jsr PrintNum
    A16
    lda lock_lv
    clc
    adc #(32+13)
    sta txt_pos
    A8
    ldx #TXT_SL_RS
    jsr PrintStr
    lda loop_i
    jsr SlotAddr
    ldx tmp2
    A16
    lda f:SRAM+6,x
    sta num
    lda f:SRAM+8,x
    sta num+2
    lda lock_lv
    clc
    adc #(32+16)
    sta txt_pos
    A8
    lda #7
    sta num_w
    jsr PrintNum
    lda loop_i
    jsr SlotFesta
    bcc @next
    A16
    lda lock_lv
    clc
    adc #(32+24)
    sta txt_pos
    A8
    lda #((5<<2)|$20)
    sta txt_attr
    ldx #TXT_SL_FESTA
    jsr PrintStr
@next:
    ; seta no espaco escolhido
    lda loop_i
    cmp menu_sel
    bne :+
    A16
    lda lock_lv
    clc
    adc #3
    asl a
    tax
    A8
    lda #FONT_ARROW
    sta bg3_buf,x
    lda #((5<<2)|$20)
    sta bg3_buf+1,x
    jsr UiMarkX
:   lda loop_i
    inc a
    cmp #3
    beq :+
    jmp @s
:   ; ajuda e avisos
    lda sl_mode
    bne :+
    PRINT TXT_SL_NOVO, 3, 17, 7
    bra :+++
:   cmp #2
    bne :+
    PRINT TXT_SL_SEC, 3, 17, 5
    bra :++
:   PRINT TXT_SL_CONT, 3, 17, 7
:   lda sl_conf
    beq @aj
    cmp #1
    bne :+
    PRINT TXT_SL_CONF, 3, 20, 5
    bra @aj
:   PRINT TXT_SL_VAZ2, 3, 20, 5
@aj:
    ldx #TXT_SL_AJ
    lda #26
    jsr Footer
    rts

SlotsUpdate:
    .a8
    .i16
    lda pad_new+1
    and #KH_UP
    beq @nu
    lda menu_sel
    beq @nu
    dec menu_sel
    stz sl_conf
    SFX SFX_CURSOR
    jsr SlotsDraw
@nu:
    lda pad_new+1
    and #KH_DOWN
    beq @nd
    lda menu_sel
    cmp #2
    bcs @nd
    inc menu_sel
    stz sl_conf
    SFX SFX_CURSOR
    jsr SlotsDraw
@nd:
    lda pad_new+1
    and #KH_B
    beq @nb
    SFX SFX_CURSOR
    lda #ST_TITLE
    sta next_state
    rts
@nb:
    lda pad_new+1
    and #KH_START
    bne @a
    lda pad_new
    and #KL_A
    bne @a
    rts
@a:
    lda sl_mode
    beq @novo
    cmp #2
    bne @cont
    lda menu_sel
    jsr HasSaveSlot
    bcs :+
    lda #2
    sta sl_conf
    SFX SFX_ERRO
    jmp SlotsDraw
:   lda menu_sel
    sta save_slot
    jsr LoadGame
    SFX SFX_OK
    lda #ST_SECRET
    sta next_state
    rts
@cont:
    ; continuar
    lda menu_sel
    jsr HasSaveSlot
    bcs :+
    lda #2
    sta sl_conf
    SFX SFX_ERRO
    jmp SlotsDraw
:   lda menu_sel
    sta save_slot
    jsr LoadGame
    SFX SFX_OK
    lda #ST_PREDAY
    sta next_state
    rts
@novo:
    lda menu_sel
    jsr HasSaveSlot
    bcc @cria
    lda sl_conf
    cmp #1
    beq @cria
    lda #1
    sta sl_conf
    SFX SFX_ALARME
    jmp SlotsDraw
@cria:
    lda menu_sel
    sta save_slot
    jsr NewGame
    jsr SaveGame
    SFX SFX_OK
    lda #ST_INTRO
    sta next_state
    rts

; ================================================================ ABERTURA "LOS PASTELLES APRESENTA"
SplashInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadMenuScene
    jsr ClearBg3
    PRINT TXT_SP_NOME, 10, 11, 5
    PRINT TXT_SP_APR, 12, 13, 4
    PRINT TXT_SP_DEV, 8, 15, 4
    PRINT TXT_SP_AUTOR, 7, 17, 5
    PRINT TXT_SP_SITE, 4, 20, 7
    PRINT TXT_SP_ANO, 7, 22, 6
    PRINT TXT_SP_VER, SP_VER_COL, 24, 4   ; versao calculada na compilacao
    ldx #0
    stx splash_t
    jsr SplashSprite
    jsr ScreenOn
    jsr FadeIn
    SFX SFX_NIVEL
    rts

SplashSprite:
    .a8
    .i16
    jsr OamClear
    A16
    lda #112
    sta spr_x
    A8
    lda #44
    sta spr_y
    lda #$32
    sta spr_attr
    lda dance_t
    beq :+
    ; danca: vira de lado e pula alto
    dec dance_t
    ; pula alto e anda de um lado para o outro
    lda frame
    and #$10
    sta tmp
    lda #40
    sec
    sbc tmp
    sta spr_y
    lda frame
    and #$20
    lsr a
    lsr a
    clc
    adc #104
    sta spr_x
    ldx #0
    stx splash_t
:   jsr MascotFrame
    jmp AddSprite32

SplashUpdate:
    .a8
    .i16
    lda pad_new+1
    and #KH_SEL
    beq :+
    inc dance_cnt
    lda dance_cnt
    cmp #10
    bcc :+
    stz dance_cnt
    lda #200
    sta dance_t
    ldx #0
    stx splash_t
    SFX SFX_NIVEL
:   jsr SplashSprite
    A16
    inc splash_t
    lda splash_t
    cmp #330            ; tempo para ler os creditos e o site
    A8
    bcs @go
    lda pad_new+1
    and #KH_START
    bne @go
    lda pad_new
    and #KL_A
    bne @go
    rts
@go:
    lda #ST_TITLE
    sta next_state
    rts

; ================================================================ TROFEUS
TBit: .word $0001, $0002, $0004, $0008, $0010, $0020, $0040, $0080
      .word $0100, $0200, $0400, $0800, $1000, $2000, $4000, $8000
TrophyCond:
    .word TC0, TC1, TC2, TC3, TC4, TC5, TC6, TC7, TC8, TC9, TC10, TC11, TC12, TC13, TC14, TC15

; marca os trofeus novos (s_trof) e guarda quais foram agora (r_newtrof)
TrophyCheck:
    .a8
    .i16
    ldx #0
    stx r_newtrof
    lda s_tflags
    and #FESTA_BIT
    beq :+
    rts
:
    stx loop_i
@l: A16
    lda loop_i
    asl a
    tax
    lda s_trof
    and TBit,x
    A8
    bne @n
    jsr (TrophyCond,x)
    bcc @n
    A16
    lda loop_i
    asl a
    tax
    lda TBit,x
    tsb s_trof
    tsb r_newtrof
    A8
@n: A16
    inc loop_i
    lda loop_i
    cmp #16
    A8
    bcc @l
    rts

; cartas de "NOVO TROFEU!" para cada trofeu conquistado hoje
TrophyCards:
    .a8
    .i16
    ldy #0
@l: A16
    tya
    asl a
    tax
    lda r_newtrof
    and TBit,x
    A8
    beq @n
    tya
    clc
    adc #CARD_TROF_0
    phy
    jsr CardAdd
    ply
@n: iny
    cpy #16
    bne @l
    rts

.macro TC16 var, valor
    A16
    lda var
    cmp #valor
    A8
    rts
.endmacro
TC0:
    TC16 s_tot_happy, 1
TC1:
    TC16 s_tot_happy, 100
TC2:
    TC16 s_tot_happy, 500
TC3:
    TC16 s_tot_perf, 50
TC4:
    TC16 s_tot_perf, 300
TC5:
    ; dia inteiro sem perder cliente (com pelo menos 10 clientes)
    lda d_lost
    bne :+
    lda d_total
    cmp #10
    rts
:   clc
    rts
TC6:
    A16
    lda s_money+2
    bne :+
    lda s_money
    cmp #5000
    A8
    rts
:   A8
    sec
    rts
TC7:
    A16
    lda s_money+2
    bne :+
    lda s_money
    cmp #20000
    A8
    rts
:   A8
    sec
    rts
TC8:
    lda s_duels
    cmp #5
    rts
TC9:
    lda s_level
    cmp #9
    rts
TC10:
    lda s_stores
    cmp #1
    rts
TC11:
    lda s_fran
    cmp #1
    rts
TC12:
    lda s_boss
    cmp #3
    rts
TC13:
    lda s_tflags
    and #$01
    cmp #1
    rts
TC14:
    jsr Units
    cmp #10
    rts
TC15:
    TC16 s_tot_dlv, 100

; ---------------------------------------------------------------- tela de trofeus
TrofInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadMenuScene
    jsr OamClear
    jsr ClearBg3
    PRINT TXT_TR_TIT, 3, 2, 5
    ; contagem
    ldx #0
    stx tmp4
    ldx #0
@c: A16
    lda s_trof
    and TBit,x
    A8
    beq :+
    inc tmp4
:   inx
    inx
    cpx #32
    bne @c
    PRINTNUM8 tmp4, 22, 2, 6, 2
    PRINT TXT_TR_DE, 24, 2, 6
    ; lista (linhas 4..18)
    ldy #0
@l: phy
    sty loop_i
    A16
    tya
    clc
    adc #4
    asl a
    asl a
    asl a
    asl a
    asl a
    sta lock_lv
    lda loop_i
    asl a
    tax
    lda s_trof
    and TBit,x
    A8
    beq @nao
    ; conquistado: estrela + nome em verde
    A16
    lda lock_lv
    clc
    adc #3
    sta txt_pos
    A8
    lda #((6<<2)|$20)
    sta txt_attr
    ldx #TXT_TR_SIM
    jsr PrintStr
    bra @nome
@nao:
    A16
    lda lock_lv
    clc
    adc #3
    sta txt_pos
    A8
    lda #((4<<2)|$20)
    sta txt_attr
    ldx #TXT_TR_NAO
    jsr PrintStr
@nome:
    A16
    lda lock_lv
    clc
    adc #5
    sta txt_pos
    lda loop_i
    asl a
    tax
    lda TrophyTxt,x
    tax
    A8
    jsr PrintStr
    ply
    iny
    cpy #16
    bne @l
    ldx #TXT_TR_VOLTAR
    lda #26
    jsr Footer
    lda s_tflags
    and #FESTA_BIT
    beq :+
    PRINT TXT_TR_FESTA, 3, 21, 5
:   jsr ScreenOn
    jsr FadeIn
    rts

TrofUpdate:
    .a8
    .i16
    lda pad_new+1
    and #(KH_B|KH_START)
    bne @v
    lda pad_new
    and #KL_A
    bne @v
    rts
@v: SFX SFX_CURSOR
    lda #ST_SHOP
    sta next_state
    rts
