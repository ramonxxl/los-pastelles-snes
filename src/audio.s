; =====================================================================
;  Audio: envia o driver ao SPC700 e toca musicas/efeitos escrevendo
;  diretamente nos registradores do DSP (via driver "proxy").
;  Vozes 0-2 = musica, 3-5 = efeitos, 6 = ruido (fritura)
; =====================================================================

; envia o bloco SpcBlob para $0200 via IPL e executa
ApuUpload:
    .a8
    .i16
    ldx #$BBAA
@w1:
    cpx APUIO0
    bne @w1
    ldx #$0200
    stx APUIO2
    lda #$01
    sta APUIO1
    lda #$CC
    sta APUIO0
@w2:
    cmp APUIO0
    bne @w2
    ldx #0
@byte:
    lda f:SpcBlob,x
    sta APUIO1
    txa
    sta APUIO0
@w3:
    cmp APUIO0
    bne @w3
    inx
    cpx #SPC_SIZE
    bne @byte
    ldy #$0200
    sty APUIO2
    stz APUIO1
    txa
    inc a
    sta APUIO0
@w4:
    cmp APUIO0
    bne @w4
    sta apu_cnt
    sta apu_ult
    lda #$D5                ; espera o driver avisar que esta pronto
@w5:
    cmp APUIO1
    bne @w5
    rts

; espera o SPC700 confirmar o envio anterior (os dados vao em pipeline)
.macro APU_ESPERA
    .local w
    lda apu_ult
w:  cmp APUIO0
    bne w
.endmacro

; X = (valor << 8) | registrador
DspWrite:
    .a8
    .i16
    APU_ESPERA
    stx APUIO1
DspEnvia:
    lda apu_cnt
    inc a
    and #$3F                ; bits 7/6 da porta 0 = 0: comando (dados: ApuTrio)
    sta apu_cnt
    sta apu_ult
    sta APUIO0
@w: cmp APUIO0
    bne @w
    rts

.macro DSP reg, val
    ldx #(((val) << 8) | (reg))
    jsr DspWrite
.endmacro

AudioInit:
    .a8
    .i16
    DSP $6C, $20        ; FLG: eco desligado
    DSP $4C, $00        ; KON
    lda #$FF            ; KOF em todas (fica ate o 1o AudioUpdate)
    jsr VozesDesliga
    DSP $0C, $58        ; volume mestre
    DSP $1C, $58
    DSP $2C, $00        ; volume do eco
    DSP $3C, $00
    DSP $2D, $00        ; PMON
    DSP $3D, $00        ; NON: sem ruido (o chiado agora e gravado)
    DSP $5D, $03        ; DIR = $0300
    DSP $6D, (ECO_ARAM >> 8) ; ESA (buffer do eco)
    DSP $7D, $02        ; EDL = 32 ms ($D000-$DFFF; o resto e o anel das falas)
    DSP $0D, $38        ; feedback do eco
    DSP $4D, $05        ; eco nas vozes 0 (melodia) e 2 (acordes)
    DSP $0F, $7F        ; filtro FIR
    DSP $1F, $00
    DSP $2F, $00
    DSP $3F, $00
    DSP $4F, $00
    DSP $5F, $00
    DSP $6F, $00
    DSP $7F, $00
    ; voz 6: chiado da fritura (gravado, em loop)
    DSP $64, SRCN_FRITURA
    DSP $65, $FF
    DSP $66, $E0
    DSP $60, $16
    DSP $61, $16
    DSP $62, <FRITURA_PITCH
    DSP $63, >FRITURA_PITCH
    DSP $6C, $3B        ; FLG: eco desligado + clock do ruido
    ldx #0
@c: stz ch_on,x
    inx
    cpx #6
    bne @c
    lda #3
    sta sfx_next
    jmp VozInit             ; vozes fixas na memoria do SPC700

; toca musica A (reinicia so se for diferente da atual)
PlaySong:
    .a8
    .i16
    cmp cur_song
    bne :+
    rts
:   pha                     ; outra musica: a gravada para
    jsr MusPara
    pla
    sta cur_song
    lda opt_music
    bne :+
    stz ch_on
    stz ch_on+1
    stz ch_on+2
    lda #$07
    jmp VozesDesliga
:   ; liga o eco na primeira musica (o driver zerou o buffer, e o EDL novo ja vale)
    lda echo_on
    bne :+
    lda #1
    sta echo_on
    DSP $6C, $1B        ; FLG: escrita do eco ligada + clock do ruido
    DSP $2C, $1C        ; volume do eco
    DSP $3C, $1C
:   lda cur_song
    A16
    and #$00FF
    sta tmp
    asl a
    clc
    adc tmp
    asl a
    tay
    ldx #0
@l: lda SongTable,y
    sta ch_ptr,x
    sta ch_loop,x
    iny
    iny
    inx
    inx
    cpx #6
    bne @l
    A8
    lda #1
    sta ch_on
    sta ch_on+1
    sta ch_on+2
    stz ch_wait
    stz ch_wait+1
    stz ch_wait+2
    lda #$07
    tsb kof_pend
    rts

StopMusic:
    .a8
    .i16
    jsr MusPara             ; musica desligada: a gravada tambem
    stz ch_on
    stz ch_on+1
    stz ch_on+2
    lda #$FF
    sta cur_song
    lda #$07
    jmp VozesDesliga

; efeito sonoro A
PlaySfx:
    .a8
    .i16
    A16
    and #$00FF
    asl a
    tay
    A8
    A16
    lda sfx_next
    and #$00FF
    sta ch_x
    asl a
    tax
    lda SfxTable,y
    sta ch_ptr,x
    sta ch_loop,x
    A8
    ldx ch_x
    lda #1
    sta ch_on,x
    stz ch_wait,x
    lda sfx_next
    inc a
    cmp #6
    bcc :+
    lda #3
