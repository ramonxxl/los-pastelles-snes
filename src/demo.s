; =====================================================================
;  Demonstracao: com o titulo parado 30 s, a CPU joga um expediente num
;  estagio sorteado (nivel/sabores, cestos, balcao, reforma, bairro...).
;  No fim do dia (ou se o jogador apertar qualquer botao) volta ao titulo.
;  Nada e salvo: a demo so usa a copia do jogo na RAM, e o titulo/slots
;  sempre leem os jogos salvos da SRAM de novo.
; =====================================================================

DEMO_OCIOSO = 1800          ; quadros parados no titulo ate a demo (30 s)
DEMO_HORA   = 14            ; o dia da demo comeca as 14h (~1 minuto)

; titulo: conta o tempo parado (chamada pelo TitleUpdate). carry = 1: comecou a demo
DemoTitulo:
    .a8
    .i16
    lda pad
    ora pad+1
    ora pad_new
    ora pad_new+1
    beq :+
    ldx #0                  ; mexeu: zera
    stx demo_ocioso
    clc
    rts
:   ldx demo_ocioso
    inx
    stx demo_ocioso
    cpx #DEMO_OCIOSO
    bcs :+
    clc
    rts
:   ldx #0
    stx demo_ocioso
    jsl DemoSorteia
    lda #1
    sta demo_on
    lda #ST_DAY
    sta next_state
    sec
    rts

; ajustes da demo no comeco do dia (chamada pelo SetupDay)
DemoDia:
    .a8
    .i16
    lda demo_on
    bne :+
    rts
:   ldx #$FFFF              ; nenhum cesto quebra
    stx d_breakat
    lda #DEMO_HORA
    sta d_hour
    rts

; a cada quadro, depois de ler o controle (laco principal): na demo, qualquer
; botao volta ao titulo; senao a CPU escolhe o botao; o fim do dia volta tambem
DemoControle:
    .a8
    .i16
    lda demo_on
    bne :+
    rts
:   lda next_state          ; o dia acabou (ia para o resultado): titulo
    cmp #ST_RESULTS
    beq @sai
    ldx pad_new             ; o jogador apertou alguma coisa
    beq :+
@sai:
    stz demo_on
    lda #ST_TITLE
    sta next_state
    ldx #0
    stx pad_new
    rts
:   lda state
    cmp #ST_DAY
    bne @nada
    lda msg_timer           ; aviso no HUD de tempos em tempos
    bne :+
    lda frame
    and #$3F
    bne :+
    ldx #TXT_DEMO
    jsr ShowMsg
:   lda frame               ; um botao a cada 4 quadros (ritmo de gente)
    and #$03
    bne @nada
    jsl DemoIA
    ldx demo_pad
    stx pad_new
    rts
@nada:
    ldx #0
    stx pad_new
    rts

; ---------------------------------------------------------------- a CPU jogando
; demo_pad = botao a apertar agora (0 = nada). Mesma ideia do robo de testes
; (teste/bot.lua): minijogo, tirar no ponto, entregar, comecar o que falta.
; Fica no banco 28 (o banco 0 esta cheio): chamada com JSL, volta com RTL; so
; le a RAM e tabelas que o DBR ($80) ja enxerga.
.segment "BANK28"
; estagio aleatorio (so na RAM; nao toca nos jogos salvos). Banco 28: JSL/RTL
DemoSorteia:
    .a8
    .i16
    lda #24                 ; nivel 1..24 (os sabores vem do nivel)
    jsr DemoRand
    inc a
    sta s_level
    lda #30                 ; dia 2..31 (sem o tutorial do dia 1)
    jsr DemoRand
    clc
    adc #2
    sta s_day
    stz s_day+1
    lda #3
    jsr DemoRand
    inc a
    sta s_fryer             ; 2..4 cestos
    lda #3
    jsr DemoRand
    inc a
    sta s_counter           ; 2..4 lugares
    lda #3
    jsr DemoRand
    sta s_reforma
    lda #5
    jsr DemoRand
    sta d_unit              ; bairro
    lda #2
    jsr DemoRand
    sta s_attend
    lda #2
    jsr DemoRand
    sta s_freezer
    lda #2
    jsr DemoRand
    sta s_ar
    lda #2
    jsr DemoRand
    sta s_unif
    lda #2
    jsr DemoRand
    sta s_musica
    lda #50
    jsr DemoRand
    clc
    adc #45
    sta s_rep
    ldx #99
    stx s_stock
    ldx #500
    stx s_money
    ldx #0
    stx s_money+2
    stz s_ads
    stz s_promo
    stz s_pc                ; sem pedidos do app (entregas ficam de fora)
    stz s_moto
    lda #1
    sta s_price
    lda #TUT_BIT            ; sem tutorial, sem modo festa
    sta s_tflags
    lda #$FF
    sta d_boss              ; dia comum
    stz d_event
    rtl

