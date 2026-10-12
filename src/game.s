; =====================================================================
;  Expediente: clientes, preparo, fritura, entrega
; =====================================================================

ST_TITLE   = 0
ST_INTRO   = 1
ST_CARD    = 2
ST_PREDAY  = 3
ST_DAY     = 4
ST_RESULTS = 5
ST_SHOP    = 6
ST_MAP     = 7
ST_OPTIONS = 8
ST_CHOOSE  = 9
ST_SLOTS   = 10
ST_SPLASH  = 11
ST_TROF    = 12
ST_SECRET  = 13

CUST_Y     = 74
BUBBLE_Y   = 54
PBAR_Y     = 47
BIN_Y      = 146
PASTEL_Y   = 142
FBAR_Y     = 156
OFF_X      = 272

; qualidade
Q_CRU      = 0
Q_BOM      = 1
Q_PERF     = 2
Q_QUEIM    = 3

; ---------------------------------------------------------------- inicio do dia
DayInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadShopScene
    ; clientes de volta (as cartas usam o mesmo espaco para os retratos)
    VRAM_LOAD SprTiles, VRAM_OBJ, 3072   ; (a loja usa o espaco para os icones)
    jsr ClearBg3
    jsr OamClear
    jsr SetupDay
    jsr DrawHudStatic
    jsr DrawHud
    jsr DayDraw
    jsr ScreenOn
    jsr StopMusic           ; expediente: musica gravada (no lugar do chiptune)
    jsr MusToca
    jsr FadeIn
    lda #VOZ_BOMDIA
    jsr VozToca
    ldx #TXT_M_BEMVINDO
    jsr ShowMsg
    rts

SetupDay:
    .a8
    .i16
    ; sabores liberados pelo nivel
    lda #3
    sta n_flav
    lda s_level
    cmp #3
    bcc :+
    inc n_flav
:   cmp #6
    bcc :+
    inc n_flav
:   cmp #9
    bcc :+
    inc n_flav
:   lda s_fryer
    inc a
    sta n_fry
    lda s_counter
    inc a
    sta n_cnt
    ldx #0
    stx d_timer
    stx d_sales
    stx d_tips
    stx d_xp
    lda #10
    sta d_hour
    stz d_min
    stz d_sub
    stz d_closed
    stz d_endwait
    stz d_served
    stz d_total
    stz d_perfect
    stz d_waste
    stz d_happy
    stz d_mystery
    stz d_myst_ok
    stz d_paused
    stz msg_timer
    lda #$FF
    sta d_broke
    sta hold_flav
    stz hold_soda
    stz mg_on
    stz masc_t
    stz pop_t
    stz d_brkonce
    stz d_lost
    stz coin_t
    stz dv_on
    stz dv_on+1
    stz dv_on+2
    stz moto_on
    stz pc_flash
    stz d_deliv
    ldx #0
    stx ph_ring
    stx d_dvsales
    ldx #600
    stx dv_spawn
    ; tutorial guiado so no primeiro dia, e so ate ser concluido uma vez neste jogo salvo
    lda #$FF
    sta tut_step
    stz tut_box
    stz tut_shown
    A16
    lda s_day
    cmp #1
    A8
    bne :+
    lda s_tflags
    and #TUT_BIT
    bne :+
    stz tut_step
:
    jsr DemoDia             ; (demonstracao: comeca as 14h, sem cesto quebrado)
    ; quando quebra um cesto: desafio 3 aos 30 s; nos dias normais 1 em 4 (a partir do dia 4)
    ldx #$FFFF
    stx d_breakat
    lda d_boss
    cmp #2
    bne :+
    ldx #1800
    stx d_breakat
    bra @brk
:   cmp #$FF
    bne @brk
    A16
    lda s_day
    cmp #4
    A8
    bcc @brk
    lda #4
    jsr RandBelow
    cmp #0
    bne @brk
    lda #200
    jsr RandBelow
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    clc
    adc #900
    sta d_breakat
    A8
@brk:
    ldx #90
    stx d_spawn
    ldx #0
@cl:
    stz c_state,x
    stz f_state,x
    stz f_burnt,x
    inx
    cpx #4
    bne @cl
    lda #1
    sta cur_row
    stz cur_col0
    stz cur_col1
    ldx #112
    stx fnd_x
    stz fnd_anim
    stz sizzle_want
    ; paciencia: taxa por quadro (quanto menor, mais tempo de espera)
    A16
    lda opt_diff
    and #$00FF
    asl a
    tax
    lda PatBase,x
    sta d_patrate
    A8
    lda s_attend
    beq :+
    A16
    lda d_patrate
    lsr a
    lsr a
    sta tmp
    lda d_patrate
    sec
    sbc tmp
    sta d_patrate
    A8
:   lda d_boss
    cmp #3
    bne :+
    A16
    lda d_patrate
    clc
    adc #12
    sta d_patrate
    A8
:   ; bairro, preco e chuva
    A16
    lda d_unit
    and #$00FF
    asl a
    tax
    lda d_patrate
    clc
    adc UnitPat,x
    sta d_patrate
    lda s_price
    and #$00FF
    asl a
    tax
    lda d_patrate
    clc
    adc PricePat,x
    sta d_patrate
    A8
    lda d_event
    cmp #3
    bne :+
    A16
    lda d_patrate
    sec
    sbc #10
    sta d_patrate
    A8
:   lda s_ar
    beq :+
    A16
    lda d_patrate
    lsr a
    lsr a
    lsr a
    eor #$FFFF
    sec
    adc d_patrate
    sta d_patrate
    A8
:   lda s_reforma
    beq :+
    A16
    lda d_patrate
    sta tmp
    lsr a
    lsr a
    lsr a
    lsr a
    sta tmp2
    lda s_reforma
    and #$00FF
    tax
    lda tmp
@ref:
    sec
    sbc tmp2
    dex
    bne @ref
    sta d_patrate
    A8
:   A16
    lda d_patrate
    cmp #16
    bcs :+
    lda #16
    sta d_patrate
:   A8   ; velocidade da fritadeira
    A16
    lda s_fryer
    and #$00FF
    dec a
    asl a
    tax
    lda FrySpeed,x
    sta d_speed
    A8
    lda d_boss
    cmp #$FF
    beq :+
    A16
    and #$00FF
    tax
    A8
    lda BossGoal,x
    sta d_goal
:   rts

FrySpeed:    .word 96, 112, 136
; paciencia base: facil / normal / dificil (65536/taxa = quadros de espera)
PatBase:     .word 28, 40, 56
; ajuste por bairro: inicial, centro, residencial, universitaria, empresarial
UnitPat:     .word 0, 10, $FFF8, 0, 6
UnitSpawn:   .word 0, $FFC4, 40, 20, 0
UnitCombo:   .byte 35, 35, 60, 35, 35
UnitPrice:   .byte 0, 0, 0, 0, 2
; preco do pastel (-1, normal, +1, +2): intervalo entre clientes e paciencia
PriceSpawn:  .word $FFD8, 0, 45, 95
PricePat:    .word $FFFB, 0, 5, 11
; cores do oleo (brilho animado)
OilColor:    .word $0E7D, $1EFF
BossGoal:    .byte 14, 6, 18, 24
BossInterval:.word 110, 230, 130, 95
SlotX:       .word 72, 152, 0, 0
             .word 40, 112, 184, 0
             .word 24, 84, 144, 204
PriceTable:  .byte 8, 7, 8, 9, 10, 11

; ---------------------------------------------------------------- HUD
DrawHudStatic:
    .a8
    .i16
    PRINT TXT_HUD_DIA, 1, 1, 0
    PRINT TXT_HUD_RS, 10, 1, 1
    PRINT TXT_HUD_NV, 21, 1, 0
    PRINT TXT_HUD_DP, 29, 1, 0
    PRINT TXT_HUD_EST, 1, 26, 0
    PRINT TXT_HUD_REP, 14, 26, 0
    jsr HasGoal
    bcc :+
    PRINT TXT_HUD_META, 22, 26, 1
    PRINT TXT_HUD_BAR, 29, 26, 1
    PRINTNUM8 d_goal, 30, 26, 1, 2
:   jmp ShowMission

ShowMission:
    .a8
    .i16
    lda #25
    jsr ClearRow
    PRINT TXT_HUD_STAR, 1, 25, 1
    A16
    lda s_mission
    and #$00FF
    asl a
    tax
    lda MissionTxt,x
    tax
    A8
    ldy #(25*32+3)
    sty txt_pos
    lda #((2<<2)|$20)
    sta txt_attr
    jmp PrintStr

DrawHud:
    .a8
    .i16
    PRINTNUM16 s_day, 5, 1, 0, 3
    A16
    lda s_money
    sta num
    lda s_money+2
    sta num+2
    A8
    ldx #(1*32+13)
    stx txt_pos
    lda #((1<<2)|$20)
    sta txt_attr
    lda #7
    sta num_w
    jsr PrintNum
    PRINTNUM8 s_level, 24, 1, 0, 2
    PRINTNUM8 d_hour, 27, 1, 0, 2
    lda #FONT_0
    sta num_pad
    PRINTNUM8 d_min, 30, 1, 0, 2
    PRINTNUM16 s_stock, 9, 26, 0, 3
    PRINTNUM8 s_rep, 18, 26, 0, 3
    jsr HasGoal
    bcc :+
    lda d_boss
    cmp #1
    bne @happy
    PRINTNUM8 d_perfect, 26, 27, 2, 2
    rts
@happy:
    PRINTNUM8 d_happy, 26, 27, 2, 2
:   rts

; ---------------------------------------------------------------- pausa
PauseDraw:
    .a8
    .i16
    lda #12
    jsr ClearRow
    lda #13
    jsr ClearRow
    lda #14
    jsr ClearRow
    lda #15
    jsr ClearRow
    PRINT TXT_PAUSA, 11, 12, 1
    PRINT TXT_PA_CONT, 9, 13, 0
    PRINT TXT_PA_SAIR, 9, 14, 0
    PRINT TXT_PA_AVISO, 3, 15, 3
    A16
    lda pause_sel
    and #$00FF
    clc
    adc #13
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #7
    asl a
    tax
    A8
    lda #FONT_ARROW
    sta bg3_buf,x
    lda #((1<<2)|$20)
    sta bg3_buf+1,x
    rts