:   sta sfx_next
    rts

; chamada uma vez por quadro
AudioUpdate:
    .a8
    .i16
    lda APUIO1              ; ENDX do ultimo comando de DSP (falas e musica usam)
    sta apu_endx
    jsr VozQuadro
    jsr MusQuadro
    stz kon_pend            ; (o kof_pend junta o quadro todo e so zera depois de escrito)
    ldx #0
@ch:
    lda ch_on,x
    beq @next
    lda ch_wait,x
    beq @read
    dec ch_wait,x
    bne @next
@read:
    phx
    jsr ChannelRead
    plx
@next:
    inx
    cpx #6
    bne @ch
    ; fritura (voz 6)
    lda sizzle_want
    cmp sizzle_on
    beq @nosz
    sta sizzle_on
    lda sizzle_on
    beq @szoff
    lda #$40
    tsb kon_pend
    bra @nosz
@szoff:
    lda #$40
    tsb kof_pend
@nosz:
    lda kof_pend            ; o KOF fica escrito ate o proximo quadro
    sta kof_atual
    stz kof_pend
    jsr KofEscreve
    lda kon_pend
    beq @nokon
    jmp KonEscreve
@nokon:
    rts

; O DSP so le o KOF e o KON a cada 2 amostras (~64 us). No console um KOF desfeito
; antes disso nao desligava a voz (a fala ficava em loop no anel, um chiado sem fim),
; e um KON escrito logo depois de outro apagava o primeiro. Por isso:
;  - o KOF so baixa no AudioUpdate seguinte (kof_atual guarda o que esta escrito);
;  - depois de cada KON espera o DSP ler.

; A = vozes: desliga agora e mantem desligadas ate o proximo AudioUpdate
VozesDesliga:
    .a8
    .i16
    tsb kof_pend
    tsb kof_atual
    lda kof_atual
    bra KofEscreve

; A = vozes: tira do KOF e liga
VozesLiga:
    .a8
    .i16
    pha
    trb kof_pend
    trb kof_atual
    lda kof_atual
    jsr KofEscreve
    pla
KonEscreve:                 ; A = KON; espera o DSP ler (preserva X e Y)
    .a8
    .i16
    phx
    phy
    xba
    lda #$4C
    tax
    jsr DspWrite
    ldy #100                ; ~100 us com o CPU rapido (2 amostras = 63 us)
:   dey
    bne :-
    ply
    plx
    rts

KofEscreve:                 ; A = KOF (preserva X e Y)
    .a8
    .i16
    phx
    xba
    lda #$5C
    tax
    jsr DspWrite
    plx
    rts

; le eventos do canal X ate encontrar nota/pausa
ChannelRead:
    .a8
    .i16
    stx ch_x
    A16
    txa
    asl a
    sta ch_x2
    tax
    lda ch_ptr,x
    sta mptr
    A8
    ldy #0
@cmd:
    lda (mptr),y
    iny
    cmp #$F0
    bcc @note
    beq @inst
    cmp #$F1
    beq @vol
    cmp #$FE
    beq @loop
    ; $FF = fim
    ldx ch_x
    stz ch_on,x
    lda VoiceBit,x
    tsb kof_pend
    rts
@loop:
    ldx ch_x2
    A16
    lda ch_loop,x
    sta mptr
    A8
    ldy #0
    bra @cmd
@inst:
    lda (mptr),y
    iny
    phy
    jsr SetInstrument
    ply
    bra @cmd
@vol:
    lda (mptr),y
    iny
    phy
    jsr SetVolume
    ply
    bra @cmd
@note:
    sta tmp_note
    lda (mptr),y
    iny
    ldx ch_x
    sta ch_wait,x
    A16
    tya
    clc
    adc mptr
    ldx ch_x2
    sta ch_ptr,x
    A8
    lda tmp_note
    beq @rest
    jmp NoteOn
@rest:
    ldx ch_x
    lda VoiceBit,x
    tsb kof_pend
    rts

VoiceReg:
    .a8
    .i16
    lda ch_x
    asl a
    asl a
    asl a
    asl a
    sta tmp_vreg
    rts

NoteOn:
    .a8
    .i16
    A16
    and #$00FF
    asl a
    tax
    lda PitchTable,x
    sta tmp_pitch
    A8
    jsr VoiceReg
    lda tmp_pitch
    xba
    lda tmp_vreg
    ora #$02
    tax
    jsr DspWrite
    lda tmp_pitch+1
    xba
    lda tmp_vreg
    ora #$03
    tax
    jsr DspWrite
    ldx ch_x
    lda VoiceBit,x
    tsb kon_pend
    trb kof_pend
    rts

; A = instrumento
SetInstrument:
    .a8
    .i16
    A16
    and #$00FF
    sta tmp_pitch
    asl a
    clc
    adc tmp_pitch
    tay
    A8
    jsr VoiceReg
    lda InstTable,y
    xba
    lda tmp_vreg
    ora #$04
    tax
    jsr DspWrite
    lda InstTable+1,y
    xba
    lda tmp_vreg
    ora #$05
    tax
    jsr DspWrite
    lda InstTable+2,y
    xba
    lda tmp_vreg
    ora #$06
    tax
    jsr DspWrite
    rts

; A = volume
SetVolume:
    .a8
    .i16
    sta tmp_note
    jsr VoiceReg
    lda tmp_note
    xba
    lda tmp_vreg
    tax
    jsr DspWrite
    lda tmp_note
    xba
    lda tmp_vreg
    ora #$01
    tax
    jsr DspWrite
    rts

VoiceBit: .byte $01, $02, $04, $08, $10, $20, $40, $80