; A = n -> A = 0..n-1 (como o RandBelow, aqui no banco 28)
DemoRand:
    .a8
    .i16
    pha
    A16
    lda rng
    lsr a
    bcc :+
    eor #$B400
:   lsr a
    bcc :+
    eor #$B400
:   sta rng
    A8
    sta WRMPYA
    pla
    sta WRMPYB
    nop
    nop
    nop
    nop
    lda RDMPYL+1
    rts


DemoIA:
    .a8
    .i16
    ldx #0
    stx demo_pad
    lda mg_on               ; minijogo: o botao da vez
    beq @semmg
    lda mg_pos
    A16
    and #$00FF
    tax
    A8
    lda mg_seq,x
    A16
    and #$00FF
    asl a
    tax
    lda MgMask,x
    sta demo_pad
    A8
    rtl
@semmg:
    lda hold_flav
    cmp #$FF
    beq @livre
    lda hold_q              ; cru ou queimado: lixo
    beq @lixo
    cmp #Q_QUEIM
    bne @entrega
@lixo:
    ldx #(KH_B << 8)
    stx demo_pad
    rtl
@entrega:                   ; quem pediu esse sabor e ja esta esperando
    ldx #0
@cs:
    txa
    cmp n_cnt
    bcs @r
    lda c_state,x
    cmp #2
    bne @ncs
    lda c_order,x
    cmp hold_flav
    bne @ncs
    lda c_combo,x           ; combo: pega o refri antes
    beq :+
    lda c_qty,x
    cmp #2
    beq :+
    lda hold_soda
    bne :+
    ldx #KL_X
    stx demo_pad
    rtl
:   lda #0
    jmp DemoVai
@ncs:
    inx
    bra @cs
@r: rtl
@livre:                     ; algum pastel no ponto (ou queimando): tirar
    ldx #0
@cf:
    txa
    cmp n_fry
    bcs @falta
    lda f_state,x
    beq @ncf
    phx
    A16
    txa
    asl a
    tax
    lda f_prog,x
    A8
    xba
    plx
    cmp #168
    bcc @ncf
    txa
    clc
    adc n_flav
    tax
    lda #1
    jmp DemoVai
@ncf:
    inx
    bra @cf
@falta:                     ; cesto livre e estoque: o sabor que falta fritar
    ldx #0
@lv:
    txa
    cmp n_fry
    bcs @r
    lda f_state,x
    beq :+
    inx
    bra @lv
:   A16
    lda s_stock
    A8
    beq @r
    ldx #0                  ; falta[sabor] = pedidos - no oleo
:   stz demo_falta,x
    inx
    cpx #6
    bne :-
    ldx #0
@pd:
    txa
    cmp n_cnt
    bcs @fr
    lda c_state,x
    beq @npd
    cmp #3
    bcs @npd
    phx
    lda c_order,x
    tay
    lda c_qty,x
    clc
    adc demo_falta,y
    sta demo_falta,y
    plx
@npd:
    inx
    bra @pd
@fr:
    ldx #0
@fl:
    txa
    cmp n_fry
    bcs @esc
    lda f_state,x
    beq :+
    phx
    lda f_flav,x
    tay
    lda demo_falta,y
    dec a
    sta demo_falta,y
    plx
:   inx
    bra @fl
@esc:
    ldx #0
:   lda demo_falta,x
    beq @nf
    bmi @nf
    lda #1                  ; vai ate o sabor x na mesa
    jmp DemoVai
@nf:
    inx
    txa
    cmp n_flav
    bcc :-
    rtl

; A = fileira (0 balcao, 1 cozinha), X = coluna: anda ate la e aperta A
; (so chamada com jmp pela DemoIA: termina com RTL)
DemoVai:
    .a8
    .i16
    sta demo_lin
    txa
    sta demo_col
    lda cur_row
    cmp demo_lin
    beq @col
    ldx #(KH_UP << 8)
    lda demo_lin
    beq :+
    ldx #(KH_DOWN << 8)
:   stx demo_pad
    rtl
@col:
    lda demo_lin
    bne :+
    lda cur_col0
    bra :++
:   lda cur_col1
:   cmp demo_col
    beq @a
    ldx #(KH_LEFT << 8)
    bcs :+
    ldx #(KH_RIGHT << 8)
:   stx demo_pad
    rtl
@a: ldx #KL_A
    stx demo_pad
    rtl
.segment "CODE"