PauseMenu:
    .a8
    .i16
    lda pad_new+1
    and #(KH_UP|KH_DOWN|KH_SEL)
    beq :+
    lda pause_sel
    eor #1
    sta pause_sel
    SFX SFX_CURSOR
    jsr PauseDraw
:   lda pad_new+1
    and #KH_START
    bne @ok
    lda pad_new
    and #KL_A
    bne @ok
    rts
@ok:
    lda pause_sel
    bne @sair
    stz d_paused
    stz dim_on
    lda #12
    jsr ClearRow
    lda #13
    jsr ClearRow
    lda #14
    jsr ClearRow
    lda #15
    jsr ClearRow
    SFX SFX_CURSOR
    rts
@sair:
    stz d_paused
    stz dim_on
    stz sizzle_want
    SFX SFX_OK
    lda #ST_TITLE
    sta next_state
    rts

; ---------------------------------------------------------------- tutorial do primeiro dia
TUT_BIT = $08           ; s_tflags: tutorial ja concluido neste jogo salvo

TutTxt: .word TXT_TUT_0, TXT_TUT_0, TXT_TUT_2, TXT_TUT_3, TXT_TUT_4

Tutorial:
    .a8
    .i16
    lda tut_step
    cmp #$FF
    bne :+
    rts
:   ; pastel na mao -> entregar
    lda hold_flav
    cmp #$FF
    beq :+
    lda #4
    sta tut_step
:   lda d_served
    beq @nofim
    lda #$FF
    sta tut_step
    ; primeira entrega: tutorial concluido, nao aparece mais (ja grava na SRAM,
    ; mesmo que o jogador saia antes do fim do dia)
    lda #TUT_BIT
    tsb s_tflags
    jsr SaveTFlags
    lda #5
    jmp TutBox
@nofim:
    lda tut_step
    cmp #3
    bcs @show
    ; algum pastel no oleo? / no ponto?
    ldx #0
@f: lda f_state,x
    beq @nx
    lda #2
    cmp tut_step
    bcc :+
    sta tut_step
:   A16
    txa
    asl a
    tay
    lda f_prog,y
    A8
    xba
    cmp #160
    bcc @nx
    lda #3
    sta tut_step
@nx:
    inx
    cpx #4
    bne @f
@show:
    ; caixa do passo atual (pausa o jogo, uma vez por passo)
    lda tut_step
    bne @bx
    lda mg_on
    beq :+
    lda #1                  ; fechando o pastel
    bra @bx
:   ldx #0
@c: lda c_state,x           ; primeiro cliente entrando na loja
    bne @c0
    inx
    cpx #4
    bne @c
    bra @hint
@c0:
    lda #0
@bx:
    jsr TutBox
    bcs @r
@hint:
    lda msg_timer
    bne @r
    lda mg_on
    bne @r
    lda frame
    and #$1F
    bne @r
    lda #2
    jsr ClearRow
    A16
    lda tut_step
    and #$00FF
    asl a
    tax
    lda TutTxt,x
    tax
    A8
    ldy #(2*32+1)
    sty txt_pos
    lda #((1<<2)|$20)
    sta txt_attr
    jsr PrintStr
@r: rts

TutBit:  .byte 1, 2, 4, 8, 16, 32
TutBoxT: .word TXT_TB_T0, TXT_TB_T1, TXT_TB_T2, TXT_TB_T3, TXT_TB_T4, TXT_TB_T5
TutBoxB: .word TXT_TB_B0, TXT_TB_B1, TXT_TB_B2, TXT_TB_B3, TXT_TB_B4, TXT_TB_B5

; A = passo (0..5): abre a caixa do tutorial e para o jogo; cada passo so uma vez.
; carry = 1 se abriu
TutBox:
    .a8
    .i16
    A16
    and #$00FF
    tax
    A8
    lda TutBit,x
    bit tut_shown
    beq :+
    clc
    rts
:   ora tut_shown
    sta tut_shown
    A16
    txa
    asl a
    pha
    A8
    jsr TutBoxClear
    A16
    lda 1,s
    tax
    lda TutBoxT,x
    tax
    A8
    ldy #(9*32+4)
    sty txt_pos
    lda #((5<<2)|$20)       ; titulo vermelho (cores das caixas: o balao e creme)
    sta txt_attr
    jsr PrintStr
    A16
    pla
    tax
    lda TutBoxB,x
    tax
    A8
    ldy #(11*32+4)
    sty txt_pos
    lda #((4<<2)|$20)
    sta txt_attr
    jsr PrintStr
    lda #45                 ; espera antes de aceitar o A (evita pular sem ler)
    sta tut_box
    lda #2                  ; escurece mais que a pausa (texto por cima do cenario)
    sta dim_on
    SFX SFX_NIVEL
    sec
    rts

TutBoxClear:
    .a8
    .i16
    lda #9
@l: pha
    jsr ClearRow
    pla
    inc a
    cmp #18
    bne @l
    rts

; caixa aberta: o jogo fica parado ate apertar A
TutBoxUpdate:
    .a8
    .i16
    lda tut_box
    cmp #1
    beq @rdy
    dec tut_box
    lda tut_box
    cmp #1
    bne @r
    ldx #TXT_C_A
    lda #17
    jsr Footer
@r: rts
@rdy:
    lda pad_new
    and #KL_A
    bne @ok
    lda pad_new+1
    and #KH_START
    bne @ok
    rts
@ok:
    stz tut_box
    stz dim_on
    jsr TutBoxClear
    SFX SFX_CURSOR
    rts

; carry = 1 se o dia tem meta (desafio ou duelo)
HasGoal:
    .a8
    .i16
    lda d_boss
    cmp #$FF
    bne @y
    lda d_event
    cmp #5
    beq @y
    clc
    rts
@y: sec
    rts

; X = texto; mensagem na linha 2 (boa = amarela)
ShowMsg:
    .a8
    .i16
    lda #1
    bra ShowMsgP
ShowMsgBad:
    .a8
    .i16
    lda #3
ShowMsgP:
    .a8
    .i16
    phx
    asl a
    asl a
    ora #$20
    sta txt_attr
    lda #2
    jsr ClearRow
    ldx #(2*32+1)
    stx txt_pos
    plx
    jsr PrintStr
    lda #150
    sta msg_timer
    rts

MsgUpdate:
    .a8
    .i16
    lda msg_timer
    beq :+
    dec msg_timer
    bne :+
    lda #2
    jsr ClearRow
:   rts

; ---------------------------------------------------------------- atualizacao
DayUpdate:
    .a8
    .i16
    jsr OamClear
    lda tut_box
    beq :+
    jsr TutBoxUpdate
    jmp DayDraw
:   lda d_paused
    beq @run
    jsr PauseMenu
    jmp DayDraw
@run:
    lda pad_new+1
    and #KH_START
    beq :+
    lda #1
    sta d_paused
    sta dim_on
    stz pause_sel
    jsr PauseDraw
    SFX SFX_CURSOR
    jmp DayDraw
:   lda frame
    and #$0F
    bne @nooil
    lda oil_ph
    eor #1
    sta oil_ph
    A16
    and #$0001
    asl a
    tax
    lda OilColor,x
    sta cgram_buf+((32+12)*2)
    A8
    lda #1
    sta pal_dirty
@nooil:
    lda mg_on
    beq @inp
    jsr MiniGame
    bra @cont
@inp:
    jsr DayInput
@cont:
    jsr DayClock
    jsr DaySpawn
    jsr CustUpdate
    jsr DeliveryUpdate
    jsr FryUpdate
    jsr FounderUpdate
    jsr MsgUpdate
    jsr DayMission
    jsr Tutorial
    jsr DrawHud
    jmp DayDraw

DayMission:
    .a8
    .i16
    lda s_mission
    pha
    jsr CheckMission
    pla
    cmp s_mission
    beq :+
    lda #VOZ_MISSAO
    jsr VozToca
    ldx #TXT_M_MISSAO
    jsr ShowMsg
    SFX SFX_NIVEL
    jsr ShowMission
:   rts

; ---------------------------------------------------------------- relogio e fim do dia
DayClock:
    .a8
    .i16
    lda tut_step            ; tutorial guiado: o relogio fica parado
    cmp #$FF
    beq :+
    rts
:   A16
    inc d_timer
    A8
    inc d_sub
    lda d_sub
    cmp #10
    bcc @ok
    stz d_sub
    inc d_min
    lda d_min
    cmp #60
    bcc @ok
    stz d_min
    inc d_hour
@ok:
    ; cesto quebra (desafio 3 ou defeito aleatorio)
    lda d_brkonce
    bne @nob
    A16
    lda d_timer
    cmp d_breakat
    A8
    bcc @nob
    lda #1
    sta d_brkonce
    lda n_fry
    dec a
    sta d_broke
    A16
    and #$00FF
    tax
    A8
    lda f_state,x
    beq :+
    stz f_state,x
    inc d_waste
:   lda #VOZ_QUEBROU
    jsr VozToca
    ldx #TXT_M_QUEBROU
    jsr ShowMsgBad
    SFX SFX_ALARME
@nob:
    lda d_closed
    bne @closed
    lda d_hour
    cmp #19
    bcc @rts
    lda #1
    sta d_closed
    lda #VOZ_PORHOJE
    jsr VozToca
    ldx #TXT_M_FECHOU
    jsr ShowMsg
    SFX SFX_SINO
@rts:
    rts
@closed:
    ldx #0
@chk:
    lda c_state,x
    bne @rts
    inx
    cpx #4
    bne @chk
    inc d_endwait
    lda d_endwait
    cmp #90
    bcc @rts
    ; pasteis que sobraram no oleo viram desperdicio
    ldx #0
