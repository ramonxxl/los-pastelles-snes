; =====================================================================
;  Segredos: codigo classico na tela de titulo (cima cima baixo baixo
;  esq dir esq dir B A) abre o menu secreto. O jogo salvo que usar o
;  menu fica em "modo festa" e nao ganha mais trofeus.
; =====================================================================

FESTA_BIT = $02         ; s_tflags: usou o menu secreto
VENTO_BIT = $04         ; s_tflags: pastel de vento (nao gasta estoque)

CodeSeq: .word $0800, $0800, $0400, $0400, $0200, $0100, $0200, $0100, $8000, $0080

; carry = 1 quando a sequencia acabou de ser completada
CodeCheck:
    .a8
    .i16
    A16
    lda pad_new
    and #$FFF0
    A8
    bne :+
    clc
    rts
:   A16
    sta tmp
    lda code_pos
    and #$00FF
    asl a
    tax
    lda CodeSeq,x
    cmp tmp
    A8
    beq @ok
    ; errou: recomeca (se foi "cima", ja conta como o primeiro)
    A16
    lda tmp
    cmp #$0800
    A8
    bne :+
    lda #1
    sta code_pos
    clc
    rts
:   stz code_pos
    clc
    rts
@ok:
    inc code_pos
    lda code_pos
    cmp #10
    bcs :+
    clc
    rts
:   stz code_pos
    sec
    rts

; ---------------------------------------------------------------- tela do menu secreto
SecretInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadMenuScene
    stz menu_sel
    stz menu_msg
    jsr SecretDraw
    jsr SecretSprite
    jsr ScreenOn
    jsr FadeIn
    rts

SecretTxt: .word TXT_SEC_0, TXT_SEC_1, TXT_SEC_2, TXT_SEC_3, TXT_SEC_4, TXT_SEC_5, TXT_SEC_6

SecretDraw:
    .a8
    .i16
    jsr ClearBg3
    PRINT TXT_SEC_TIT, 3, 3, 5
    ldy #0
@l: phy
    sty loop_i
    A16
    tya
    clc
    adc #6
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #5
    sta txt_pos
    lda loop_i
    asl a
    tax
    lda SecretTxt,x
    tax
    A8
    lda #((4<<2)|$20)
    sta txt_attr
    lda loop_i
    cmp menu_sel
    bne :+
    lda #((5<<2)|$20)
    sta txt_attr
:   jsr PrintStr
    ply
    iny
    cpy #7
    bne @l
    ; seta
    A16
    lda menu_sel
    and #$00FF
    clc
    adc #6
    asl a
    asl a
    asl a
    asl a
    asl a
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
    ; estado do pastel de vento
    ldx #TXT_SEC_OFF
    lda s_tflags
    and #VENTO_BIT
    beq :+
    ldx #TXT_SEC_ON
:   ldy #(10*32+21)
    sty txt_pos
    lda #((6<<2)|$20)
    sta txt_attr
    jsr PrintStr
    PRINT TXT_SEC_AVISO, 3, 15, 5
    PRINT TXT_SEC_DESC, 3, 18, 7
    lda menu_msg
    beq :+
    PRINT TXT_SEC_OK, 3, 21, 6
:   ldx #TXT_TR_VOLTAR
    lda #26
    jsr Footer
    rts

; mascote dancando no canto
SecretSprite:
    .a8
    .i16
    jsr OamClear
    A16
    lda #206
    sta spr_x
    A8
    lda #14
    sta spr_y
    lda #$32
    sta spr_attr
    lda frame
    and #$08
    lsr a
    sta tmp
    lda spr_y
    sec
    sbc tmp
    sta spr_y
    jsr MascotFrame
    jmp AddSprite32

SecretUpdate:
    .a8
    .i16
    jsr SecretSprite
    lda pad_new+1
    and #KH_UP
    beq @nu
    lda menu_sel
    beq @nu
    dec menu_sel
    SFX SFX_CURSOR
    jsr SecretDraw
@nu:
    lda pad_new+1
    and #KH_DOWN
    beq @nd
    lda menu_sel
    cmp #6
    bcs @nd
    inc menu_sel
    SFX SFX_CURSOR
    jsr SecretDraw
@nd:
    lda pad_new+1
    and #KH_B
    beq :+
    SFX SFX_CURSOR
    lda #ST_TITLE
    sta next_state
    rts
:   lda pad_new
    and #KL_A
    bne :+
    rts
:   lda menu_sel
    cmp #5
    bcc @truque
    bne @sair
    ; salvar e jogar
    jsr SaveGame
    SFX SFX_OK
    lda #ST_PREDAY
    sta next_state
    rts
@sair:
    SFX SFX_CURSOR
    lda #ST_TITLE
    sta next_state
    rts
@truque:
    ; qualquer truque marca o jogo como "modo festa"
    lda #FESTA_BIT
    tsb s_tflags
    lda menu_sel
    A16
    and #$00FF
    asl a
    tax
    A8
    jsr (SecretFn,x)
    lda #1
    sta menu_msg
    SFX SFX_NIVEL
    jmp SecretDraw

SecretFn: .word SF0, SF1, SF2, SF3, SF4
SF0: ; +R$ 1.000
    .a8
    .i16
    A16
    lda #1000
    sta tmp
    jsr AddMoney16
    A8
    rts
SF1: ; +1 nivel
    .a8
    .i16
    lda s_level
    cmp #60
    bcs :+
    inc s_level
:   ldx #0
    stx s_xp
    rts
SF2: ; estoque cheio
    .a8
    .i16
    ldx #999
    stx s_stock
    rts
SF3: ; liberar tudo
    .a8
    .i16
    lda #3
    sta s_fryer
    sta s_counter
    lda #1
    sta s_attend
    sta s_ads
    sta s_pc
    sta s_moto
    rts
SF4: ; pastel de vento liga/desliga
    .a8
    .i16
    lda s_tflags
    eor #VENTO_BIT
    sta s_tflags
    rts

; carry = 1 se o espaco A esta em modo festa (le o bloco extra na SRAM)
SlotFesta:
    .a8
    .i16
    jsr SlotAddr
    ldx tmp4
    lda f:SRAM,x
    cmp #'E'
    bne @n
    lda f:SRAM+1,x
    cmp #'Y'
    beq :+
    cmp #'Z'
    bne @n
:   lda f:SRAM+21,x
    and #FESTA_BIT
    beq @n
    sec
    rts
@n: clc
    rts