@w: lda f_state,x
    beq :+
    inc d_waste
    stz f_state,x
:   inx
    cpx #4
    bne @w
    stz sizzle_want
    lda #ST_RESULTS
    sta next_state
    rts

; ---------------------------------------------------------------- controles
DayInput:
    .a8
    .i16
    lda tut_step
    cmp #$FF
    beq :+
    jmp TutInput
:   lda pad_new+1
    and #KH_LEFT
    beq @nl
    jsr CurCount
    sta tmp
    jsr CurGet
    dec a
    bpl :+
    lda #0
:   jsr CurSet
    SFX SFX_CURSOR
@nl:
    lda pad_new+1
    and #KH_RIGHT
    beq @nr
    jsr CurCount
    sta tmp
    jsr CurGet
    inc a
    cmp tmp
    bcc :+
    lda tmp
    dec a
:   jsr CurSet
    SFX SFX_CURSOR
@nr:
    lda pad_new+1
    and #KH_UP
    beq @nu
    lda cur_row
    beq @nu
    lda hold_flav
    cmp #$FF
    beq :+
    jsr AutoTarget
    bcs @upok
:   stz cur_row
@upok:
    SFX SFX_CURSOR
@nu:
    lda pad_new+1
    and #KH_DOWN
    beq @nd
    lda cur_row
    bne @nd
    lda #1
    sta cur_row
    SFX SFX_CURSOR
@nd:
    lda pad_new+1
    and #KH_B
    beq @nb
    lda hold_flav
    cmp #$FF
    beq @nb
    lda #$FF
    sta hold_flav
    lda #1
    sta cur_row
    inc d_waste
    ldx #TXT_M_LIXO
    jsr ShowMsgBad
    SFX SFX_LIXO
@nb:
    lda pad_new
    and #KL_X
    beq @nx
    lda s_level
    cmp #COMBO_LV
    bcc @nx
    lda hold_soda
    bne @nx
    lda #1
    sta hold_soda
    lda #VOZ_REFRI
    jsr VozToca
    ldx #TXT_M_REFRI
    jsr ShowMsg
    SFX SFX_PEGAR
@nx:
    lda pad_new+1
    and #KH_Y
    beq @ny
    jsr YAction
@ny:
    lda pad_new
    and #KL_A
    beq @na
    jsr ActionA
@na:
    rts

; tutorial guiado: o jogo poe o cursor no lugar certo de cada passo e so aceita o A
; na hora certa (direcionais, B, X e Y nao fazem nada)
TUT_PONTO = 185             ; o pastel para aqui (meio do ponto perfeito, 160..209)
TutInput:
    .a8
    .i16
    ; pastel na mao: entregar ao cliente (o cursor vai ate ele)
    lda hold_flav
    cmp #$FF
    beq @semmao
    jsr AutoTarget
    lda pad_new
    and #KL_A
    beq @r
    jmp ServeCustomer
@semmao:
    ; pastel no oleo: cursor no cesto; A so com o pastel no ponto
    ldx #0
@cesto:
    lda f_state,x
    bne @frit
    inx
    cpx #4
    bne @cesto
    ; nada ainda: cursor no sabor carne; A so com o cliente na loja
    lda #1
    sta cur_row
    stz cur_col1
    lda pad_new
    and #KL_A
    beq @r
    ldx #0
:   lda c_state,x
    bne @ok
    inx
    cpx #4
    bne :-
    bra @nao
@frit:
    lda #1
    sta cur_row
    txa
    clc
    adc n_flav
    sta cur_col1
    lda pad_new
    and #KL_A
    beq @r
    A16
    txa
    asl a
    tay
    lda f_prog,y
    A8
    xba
    cmp #160
    bcc @nao                ; ainda cru: espera a barra ficar verde
@ok:
    jmp ActionA
@nao:
    SFX SFX_ERRO
@r: rts

CurCount:
    .a8
    .i16
    lda cur_row
    bne :+
    lda n_cnt
    rts
:   lda n_flav
    clc
    adc n_fry
    rts
CurGet:
    .a8
    .i16
    lda cur_row
    bne :+
    lda cur_col0
    rts
:   lda cur_col1
    rts
CurSet:
    .a8
    .i16
    pha
    lda cur_row
    bne :+
    pla
    sta cur_col0
    rts
:   pla
    sta cur_col1
    rts

; ---------------------------------------------------------------- acao A
ActionA:
    .a8
    .i16
    lda cur_row
    bne @kitchen
    jmp ServeCustomer
@kitchen:
    lda cur_col1
    cmp n_flav
    bcs @basket
    jmp StartFry
@basket:
    sec
    sbc n_flav
    jmp TakeFromBasket

COMBO_LV = 7

; A = sabor: confere estoque/cesto e abre o minijogo de fechar o pastel
StartFry:
    .a8
    .i16
    sta tmp
    lda s_tflags
    and #VENTO_BIT
    bne :+
    A16
    lda s_stock
    A8
    bne :+
    ldx #TXT_M_SEMEST
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
:   jsr FindBasket
    bcc :+
    ldx #TXT_M_CHEIA
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
:   lda tmp
    sta mg_flav
    stz mg_mode
    jmp MiniStart

; X = cesto livre; carry = 1 se nao ha
FindBasket:
    .a8
    .i16
    ldx #0
@f: cpx #4
    beq @full
    txa
    cmp n_fry
    bcs @full
    cmp d_broke
    beq @nx
    lda f_state,x
    beq @found
@nx:
    inx
    bra @f
@full:
    sec
    rts
@found:
    clc
    rts

; A = sabor: coloca o pastel no oleo
PutInFryer:
    .a8
    .i16
    sta tmp
    jsr FindBasket
    bcc @ok
    ldx #TXT_M_CHEIA
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
@ok:
    lda #1
    sta f_state,x
    lda tmp
    sta f_flav,x
    stz f_burnt,x
    A16
    txa
    asl a
    tay
    lda #0
    sta f_prog,y
    inc s_tot_fried
    A8
    lda s_tflags
    and #VENTO_BIT
    bne :+
    A16
    dec s_stock
    A8
:
    SFX SFX_PLOP
    rts

; ---------------------------------------------------------------- minijogo: fechar o pastel
; botoes: 0 cima 1 baixo 2 esq 3 dir 4 A 5 B 6 X 7 Y
MgMask: .word $0800, $0400, $0200, $0100, $0080, $8000, $0040, $4000

MiniStart:
    .a8
    .i16
    lda s_level
    ldy #2
    cmp #6
    bcc :+
    ldy #3
    cmp #13
    bcc :+
    ldy #4
:   lda mg_mode
    beq :+
    ldy #5                  ; conserto: 5 botoes
:   tya
    sta mg_len
    ldx #0
@g: phx
    lda #8
    jsr RandBelow
    plx
    sta mg_seq,x
    inx
    cpx #6
    bne @g
    stz mg_pos
    ; tempo = 80 + 45 * tamanho (quadros)
    lda mg_len
    sta WRMPYA
    lda #45
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    clc
    adc #80
    sta mg_timer
    sta mg_tmax
    A8
    lda #1
    sta mg_on
    SFX SFX_CURSOR
    jmp MiniDraw

MiniGame:
    .a8
    .i16
    lda tut_step            ; tutorial: o tempo nao corre
    cmp #$FF
    bne @semtempo
    A16
    dec mg_timer
    A8
    beq @fail
@semtempo:
    A16
    lda pad_new
    and #$CFC0
    A8
    beq @draw
    A16
    sta tmp
    lda mg_pos
    and #$00FF
    tax
    lda mg_seq,x
    and #$00FF
    asl a
    tax
    lda MgMask,x
    and tmp
    A8
    beq @errou
    inc mg_pos
    lda mg_pos
    cmp mg_len
    bcs @ok
    SFX SFX_CURSOR
@draw:
    jmp MiniDraw
@errou:
    lda tut_step            ; tutorial: so avisa e espera o botao certo
    cmp #$FF
    beq @fail
    SFX SFX_ERRO
    jmp MiniDraw
@ok:
    stz mg_on
    lda mg_mode
    beq :+
    lda #$FF
    sta d_broke
    ldx #TXT_M_CONSERTO
    jsr ShowMsg
    SFX SFX_OK
    rts
:   lda #VOZ_FECHOU
    jsr VozToca
    ldx #TXT_M_FECHADO
    jsr ShowMsg
    lda mg_flav
    jmp PutInFryer
@fail:
    stz mg_on
    lda mg_mode
    beq :+
    ldx #TXT_M_NAODEU
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
:   lda s_tflags
    and #VENTO_BIT
    bne :+
    A16
    dec s_stock
    A8
:
    inc d_waste
    lda #VOZ_ABRIU
    jsr VozToca
    ldx #TXT_M_ABRIU
    jsr ShowMsgBad
    SFX SFX_LIXO
    rts

; linha 2: aviso; linha 3: sequencia isolada (verde = feito, amarelo = atual)
MiniDraw:
    .a8
    .i16
    lda #2
    jsr ClearRow
    lda mg_mode
    beq :+
    PRINT TXT_M_CONSERTE, 1, 2, 3
    bra :++
:   PRINT TXT_M_FECHE, 1, 2, 1
:   stz msg_timer
    rts

; botoes do minijogo em sprites (cima, baixo, esq, dir, A, B, X, Y)
BtnTiles: .word SPR_BTN_U, SPR_BTN_D, SPR_BTN_L, SPR_BTN_R, SPR_BTN_A, SPR_BTN_B, SPR_BTN_X, SPR_BTN_Y

MiniSprites:
    .a8
    .i16
    lda mg_on
    bne :+
    rts
:   ; x inicial = 130 - 10 * tamanho (centralizado, 20 px entre botoes)
    lda mg_len
    asl a
    sta tmp
    asl a
    asl a
    clc
    adc tmp
    sta tmp
    lda #130
    sec
    sbc tmp
    sta spr_x
    stz spr_x+1
    lda #$30
    sta spr_attr
    ldx #0
@l: stx tmp3
    txa
    cmp mg_len
    bcs @bar
    lda #1
    sta spr_size
    lda #30
    sta spr_y
    txa
    cmp mg_pos
    bcs :+
    ; ja acertado
    A16
    lda #SPR_BTN_OK
    sta spr_tile
    A8
    bra @put
:   bne :+
    ; botao da vez: pula
    lda frame
    lsr a
    lsr a
    and #$02
    eor #$FF
    sec
    adc #30
    sta spr_y
:   lda mg_seq,x
    A16
    and #$00FF
    asl a
    tax
    lda BtnTiles,x
    sta spr_tile
    A8
@put:
    jsr AddSprite
    A16
    lda spr_x
    clc
    adc #20
    sta spr_x
    A8
    ldx tmp3
    inx
    bra @l
@bar:
    ; barra de tempo (4 blocos de 8 px) = mg_timer / mg_tmax
    A16
    lda mg_tmax
    lsr a
    sta tmp
    lda mg_timer
    lsr a
    asl a
    asl a
    asl a
    asl a
    asl a
    sta WRDIVL
    A8
    lda tmp
    sta WRDIVB
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    lda RDDIVL
    sta tmp4               ; 0..32
    ldy #0
    cmp #16
    bcs :+
    ldy #9
    cmp #8
    bcs :+
    ldy #18
:   sty tmp2
    stz spr_size
    lda #48
    sta spr_y
    lda #112
    sta spr_x
    ldx #0
@b: lda tmp4
    sec
    sbc @off,x
    bcs :+
    lda #0
:   cmp #9
    bcc :+
    lda #8
:   clc
    adc tmp2
    A16
    and #$00FF
    clc
    adc #SPR_BAR_BASE
    sta spr_tile
    A8
    phx
    jsr AddSprite
    plx
    lda spr_x
    clc
    adc #8
    sta spr_x
    inx
    cpx #4
    bne @b
    rts
@off: .byte 0, 8, 16, 24

; A = cesto
TakeFromBasket:
    .a8
    .i16
    A16
    and #$00FF
    tax
    A8
    cmp d_broke
    bne :+
    lda #1
    sta mg_mode
    jmp MiniStart
:   lda f_state,x
    bne :+
    ldx #TXT_M_VAZIO
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
:   lda hold_flav
    cmp #$FF
    beq :+
    ldx #TXT_M_MAO
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
:   stz f_state,x
    lda f_flav,x
    sta hold_flav
    A16
    txa
    asl a
    tay
    lda f_prog,y
    A8
    xba
    jsr Quality
    sta hold_q
    SFX SFX_PEGAR
    lda hold_q
    cmp #Q_CRU
    beq @ruim
    cmp #Q_QUEIM
    beq @ruim
    lda #VOZ_OLHA
    jsr VozToca
    jsr AutoTarget
    bcs :+
    jsr DvWants
    ldx #TXT_M_NINGUEM
    bcc @semdv
    ldx #TXT_M_PARAENT
@semdv:
    jsr ShowMsg
:   rts
@ruim:
    lda hold_q              ; cru ou queimado
    cmp #Q_CRU
    bne @queim
    lda #VOZ_CRU
    bra @fala
@queim:
    lda #VOZ_QUEIMOU
@fala:
    jsr VozToca
    ldx #TXT_M_RUIM
    jmp ShowMsgBad

; cursor vai ao cliente (esperando ou chegando) que pediu hold_flav,
; o de menor paciencia primeiro. carry = 1 se achou
AutoTarget:
    .a8
    .i16
    lda #$FF
    sta at_best
    ldx #0
@lp:
    txa
    cmp n_cnt
    bcs @done
    lda c_state,x
    cmp #2
    beq @ok
    cmp #1
    bne @nx
@ok:
    lda c_order,x
    cmp hold_flav
    bne @nx
    A16
    txa
    asl a
    tay
    A8
    lda at_best
    cmp #$FF
    beq @take
    A16
    lda c_pat,y
    cmp at_pat
    A8
    bcs @nx
@take:
    A16
    lda c_pat,y
    sta at_pat
    A8
    txa
    sta at_best
@nx:
    inx
    bra @lp
@done:
    lda at_best
    cmp #$FF
    beq @none
    sta cur_col0
    stz cur_row
    sec
    rts
@none:
    clc
    rts

; A = byte alto do progresso -> A = qualidade
Quality:
    .a8
    .i16
    cmp #110
    bcs :+
    lda #Q_CRU
    rts
:   cmp #160
    bcs :+
    lda #Q_BOM
    rts
:   cmp #210
    bcs :+
    lda #Q_PERF
    rts
:   cmp #235
    bcs :+
    lda #Q_BOM
    rts
:   lda #Q_QUEIM
    rts

; entrega ao cliente do lugar cur_col0
ServeCustomer:
    .a8
    .i16
    A16
    lda cur_col0
    and #$00FF
    tax
    asl a
    tay
    A8
    lda c_state,x
    cmp #2
    beq :++
    cmp #1
    bne :+
    ldx #TXT_M_ESPERA
    jsr ShowMsgBad
:   SFX SFX_ERRO
    rts
:   lda hold_flav
    cmp #$FF
    bne :+
    ldx #TXT_M_MAOVAZ
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
:   cmp c_order,x
    beq @right
    ; sabor errado: perde o pastel e paciencia
    lda #$FF
    sta hold_flav
    lda #1
    sta cur_row
    inc d_waste
    A16
    lda c_pat,y
    sec
    sbc #$3000
    bcs :+
    lda #0
:   sta c_pat,y
    A8
    lda #1
    jsr RepDown
    lda #VOZ_ESSENAO
    jsr VozToca
    ldx #TXT_M_ERRADO
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
@right:
    lda c_combo,x
    beq @nocombo
    lda c_qty,x
    cmp #2
    beq @nocombo
    lda hold_soda
    bne @nocombo
    ldx #TXT_M_FALTAREFRI
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
@nocombo:
    lda #$FF
    sta hold_flav
    lda #1
    sta cur_row
    lda hold_q
    cmp #Q_CRU
    beq @bad
    cmp #Q_QUEIM
    bne @good
@bad:
    inc d_waste
    lda #4
    sta c_state,x
    inc d_lost
    lda #60
    sta c_timer,x
    lda #2
    jsr RepDown
    lda hold_q
    beq :+
    ldx #TXT_M_QUEIM
    bra :++
:   ldx #TXT_M_CRU
:   jsr ShowMsgBad
    SFX SFX_BRAVO
    rts
@good:
    stx tmp3                    ; lugar
    phx
    A16
    lda s_money
    sta pop_base
    lda c_x,y
    clc
    adc #4
    sta pop_x
    A8
    plx
    lda c_qty,x
    cmp #2
    bne @fullsrv
    jmp PartialServe
@fullsrv:
    lda #3
    sta c_state,x
    lda #60
    sta c_timer,x
    inc d_served
    inc d_happy
    A16
    inc s_tot_happy
    ; preco
    lda c_order,x
    and #$00FF
    tax
    lda PriceTable,x
    and #$00FF
    sta tmp
    lda d_unit
    and #$00FF
    tax
    lda UnitPrice,x
    and #$00FF
    clc
    adc tmp
    sta tmp
    lda s_price
    and #$00FF
    clc
    adc tmp
    dec a
    sta tmp
    jsr TypePrice
    clc
    adc d_sales
    sta d_sales
    lda tmp
    clc
    adc s_tot_sales
    sta s_tot_sales
    lda s_tot_sales+2
    adc #0
    sta s_tot_sales+2
    jsr AddMoney16
    A8
    ldx tmp3
    lda c_combo,x
    beq @nocb
    stz hold_soda
    A16
    lda #7
    sta tmp
    clc
    adc d_sales
    sta d_sales
    jsr AddMoney16
    lda d_xp
    clc
    adc #3
    sta d_xp
    A8
@nocb:
    A16
    ; gorjeta = (paciencia >> 14) + 2 se perfeito
    lda c_pat,y
    xba
    and #$00FF
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    sta tmp
    A8
    lda hold_q
    cmp #Q_PERF
    bne @nop
    ; perfeito
    lda #70
    sta masc_t
    inc d_perfect
    A16
    inc s_tot_perf
    inc tmp
    lda d_xp
    clc
    adc #8
    sta d_xp
    A8
    lda #2
    jsr RepUp
    ldx tmp3
    lda c_var,x
    cmp #4
    bne @nomyst
    ; cliente misterioso satisfeito
    lda #1
    sta d_myst_ok
    A16
    lda tmp
    clc
    adc #30
    sta tmp
    A8
    lda #5
    jsr RepUp
    ldx #TXT_M_MIST_OK
    jsr ShowMsg
    bra @tip
@nomyst:
    lda #VOZ_TOP
    jsr VozToca
    ldx #TXT_M_PERF
    jsr ShowMsg
    bra @tip
@nop:
    A16
    lda d_xp
    clc
    adc #5
    sta d_xp
    A8
    lda #1
    jsr RepUp
    ldx #TXT_M_BOM
    jsr ShowMsg
@tip:
    ; Festival: +R$ 1 em toda gorjeta. Critico: +R$ 10 no ponto perfeito.
    lda d_event
    cmp #6
    bne @critic
    A16
    inc tmp
    A8
@critic:
    lda d_event
    cmp #7
    bne @tipdone
    lda hold_q
    cmp #Q_PERF
    bne @tipdone
    A16
    lda tmp
    clc
    adc #10
    sta tmp
    A8
@tipdone:
    ; idoso: gorjeta +3; crianca: sem gorjeta
    ldx tmp3
    lda c_var,x
    cmp #3
    bne :+
    A16
    lda tmp
    clc
    adc #3
    sta tmp
    A8
    bra @tipok
:   cmp #2
    bne @tipok
    A16
    stz tmp
    A8
@tipok:
    lda s_musica
    beq :+
    A16
    inc tmp
    A8
:   lda s_reforma
    cmp #2
    bcc :+
    A16
    inc tmp
    A8
:   A16
    lda tmp
    clc
    adc d_tips
    sta d_tips
    jsr AddMoney16
    lda s_money
    sec
    sbc pop_base
    sta pop_val
    A8
    lda #48
    sta pop_t
    jsr CoinStart
    SFX SFX_MOEDA
    rts

; primeiro pastel de um pedido duplo: paga o pastel e o cliente continua esperando
PartialServe:
    .a8
    .i16
    lda #1
    sta c_qty,x
    A16
    lda c_pat,y
    clc
    adc #$3000
    bcc :+
    lda #$FFFF
:   sta c_pat,y
    A8
    jsr PastelPrice
    A16
    lda tmp
    sta pop_val
    clc
    adc d_sales
    sta d_sales
    lda tmp
    clc
    adc s_tot_sales
    sta s_tot_sales
    lda s_tot_sales+2
    adc #0
    sta s_tot_sales+2
    jsr AddMoney16
    lda d_xp
    clc
    adc #3
    sta d_xp
    A8
    lda #48
    sta pop_t
    jsr CoinStart
    ldx #TXT_M_FALTA1
    jsr ShowMsg
    SFX SFX_MOEDA
    rts

; X = lugar -> tmp = preco do pastel pedido (bairro e ajuste de preco inclusos)
PastelPrice:
    .a8
    .i16
    A16
    lda c_order,x
    and #$00FF
    tax
    lda PriceTable,x
    and #$00FF
    sta tmp
    lda d_unit
    and #$00FF
    tax
    lda UnitPrice,x
    and #$00FF
    clc
    adc tmp
    sta tmp
    lda s_price
    and #$00FF
    clc
    adc tmp
    dec a
    sta tmp
    jsr TypePrice
    A8
    rts

; X = lugar: paciencia do cliente conforme o tipo -> c_rate
SetRate:
    .a8
    .i16
    A16
    lda d_patrate
    sta tmp2
    A8
    lda c_var,x
    cmp #2
    bne :+
    ; crianca: perde a paciencia 50% mais rapido
    A16
    lda tmp2
    lsr a
    clc
    adc tmp2
    sta tmp2
    A8
    bra @s
:   cmp #3
    bne @s
    ; idoso: ~37% mais devagar
    A16
    lda tmp2
    lsr a
    lsr a
    sta tmp4
    lsr a
    clc
    adc tmp4
    sta tmp4
    lda tmp2
    sec
    sbc tmp4
    sta tmp2
    A8
@s: A16
    txa
    asl a
    tay
    lda tmp2
    sta c_rate,y
    A8
    rts

; ajusta o preco em tmp pelo tipo do cliente (lugar em tmp3). Chamar em A16
.a16
TypePrice:
    lda s_unif
    and #$00FF
    beq :+
    inc tmp
:   ldx tmp3
    lda c_var,x
    and #$00FF
    cmp #2
    bne :+
    dec tmp
    bra @r
:   cmp #5
    bne @r
    lda tmp
    clc
    adc #3
    sta tmp
@r: lda tmp
    rts
.a8

; soma tmp (16 bits) ao caixa. Chamar em A16
.a16
AddMoney16:
    lda tmp
    clc
    adc s_money
    sta s_money
    lda s_money+2
    adc #0
    sta s_money+2
    rts
.a8

RepUp:
    .a8
    .i16
    clc
    adc s_rep
    cmp #101
    bcc :+
    lda #100
:   sta s_rep
    rts
RepDown:
    .a8
    .i16
    sta tmp
    lda s_rep
    sec
    sbc tmp
    bcs :+
    lda #0
:   sta s_rep
    rts

; ---------------------------------------------------------------- clientes
DaySpawn:
    .a8
    .i16
    lda tut_step            ; tutorial: um cliente so (o primeiro pedido)
    cmp #$FF
    beq :+
    lda d_total
    bne @rts
:   lda d_closed
    bne @rts
    A16
    lda d_spawn
    beq @try
    dec a
    sta d_spawn
    A8
    bne @rts
@try:
    A8
    lda n_cnt
    jsr RandBelow
    sta tmp
    ldy #0
@find:
    lda tmp
    A16
    and #$00FF
    tax
    A8
    lda c_state,x
    beq @got
    inc tmp
    lda tmp
    cmp n_cnt
    bcc :+
    stz tmp
:   iny
    cpy #4
    bne @find
    ldx #30
    stx d_spawn
@rts:
    A8
    rts
@got:
    ; X = lugar livre
    lda tmp
    cmp n_cnt
    bcs @rts
    lda #1
    sta c_state,x
    stz c_timer,x
    stz c_combo,x
    lda #1
    sta c_qty,x
    phx
    A16
    txa
    asl a
    tay
    lda #OFF_X
    sta c_x,y
    lda #$FFFF
    sta c_pat,y
    ; posicao no balcao
    lda n_cnt
    and #$00FF
    sec
    sbc #2
    asl a
    asl a
    asl a
    sta tmp2
    tya
    clc
    adc tmp2
    tax
    lda SlotX,x
    sta c_tx,y
    A8
    plx
    ; cliente misterioso?
    lda d_mystery
    bne @normal
    lda s_level
    cmp #4
    bcc @normal
    lda #100
    phx
    jsr RandBelow
    plx
    cmp #7
    bcs @normal
    lda #1
    sta d_mystery
    lda #4
    sta c_var,x
    lda n_flav
    dec a
    sta c_order,x
    phx
    ldx #TXT_M_MIST
    jsr ShowMsg
    plx
    jmp @cnt
@normal:
    phx
    lda #4
    jsr RandBelow
    plx
    sta c_var,x
    phx
    lda n_flav
    jsr RandBelow
    plx
    sta c_order,x
    ; turista (nivel 3+, 15%): pede o sabor mais caro
    lda s_level
    cmp #3
    bcc @noTur
    phx
    lda #100
    jsr RandBelow
    plx
    cmp #15
    bcs @noTur
    lda #5
    sta c_var,x
    lda n_flav
    dec a
    sta c_order,x
    phx
    ldx #TXT_M_TURISTA
    jsr ShowMsg
    plx
@noTur:
    ; pedido duplo (nivel 4+): 25% (residencial 40%)
    lda s_level
    cmp #4
    bcc @noqty
    phx
    lda #100
    jsr RandBelow
    plx
    ldy #25
    pha
    lda d_unit
    cmp #2
    bne :+
    ldy #40
:   sty tmp2
    pla
    cmp tmp2
    bcs @noqty
    lda #2
    sta c_qty,x
@noqty:
    lda s_level
    cmp #COMBO_LV
    bcc @cnt
    phx
    lda #100
    jsr RandBelow
    plx
    phx
    pha
    A16
    lda d_unit
    and #$00FF
    tax
    A8
    pla
    cmp UnitCombo,x
    plx
    bcs @cnt
    lda #1
    sta c_combo,x
@cnt:
    lda tut_step            ; tutorial: pedido simples de carne
    cmp #$FF
    beq :+
    stz c_order,x
    stz c_combo,x
    lda #1
    sta c_qty,x
    lda c_var,x
    cmp #4
    bcc :+
    stz c_var,x             ; nem misterioso nem turista
:   jsr SetRate
    inc d_total
    jsr NextInterval
    rts

NextInterval:
    .a8
    .i16
    lda d_boss
    cmp #$FF
    beq @normal
    A16
    and #$00FF
    asl a
    tax
    lda BossInterval,x
    sta tmp
    A8
    lda #48
    jsr RandBelow
    A16
    and #$00FF
    clc
    adc tmp
    sta d_spawn
    A8
    rts
@normal:
    A16
    lda s_rep
    and #$00FF
    lsr a
    sta tmp
    lda #300
    sec
    sbc tmp
    sta tmp
    A8
    lda s_ads
    beq :+
    A16
    lda tmp
    sec
    sbc #50
    sta tmp
    A8
:   lda s_promo
    beq :+
    A16
    lda tmp
    sec
    sbc #70
    sta tmp
    A8
:   lda d_event
    cmp #2
    beq @crowd
    cmp #6
    bne :+
@crowd:
    A16
    lda tmp
    sec
    sbc #70
    sta tmp
    A8
:   lda d_event
    cmp #1
    bne :+
    A16
    lda tmp
    clc
    adc #110
    sta tmp
    A8
:   lda s_reforma
    cmp #2
    bcc :+
    A16
    lda tmp
    sec
    sbc #40
    sta tmp
    A8
:   ; preco: mais caro, menos gente
    A16
    lda s_price
    and #$00FF
    asl a
    tax
    lda PriceSpawn,x
    clc
    adc tmp
    sta tmp
    ; bairro
    lda d_unit
    and #$00FF
    asl a
    tax
    lda UnitSpawn,x
    clc
    adc tmp
    sta tmp
    A8
    ; chuva: menos gente
    lda d_event
    cmp #3
    bne :+
    A16
    lda tmp
    clc
    adc #90
    sta tmp
    A8
:   ; jogo do Brasil (14h-15h59) e almoco na universidade (11h-13h59): pico
    lda d_event
    cmp #4
    bne :+
    lda d_hour
    cmp #14
    bcc :+
    cmp #16
    bcs :+
    jsr Rush
:   lda d_unit
    cmp #3
    bne :+
    lda d_hour
    cmp #11
    bcc :+
    cmp #14
    bcs :+
    jsr Rush
:   lda #64
    jsr RandBelow
    A16
    and #$00FF
    clc
    adc tmp
    cmp #60
    bcs :+
    lda #60
:   sta d_spawn
    A8
    rts

; horario de pico: intervalo -140
Rush:
    .a8
    .i16
    A16
    lda tmp
    sec
    sbc #140
    sta tmp
    A8
    rts

CustUpdate:
    .a8
    .i16
    ldx #0
@lp:
    stx tmp3
    A16
    txa
    asl a
    tay
    A8
    lda c_state,x
    bne @jx1010
    jmp @next
@jx1010:
    cmp #1
    bne @n1
    ; chegando
    A16
    lda c_x,y
    sec
    sbc #2
    cmp c_tx,y
    bcs :+
    lda c_tx,y
:   sta c_x,y
    cmp c_tx,y
    A8
    bne @next
    lda #2
    sta c_state,x
    SFX SFX_SINO
    ldx tmp3
    bra @next
@n1:
    cmp #2
    bne @leave
    ; esperando (no tutorial a paciencia nao cai)
    lda tut_step
    cmp #$FF
    bne @next
    A16
    lda c_pat,y
    sec
    sbc c_rate,y
    sta c_pat,y
    A8
    bcs @next
    A16
    lda #0
    sta c_pat,y
    A8
    lda #4
    sta c_state,x
    inc d_lost
    lda #60
    sta c_timer,x
    lda #3
    jsr RepDown
    lda #VOZ_DESISTIU
    jsr VozToca
    ldx #TXT_M_FOI
    jsr ShowMsgBad
    SFX SFX_BRAVO
    ldx tmp3
    bra @next
@leave:
    lda c_timer,x
    beq :+
    dec c_timer,x
    bra @next
:   A16
    lda c_x,y
    clc
    adc #3
    sta c_x,y
    cmp #OFF_X
    A8
    bcc @next
    stz c_state,x
@next:
    ldx tmp3
    inx
    cpx #4
    beq :+
    jmp @lp
:   rts

; ---------------------------------------------------------------- fritura
FryUpdate:
    .a8
    .i16
    stz sizzle_want
    ldx #$FFFF
    lda tut_step
    cmp #$FF
    beq :+
    ldx #(TUT_PONTO << 8)
:   stx fry_lim
    ldx #0
@lp:
    lda f_state,x
    beq @next
    lda #1
    sta sizzle_want
    stx tmp3
    A16
    txa
    asl a
    tay
    lda f_prog,y
    clc
    adc d_speed
    bcc :+
    lda #$FFFF
:   cmp fry_lim
    bcc :+
    lda fry_lim
:   sta f_prog,y
    A8
    xba
    cmp #235
    bcc @next
    lda f_burnt,x
    bne @next
    lda #1
    sta f_burnt,x
    SFX SFX_QUEIMOU
    ldx tmp3
@next:
    inx
    cpx #4
    bne @lp
    rts

; ---------------------------------------------------------------- fundador
FounderUpdate:
    .a8
    .i16
    jsr CursorPos
    A16
    lda cur_x
    sec
    sbc #8
    sta fnd_tx
    sec
    sbc fnd_x
    beq @stop
    bmi @left
    cmp #3
    bcc :+
    lda #3
:   clc
    adc fnd_x
    sta fnd_x
    bra @mov
@left:
    cmp #$FFFD
    bcs :+
    lda #$FFFD
:   clc
    adc fnd_x
    sta fnd_x
@mov:
    A8
    inc fnd_anim
    rts
@stop:
    A8
    stz fnd_anim
    rts

; posicao do cursor -> cur_x (16), cur_y
CursorPos:
    .a8
    .i16
    lda cur_row
    bne @k
    lda #30
    sta cur_y
    A16
    lda n_cnt
    and #$00FF
    sec
    sbc #2
    asl a
    asl a
    asl a
    sta tmp
    lda cur_col0
    and #$00FF
    asl a
    clc
    adc tmp
    tax
    lda SlotX,x
    clc
    adc #8
    sta cur_x
    A8
    rts
@k:
    lda cur_col1
    cmp n_flav
    bcs @b
    ; tigela: 6 + i*20
    sta WRMPYA
    lda #20
    sta WRMPYB
    nop
    nop
    lda #128
    sta cur_y
    A16
    lda RDMPYL
    clc
    adc #6
    sta cur_x
    A8
    rts
@b:
    sec
    sbc n_flav
    sta WRMPYA
    lda #28
    sta WRMPYB
    nop
    nop
    lda #124
    sta cur_y
    A16
    lda RDMPYL
    clc
    adc #142
    sta cur_x
    A8
    rts

; ---------------------------------------------------------------- desenho
DayDraw:
    .a8
    .i16
    jsr MiniSprites
    ; cursor (balanca)
    jsr CursorPos
    A16
    lda cur_x
    sta spr_x
    lda #SPR_CURSOR
    sta spr_tile
    A8
    lda frame
    lsr a
    lsr a
    lsr a
    and #$01
    clc
    adc cur_y
    sta spr_y
    lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    jsr AddSprite
    ; item na mao (no rodape e acima do fundador)
    lda hold_flav
    cmp #$FF
    beq @nohold
    A16
    and #$00FF
    asl a
    tax
    lda IconTiles,x
    sta spr_tile
    lda #222
    sta spr_x
    A8
    lda #199
    sta spr_y
    lda #$30
    sta spr_attr
    jsr AddSprite
    jsr HoldPastelTile
    A16
    lda #238
    sta spr_x
    A8
    lda #$32
    sta spr_attr
    jsr AddSprite
    A16
    lda fnd_x
    clc
    adc #8
    sta spr_x
    A8
    lda #162
    sta spr_y
    jsr AddSprite
@nohold:
    jsr DrawPopup
    lda hold_soda
    beq @nosoda
    A16
    lda #SPR_REFRI
    sta spr_tile
    lda #206
    sta spr_x
    A8
    lda #199
    sta spr_y
    lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    jsr AddSprite
    A16
    lda fnd_x
    clc
    adc #22
    sta spr_x
    lda #SPR_REFRI_P
    sta spr_tile
    A8
    lda #166
    sta spr_y
    stz spr_size
    jsr AddSprite
@nosoda:
    ; mascote comemorando o pastel perfeito
    lda masc_t
    beq @nomasc
    dec masc_t
    A16
    lda #SPR_MASCOTE_1
    sta spr_tile
    lda #222
    sta spr_x
    A8
    lda masc_t
    and #$08
    bne :+
    A16
    lda #SPR_MASCOTE_0
    sta spr_tile
    A8
:   lda masc_t
    lsr a
    lsr a
    and #$03
    eor #$03
    clc
    adc #168
    sta spr_y
    lda #$32
    sta spr_attr
    jsr AddSprite32
@nomasc:
    ; fundador
    A16
    lda fnd_x
    sta spr_x
    lda #SPR_FOUNDER_0
    sta spr_tile
    A8
    lda fnd_anim
    and #$08
    beq :+
    A16
    lda #SPR_FOUNDER_1
    sta spr_tile
    A8
:   lda #168
    sta spr_y
    lda masc_t
    and #$04
    beq :+
    lda #164
    sta spr_y
:
    lda #$34
    sta spr_attr
    jsr AddSprite32
    jsr DrawCoin
    jsr DrawDelivery
    jsr DrawCustomers
    jsr DrawBins
    jsr DrawBubbles
    jsr DrawBaskets
    rts

DigTiles: .word SPR_DIG_0, SPR_DIG_1, SPR_DIG_2, SPR_DIG_3, SPR_DIG_4, SPR_DIG_5, SPR_DIG_6, SPR_DIG_7, SPR_DIG_8, SPR_DIG_9

; "+NN" amarelo subindo sobre o cliente
DrawPopup:
    .a8
    .i16
    lda pop_t
    bne :+
    rts
:   dec pop_t
    lsr a
    clc
    adc #44
    sta spr_y
    stz spr_size
    lda #$30
    sta spr_attr
    A16
    lda pop_x
    sta spr_x
    lda #SPR_DIG_MAIS
    sta spr_tile
    A8
    jsr AddSprite
    ; dezenas e unidades
    lda pop_val
    ldy #0
@d: cmp #10
    bcc @u
    sbc #10
    iny
    bra @d
@u: pha
    cpy #0
    beq @un
    A16
    lda spr_x
    clc
    adc #7
    sta spr_x
    tya
    asl a
    tax
    lda DigTiles,x
    sta spr_tile
    A8
    jsr AddSprite
@un:
    A16
    lda spr_x
    clc
    adc #7
    sta spr_x
    A8
    pla
    A16
    and #$00FF
    asl a
    tax
    lda DigTiles,x
    sta spr_tile
    A8
    jmp AddSprite

; ================================================================ ENTREGAS (telefone e aplicativo)
TEL_LV = 6

; maximo de comandas abertas: 2 (so telefone) ou 3 (com computador)
DvMax:
    .a8
    .i16
    lda s_pc
    beq :+
    lda #3
    rts
:   lda #2
    rts

; X = comanda livre (carry = 0) ou carry = 1 se nao ha
DvFree:
    .a8
    .i16
    jsr DvMax
    sta tmp4
    ldx #0
@l: txa
    cmp tmp4
    bcs @no
    lda dv_on,x
    beq @ok
    inx
    bra @l
@ok:
    clc
    rts
@no:
    sec
    rts

; carry = 1 se alguma comanda aberta quer o sabor da mao (X = comanda)
DvWants:
    .a8
    .i16
    ldx #0
@l: lda dv_on,x
    beq @n
    lda dv_qty,x
    beq @n
    lda dv_flav,x
    cmp hold_flav
    beq @s
@n: inx
    cpx #3
    bne @l
    clc
    rts
@s: sec
    rts

; cria comanda em X: A = quantidade, tmp4 = 1 se pelo aplicativo
DvCreate:
    .a8
    .i16
    sta dv_qty,x
    sta dv_qtot,x
    lda tmp4
    sta dv_app,x
    lda #1
    sta dv_on,x
    phx
    lda n_flav
    jsr RandBelow
    plx
    sta dv_flav,x
    ; prazo: 60 s (app 80 s); motoboy extra +20 s
    A16
    txa
    asl a
    tay
    lda #3600
    sta tmp
    A8
    lda tmp4
    beq :+
    ldx #4800
    stx tmp
:   lda s_moto
    beq :+
    A16
    lda tmp
    clc
    adc #1200
    sta tmp
    A8
:   A16
    lda tmp
    sta dv_t,y
    A8
    rts

DeliveryUpdate:
    .a8
    .i16
    lda s_level
    cmp #TEL_LV
    bcs :+
    rts
:   ; prazo das comandas
    ldx #0
@t: lda dv_on,x
    beq @tn
    A16
    txa
    asl a
    tay
    lda dv_t,y
    dec a
    sta dv_t,y
    A8
    bne @tn
    stz dv_on,x
    phx
    lda #2
    jsr RepDown
    ldx #TXT_M_CANCEL
    jsr ShowMsgBad
    SFX SFX_BRAVO
    plx
@tn:
    inx
    cpx #3
    bne @t
    ; telefone tocando
    A16
    lda ph_ring
    A8
    beq @quieto
    A16
    dec ph_ring
    A8
    bne :+
    lda #1
    jsr RepDown
    ldx #TXT_M_PERDEU
    jsr ShowMsgBad
    bra @quieto
:   lda ph_ring
    and #$3F
    cmp #$3F
    bne @quieto
    SFX SFX_TELEFONE
@quieto:
    lda pc_flash
    beq :+
    dec pc_flash
:   ; novos pedidos (nao depois de fechar)
    lda d_closed
    beq :+
    rts
:   A16
    lda dv_spawn
    A8
    beq @novo
    A16
    dec dv_spawn
    A8
    rts
@novo:
    jsr DvFree
    bcs @depois
    lda s_pc
    beq @tel
    phx
    lda #2
    jsr RandBelow
    plx
    cmp #0
    beq @tel
    ; pedido pelo aplicativo: entra sozinho, 1 a 3 pasteis
    lda #1
    sta tmp4
    phx
    lda #3
    jsr RandBelow
    plx
    inc a
    jsr DvCreate
    lda #90
    sta pc_flash
    ldx #TXT_M_APP
    jsr ShowMsg
    SFX SFX_APP
    bra @prox
@tel:
    A16
    lda ph_ring
    A8
    bne @depois
    ldx #240
    stx ph_ring
    ldx #TXT_M_LIGACAO
    jsr ShowMsg
    SFX SFX_TELEFONE
@prox:
    ; proximo pedido: 10 a 27 s (com computador, metade)
    lda #255
    jsr RandBelow
    A16
    and #$00FF
    asl a
    asl a
    clc
    adc #600
    sta dv_spawn
    A8
    lda s_pc
    beq :+
    A16
    lda dv_spawn
    lsr a
    clc
    adc #60
    sta dv_spawn
    A8
:   rts
@depois:
    ldx #120
    stx dv_spawn
    rts

; Y: atende o telefone ou coloca o pastel da mao na entrega
YAction:
    .a8
    .i16
    lda s_level
    cmp #TEL_LV
    bcs :+
    rts
:   A16
    lda ph_ring
    A8
    beq @poe
    jsr DvFree
    bcs @poe
    stz tmp4
    lda #1
    jsr DvCreate
    ldx #0
    stx ph_ring
    lda #VOZ_TELEFONE
    jsr VozToca
    ldx #TXT_M_ATENDEU
    jsr ShowMsg
    SFX SFX_OK
    rts
@poe:
    lda hold_flav
    cmp #$FF
    bne :+
    rts
:   lda hold_q
    cmp #Q_CRU
    beq @ruim
    cmp #Q_QUEIM
    beq @ruim
    jsr DvWants
    bcs :+
    ldx #TXT_M_SEMENT
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
:   dec dv_qty,x
    lda #$FF
    sta hold_flav
    lda #1
    sta cur_row
    lda dv_qty,x
    beq @pronta
    ldx #TXT_M_SACOLA
    jsr ShowMsg
    SFX SFX_PLOP
    rts
@ruim:
    ldx #TXT_M_RUIM
    jsr ShowMsgBad
    SFX SFX_ERRO
    rts
@pronta:
    ; entrega completa: pasteis + taxa (R$ 4, ou 6 com motoboy extra)
    stz dv_on,x
    stx tmp3
    lda dv_flav,x
    A16
    and #$00FF
    tax
    lda PriceTable,x
    and #$00FF
    sta tmp2
    lda #4
    sta tmp
    A8
    lda s_moto
    beq :+
    lda #6
    sta tmp
:   ldx tmp3
    lda dv_qtot,x
    A16
    and #$00FF
    tay
    A8
@soma:
    A16
    lda tmp
    clc
    adc tmp2
    sta tmp
    A8
    dey
    bne @soma
    A16
    lda tmp
    clc
    adc d_sales
    sta d_sales
    lda tmp
    clc
    adc d_dvsales
    sta d_dvsales
    lda tmp
    clc
    adc s_tot_sales
    sta s_tot_sales
    lda s_tot_sales+2
    adc #0
    sta s_tot_sales+2
    lda s_money
    sta pop_base
    jsr AddMoney16
    lda tmp
    sta pop_val
    inc s_tot_dlv
    lda d_xp
    clc
    adc #6
    sta d_xp
    lda #20
    sta pop_x
    A8
    inc d_deliv
    lda #1
    jsr RepUp
    lda #48
    sta pop_t
    ; motoboy sai pela porta
    lda #1
    sta moto_on
    ldx #$FFF0
    stx moto_x
    ldx #TXT_M_SAIU
    jsr ShowMsg
    SFX SFX_BUZINA
    rts

; telefone, monitor, comandas e o motoboy
DrawDelivery:
    .a8
    .i16
    lda s_level
    cmp #TEL_LV
    bcs :+
    rts
:   lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    ; telefone (treme quando toca)
    ldx #2
    A16
    lda ph_ring
    A8
    beq :+
    lda frame
    and #$02
    beq :+
    ldx #4
:   stx spr_x
    lda #88
    sta spr_y
    A16
    lda #SPR_TELEFONE
    sta spr_tile
    A8
    jsr AddSprite
    ; monitor (pisca quando chega pedido)
    lda s_pc
    beq @nopc
    lda pc_flash
    and #$08
    bne @nopc
    ldx #238
    stx spr_x
    A16
    lda #SPR_MONITOR
    sta spr_tile
    A8
    jsr AddSprite
@nopc:
    ; comandas na parede (x 2, y 30 / 50 / 70)
    ldx #0
@c: stx tmp3
    lda dv_on,x
    bne :+
    jmp @cn
:   ; pisca nos ultimos 10 s
    A16
    txa
    asl a
    tay
    lda dv_t,y
    cmp #600
    A8
    bcs :+
    lda frame
    and #$08
    beq :+
    jmp @cn
:   txa
    sta WRMPYA
    lda #20
    sta WRMPYB
    nop
    nop
    lda #1
    sta spr_size
    lda RDMPYL
    clc
    adc #30
    sta spr_y
    ldy #2
    sty spr_x
    lda dv_flav,x
    A16
    and #$00FF
    asl a
    tax
    lda IconTiles,x
    sta spr_tile
    A8
    jsr AddSprite
    ; quantidade que falta (se mais de 1)
    ldx tmp3
    lda dv_qty,x
    cmp #2
    bcc :+
    A16
    and #$00FF
    asl a
    tax
    lda DigTiles,x
    sta spr_tile
    lda #18
    sta spr_x
    A8
    stz spr_size
    jsr AddSprite
    lda #1
    sta spr_size
    ldy #2
    sty spr_x
:   A16
    lda #SPR_BALAO
    sta spr_tile
    A8
    jsr AddSprite
@cn:
    ldx tmp3
    inx
    cpx #3
    beq :+
    jmp @c
:   ; moto atravessando o chao
    lda moto_on
    beq @fim
    A16
    lda moto_x
    clc
    adc #4
    sta moto_x
    bmi @anda
    cmp #256
    bcc @anda
    A8
    stz moto_on
    rts
@anda:
    A16
    lda moto_x
    sta spr_x
    lda #SPR_MOTO
    sta spr_tile
    A8
    lda #184
    sta spr_y
    lda #1
    sta spr_size
    jsr AddSprite
@fim:
    rts

; ---------------------------------------------------------------- moeda voando ate o caixa
CoinStart:
    .a8
    .i16
    A16
    lda pop_x
    sta coin_x
    A8
    lda #58
    sta coin_y
    lda #28
    sta coin_t
    rts

DrawCoin:
    .a8
    .i16
    lda coin_t
    bne :+
    rts
:   dec coin_t
    ; aproxima 1/4 do caminho por quadro (destino: dinheiro no topo)
    lda coin_y
    sec
    sbc #2
    lsr a
    lsr a
    sta tmp
    lda coin_y
    sec
    sbc tmp
    sta coin_y
    A16
    lda #104
    sec
    sbc coin_x
    cmp #$8000
    ror a
    cmp #$8000
    ror a
    clc
    adc coin_x
    sta coin_x
    sta spr_x
    lda #SPR_MOEDA
    sta spr_tile
    A8
    lda coin_y
    sta spr_y
    lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    jmp AddSprite

; ---------------------------------------------------------------- bolhas no oleo
DrawBubbles:
    .a8
    .i16
    ldx #0
@l: lda f_state,x
    beq @n
    txa
    cmp n_fry
    bcs @n
    stx tmp3
    ; sobe em ciclo de 16 quadros; x muda a cada ciclo
    txa
    asl a
    asl a
    asl a
    clc
    adc frame
    and #$0F
    sta tmp
    lda #160
    sec
    sbc tmp
    sta spr_y
    A16
    txa
    asl a
    tay
    lda BasketX,y
    sta spr_x
    A8
    lda frame
    lsr a
    lsr a
    lsr a
    lsr a
    clc
    adc tmp3
    asl a
    asl a
    asl a
    and #$0F
    clc
    adc spr_x
    sta spr_x
    A16
    lda #SPR_BOLHA
    sta spr_tile
    A8
    lda #$32
    sta spr_attr
    stz spr_size
    jsr AddSprite
    ldx tmp3
@n: inx
    cpx #4
    bne @l
    rts

HoldPastelTile:
    .a8
    .i16
    A16
    lda #SPR_PASTEL_1
    sta spr_tile
    A8
    lda hold_q
    bne :+
    A16
    lda #SPR_PASTEL_0
    sta spr_tile
    A8
:   cmp #Q_QUEIM
    bne :+
    A16
    lda #SPR_PASTEL_2
    sta spr_tile
    A8
:   rts

IconTiles: .word SPR_ICON_0, SPR_ICON_1, SPR_ICON_2, SPR_ICON_3, SPR_ICON_4, SPR_ICON_5
CustTiles: .word SPR_CUST_0_0, SPR_CUST_0_1, SPR_CUST_0_2
           .word SPR_CUST_1_0, SPR_CUST_1_1, SPR_CUST_1_2
           .word SPR_CUST_2_0, SPR_CUST_2_1, SPR_CUST_2_2
           .word SPR_CUST_3_0, SPR_CUST_3_1, SPR_CUST_3_2
           .word SPR_CUST_4_0, SPR_CUST_4_1, SPR_CUST_4_2
           .word SPR_CUST_5_0, SPR_CUST_5_1, SPR_CUST_5_2
; paleta de cada tipo (0-3 comuns, 4 misterioso, 5 turista usa a paleta do fundador)
CustAttr:  .byte $26, $28, $2A, $2C, $2E, $24

DrawCustomers:
    .a8
    .i16
    ldx #0
@lp:
    stx tmp3
    lda c_state,x
    bne :+
    jmp @next
:   A16
    txa
    asl a
    tay
    lda c_x,y
    sta spr_x
    sta tmp4
    A8
    ; expressao: 0 normal, 1 feliz, 2 bravo
    lda c_state,x
    ldy #0
    cmp #3
    bne :+
    ldy #1
:   cmp #4
    bne :+
    ldy #2
:   cmp #2
    bne @expr
    ; esperando com pouca paciencia = bravo
    phx
    A16
    txa
    asl a
    tax
    lda c_pat,x
    cmp #$3000
    A8
    plx
    bcs @expr
    ldy #2
@expr:
    sty tmp2
    lda c_var,x
    sta WRMPYA
    lda #3
    sta WRMPYB
    nop
    nop
    nop
    A16
    lda RDMPYL
    clc
    adc tmp2
    asl a
    tax
    lda CustTiles,x
    sta spr_tile
    A8
    ldx tmp3
    lda c_var,x
    phx
    A16
    and #$00FF
    tax
    A8
    lda CustAttr,x          ; paleta + prioridade 2 (atras do balcao)
    plx
    sta spr_attr
    lda #CUST_Y
    sta spr_y
    lda c_state,x
    cmp #2
    beq :+
    lda frame
    lsr a
    and #$02
    eor #$FF
    inc a
    clc
    adc #CUST_Y
    sta spr_y
:   jsr AddSprite32
    ldx tmp3
    lda c_state,x
    cmp #2
    beq @wait
    cmp #3
    beq @happy
    cmp #4
    beq @jx1395
    jmp @next
@jx1395:
    ; bravo
    A16
    lda #SPR_RAIVA
    bra @icon
@happy:
    A16
    lda #SPR_CORACAO
@icon:
    sta spr_tile
    lda tmp4
    clc
    adc #8
    sta spr_x
    A8
    lda #62
    sta spr_y
    lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    jsr AddSprite
    jmp @next
@wait:
    ; icone do pedido + balao
    lda c_order,x
    A16
    and #$00FF
    asl a
    tax
    lda IconTiles,x
    sta spr_tile
    lda tmp4
    clc
    adc #8
    sta spr_x
    A8
    lda #BUBBLE_Y
    sta spr_y
    lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    jsr AddSprite
    ldx tmp3
    lda c_qty,x
    cmp #2
    bne @noq
    A16
    lda spr_x
    pha
    sec
    sbc #6
    sta spr_x
    lda #SPR_DIG_2
    sta spr_tile
    A8
    stz spr_size
    jsr AddSprite
    A16
    pla
    sta spr_x
    A8
    lda #1
    sta spr_size
@noq:
    ldx tmp3
    lda c_combo,x
    beq @nocan
    A16
    lda spr_x
    pha
    clc
    adc #14
    sta spr_x
    lda #SPR_REFRI_P
    sta spr_tile
    A8
    stz spr_size
    lda #(BUBBLE_Y+5)
    sta spr_y
    jsr AddSprite
    A16
    pla
    sta spr_x
    A8
    lda #BUBBLE_Y
    sta spr_y
    lda #1
    sta spr_size
@nocan:
    A16
    lda #SPR_BALAO
    sta spr_tile
    A8
    jsr AddSprite
    ; barra de paciencia
    ldx tmp3
    A16
    txa
    asl a
    tax
    lda c_pat,x
    xba
    and #$00FF
    lsr a
    lsr a
    lsr a
    lsr a
    sta tmp
    A8
    lda c_pat+1,x
    ldy #0
    cmp #$80
    bcs :+
    ldy #9
    cmp #$40
    bcs :+
    ldy #18
:   sty tmp2
    cpy #18
    bne :+
    lda frame
    and #$08
    bne @next
:   lda #PBAR_Y
    sta spr_y
    jsr DrawBar
@next:
    ldx tmp3
    inx
    cpx #4
    beq :+
    jmp @lp
:   rts

; barra de 16 pixels: tmp = nivel 0..15, tmp2 = cor (0, 9, 18), spr_x = inicio-8.. usa spr_y
; desenha em spr_x+? (spr_x ja aponta para o inicio da barra)
DrawBar:
    .a8
    .i16
    stz spr_size
    lda #$30
    sta spr_attr
    ; metade esquerda: min(nivel, 8)
    lda tmp
    cmp #9
    bcc :+
    lda #8
:   clc
    adc tmp2
    A16
    and #$00FF
    clc
    adc #SPR_BAR_BASE
    sta spr_tile
    A8
    jsr AddSprite
    A16
    lda spr_x
    clc
    adc #8
    sta spr_x
    A8
    lda tmp
    sec
    sbc #8
    bcs :+
    lda #0
:   clc
    adc tmp2
    A16
    and #$00FF
    clc
    adc #SPR_BAR_BASE
    sta spr_tile
    A8
    jmp AddSprite

DrawBins:
    .a8
    .i16
    ldx #0
@lp:
    stx tmp3
    A16
    txa
    asl a
    tay
    lda BinX,y
    sta spr_x
    lda IconTiles,y
    sta spr_tile
    A8
    txa
    cmp n_flav
    bcc :+
    A16
    lda #SPR_CADEADO
    sta spr_tile
    A8
:   lda #BIN_Y
    sta spr_y
    lda #$30
    sta spr_attr
    lda #1
    sta spr_size
    jsr AddSprite
    ldx tmp3
    inx
    cpx #6
    bne @lp
    rts
BinX: .word 6, 26, 46, 66, 86, 106

DrawBaskets:
    .a8
    .i16
    ldx #0
@lp:
    stx tmp3
    A16
    txa
    asl a
    tay
    lda BasketX,y
    sta spr_x
    sta tmp4
    A8
    lda #1
    sta spr_size
    lda #$30
    sta spr_attr
    lda #PASTEL_Y
    sta spr_y
    txa
    cmp n_fry
    bcc :+
    A16
    lda #SPR_CADEADO
    sta spr_tile
    A8
    jsr AddSprite
    jmp @next
:   cmp d_broke
    bne :+
    A16
    lda #SPR_XIS
    sta spr_tile
    A8
    jsr AddSprite
    jmp @next
:   lda f_state,x
    bne :+
    jmp @next
:   A16
    lda f_prog,y
    xba
    and #$00FF
    sta tmp
    A8
    ; pastel conforme o ponto
    lda tmp
    jsr Quality
    sta tmp2
    lda #$32
    sta spr_attr
    A16
    lda #SPR_PASTEL_1
    sta spr_tile
    A8
    lda tmp
    cmp #110
    bcs :+
    A16
    lda #SPR_PASTEL_0
    sta spr_tile
    A8
:   lda tmp2
    cmp #Q_QUEIM
    bne :+
    A16
    lda #SPR_PASTEL_2
    sta spr_tile
    A8
:   ; brilho quando perfeito (antes do pastel = na frente)
    lda tmp2
    cmp #Q_PERF
    bne @nospark
    lda frame
    and #$10
    beq @nospark
    A16
    lda spr_tile
    pha
    lda #SPR_BRILHO
    sta spr_tile
    A8
    lda #(PASTEL_Y-6)
    sta spr_y
    jsr AddSprite
    lda #PASTEL_Y
    sta spr_y
    A16
    pla
    sta spr_tile
    A8
@nospark:
    lda tmp2
    cmp #Q_QUEIM
    bne @nosmoke
    A16
    lda spr_tile
    pha
    lda #SPR_FUMACA
    sta spr_tile
    A8
    lda frame
    lsr a
    lsr a
    and #$07
    eor #$FF
    clc
    adc #(PASTEL_Y-10)
    sta spr_y
    jsr AddSprite
    lda #PASTEL_Y
    sta spr_y
    A16
    pla
    sta spr_tile
    A8
@nosmoke:
    lda #$32
    sta spr_attr
    jsr AddSprite
    ; barra de fritura (cor: verde=perfeito, vermelho=queimado, amarelo=outros)
    lda tmp
    lsr a
    lsr a
    lsr a
    lsr a
    sta tmp
    ldy #9
    lda tmp2
    cmp #Q_PERF
    bne :+
    ldy #0
:   cmp #Q_QUEIM
    bne :+
    ldy #18
:   sty tmp2
    lda #FBAR_Y
    sta spr_y
    A16
    lda tmp4
    sta spr_x
    A8
    jsr DrawBar
@next:
    ldx tmp3
    inx
    cpx #4
    beq :+
    jmp @lp
:   rts
BasketX: .word 142, 170, 198, 226
