; =====================================================================
;  Audio gravado (BRR): falas na voz 7 e musica na voz 1
;   - falas fixas: ja estao na memoria do SPC700 (carregadas na abertura)
;   - falas em stream e a musica: os blocos BRR saem da ROM e vao para um
;     anel na memoria do SPC700 enquanto tocam (anel B = falas, A = musica).
;     O envio usa o tempo ocioso de cada quadro (Bomba, no WaitFrame) e e em
;     pipeline: o CPU prepara os proximos 3 bytes enquanto o SPC700 grava.
;   Tabelas e constantes: gen/voz.inc e gen/assets.inc (gerador/sons.js).
; =====================================================================

LOTE_MAX = 72               ; bytes por lote (24 trios, ~2 ms): reparte o tempo ocioso

; Lote: manda trios direto da ROM ([ptr],y), sem eventos no meio (o chamador ja
; limitou o tamanho: X = bytes que podem ir). Busca os 3 bytes seguintes enquanto o
; SPC700 grava os anteriores e para quando o quadro acaba (NMI). Sai com Y = bytes
; enviados (multiplo de 3).
.macro LOTE ptr, modo
    ldy #0                  ; (rotulos anonimos: rotulos normais quebrariam os @locais)
:   lda [ptr],y
    sta lt_b0
    iny
    lda [ptr],y
    sta lt_b1
    iny
    lda [ptr],y
    sta lt_b2
    iny
    lda apu_ult
:   cmp APUIO0
    bne :-
    lda lt_b0
    sta APUIO1
    lda lt_b1
    sta APUIO2
    lda lt_b2
    sta APUIO3
    lda apu_cnt
    inc a
    and #$3F
    sta apu_cnt
    ora #modo
    sta apu_ult
    sta APUIO0
    dex
    dex
    dex
    cpx #3
    bcc :+
    lda nmi_ready           ; o quadro acabou: devolve o tempo ao jogo
    bne :--
:
.endmacro

; envia 3 bytes (vz_tri) ao ponteiro A (A = $80) ou B (A = $C0); nao espera a
; confirmacao (o proximo envio espera)
ApuTrio:
    .a8
    .i16
    sta vz_modo
    APU_ESPERA
    lda vz_tri
    sta APUIO1
    lda vz_tri+1
    sta APUIO2
    lda vz_tri+2
    sta APUIO3
    lda apu_cnt
    inc a
    and #$3F
    sta apu_cnt
    ora vz_modo             ; bits 7/6: dados para o ponteiro A ou B
    sta apu_ult
    sta APUIO0
    rts

; X = endereco na memoria do SPC700 para o ponteiro A ou B
ApuPonteiroA:
    .a8
    .i16
    lda #$80
    bra :+
ApuPonteiroB:
    .a8
    .i16
    lda #$81
:   pha
    APU_ESPERA
    pla
    sta APUIO1
    stx APUIO2
    jmp DspEnvia

; le um byte da ROM em [vz_ptr] e avanca (passa de banco em $FFFF -> $8000)
VozLeRom:
    .a8
    .i16
    lda [vz_ptr]
    pha
    A16
    inc vz_ptr
    bne :+
    lda #$8000
    sta vz_ptr
    A8
    inc vz_ptr+2
:   A8
    pla
    rts

; ---------------------------------------------------------------- inicio
; boot: comeca a carga das vozes fixas e do chiado (ponteiro A). Ela segue no
; tempo ocioso dos quadros, durante a abertura; ate acabar nada toca
; (VozCargaFim termina na hora, se precisar)
VozInit:
    .a8
    .i16
    ldx #FIXAS_ARAM
    jsr ApuPonteiroA
    ldx #.loword(FIXAS_ROM)
    stx vz_ptr
    lda #^FIXAS_ROM
    sta vz_ptr+2
    ldx #(FIXAS_LEN / 3)
    stx vz_carga
    ; voz 7 (falas): volume 3/4, GAIN direto (sem envelope)
    DSP $70, $60
    DSP $71, $60
    DSP $75, $00
    DSP $77, $7F
    lda #$FF
    sta vz_cur
    stz vz_est
    stz mu_est
    ldx #0
    A16
    lda #$8000              ; "tocou ha muito tempo"
:   sta vz_ultima,x
    inx
    inx
    cpx #(VOZ_N * 2)
    bne :-
    A8
    rts

; um trio da carga das vozes fixas
VozCargaTrio:
    .a8
    .i16
    jsr VozLeRom
    sta vz_tri
    jsr VozLeRom
    sta vz_tri+1
    jsr VozLeRom
    sta vz_tri+2
    lda #$80
    jsr ApuTrio
    ldx vz_carga
    dex
    stx vz_carga
    rts

; termina a carga das vozes fixas agora (ex.: o jogador pulou a abertura)
VozCargaFim:
    .a8
    .i16
:   ldx vz_carga
    beq :+
    jsr VozCargaTrio
    bra :-
:   rts

; chamada sem parar enquanto o quadro espera o NMI (um trio por chamada)
Bomba:
    .a8
    .i16
    ldx vz_carga            ; primeiro a carga das vozes fixas
    beq :+
    jmp VozCargaTrio
:   ldx vz_anel             ; falas primeiro: se mandaram um lote, a musica espera a
    stx lt_ant              ; proxima volta (ela tem 0,5 s de folga para atravessar)
    jsr VozBomba
    ldx vz_anel
    cpx lt_ant
    bne :+
    jmp MusBomba
:   rts

; ---------------------------------------------------------------- falas
; A = voz (VOZ_*): toca, respeitando prioridade e o tempo sem repetir
VozToca:
    .a8
    .i16
    ldx vz_carga            ; vozes fixas ainda carregando: nada toca
    beq :+
    rts
:   xba                     ; (a voz fica no B)
    lda opt_falas           ; falas desligadas nas opcoes: nada toca
    bne :+
    rts
:   xba
:   sta vz_tmp
    A16
    and #$00FF
    tax
    A8
    lda vz_cur              ; outra tocando: so interrompe se esta for tao importante
    cmp #$FF
    beq :+
    lda f:VozPri,x
    cmp vz_pri
    bcs :+
    rts
:   A16                     ; a mesma voz ha pouco tempo: nao repete
    txa
    asl a
    tay
    lda frame
    sec
    sbc vz_ultima,y
    phx
    tyx
    cmp f:VozEspera,x
    plx
    bcs :+
    A8
    rts
:   lda frame
    sta vz_ultima,y
    A8
    lda vz_tmp
    sta vz_cur
    lda f:VozPri,x
    sta vz_pri
    stz vz_est
    ; registradores da voz 7: sample e afinacao
    lda f:VozSrcn,x
    xba
    lda #$74
    jsr @dsp
    phx
    tyx
    lda f:VozPitch,x
    plx
    xba
    lda #$72
    jsr @dsp
    phx
    tyx
    lda f:VozPitch+1,x
    plx
    xba
    lda #$73
    jsr @dsp
    lda f:VozTipo,x
    bne @stream
    ; fixa: liga a voz ja
    A16
    phx
    tyx
    lda f:VozQuadros,x
    plx
    sta vz_resto
    A8
    lda #$80
    jmp VozesLiga
@stream:
    phx
    phy
    jsr VozFonte
    ply
    plx
    A16
    phx
    tyx
    lda f:VozBpq,x
    plx
    sta vz_bpq
    phx
    tyx
    lda f:VozFolga,x
    plx
    sta vz_folga
    stz vz_anel
    stz vz_nivel
    A8
    stz vz_nivel+2
    stz vz_fim
    lda #$80                ; para a voz enquanto o anel enche
    jsr VozesDesliga
    ldx #FALA_ARAM          ; ponteiro B no inicio do anel das falas
    jsr ApuPonteiroB
    DSP $7C, $00            ; limpa o ENDX (avisa quando a voz da a volta no anel)
    lda #1
    sta vz_est              ; enchendo: a VozBomba liga a voz quando tiver a folga
    rts
@dsp:                       ; DspWrite preservando X e Y
    phx
    phy
    tax
    jsr DspWrite
    ply
    plx
    rts

; ponteiro e tamanho da fonte da fala vz_cur -> vz_ptr / vz_resta
VozFonte:
    .a8
    .i16
    lda vz_cur
    A16
    and #$00FF
    sta vz_tmp2
    asl a
    clc
    adc vz_tmp2             ; * 3 (.faraddr)
    tax
    lda f:VozRom,x
    sta vz_ptr
    lda f:VozLen,x
    sta vz_resta
    A8
    lda f:VozRom+2,x
    sta vz_ptr+2
    lda f:VozLen+2,x
    sta vz_resta+2
    rts

; para a fala
VozPara:
    .a8
    .i16
    lda vz_cur
    cmp #$FF
    beq :+
    lda #$FF
    sta vz_cur
    stz vz_est
    lda #$80
    jsr VozesDesliga
:   rts

; proximos 3 bytes da fala em vz_tri (silencio depois do fim)
VozTrio:
    .a8
    .i16
    lda vz_fim
    bne @zero
    ; caminho rapido: 3+ bytes e sem troca de banco no meio
    lda vz_resta+2
    bne @rapido
    A16
    lda vz_resta
    cmp #3
    A8
    bcc @lento
@rapido:
    A16
    lda vz_ptr
    cmp #$FFFE
    A8
    bcs @lento
    ldy #0
    lda [vz_ptr],y
    sta vz_tri
    iny
    lda [vz_ptr],y
    sta vz_tri+1
    iny
    lda [vz_ptr],y
    sta vz_tri+2
    A16
    lda vz_ptr
    clc
    adc #3
    sta vz_ptr
    bcc :+
    lda #$8000
    sta vz_ptr
    A8
    inc vz_ptr+2
    A16
:   lda vz_resta
    sec
    sbc #3
    sta vz_resta
    A8
    lda vz_resta+2
    sbc #0
    sta vz_resta+2
    rts
@lento:
    jsr @byte
    sta vz_tri
    jsr @byte
    sta vz_tri+1
    jsr @byte
    sta vz_tri+2
    rts
@zero:
    stz vz_tri
    stz vz_tri+1
    stz vz_tri+2
    ldx vz_sil              ; silencio de cauda enviado
    inx
    inx
    inx
    stx vz_sil
    rts
@byte:
    lda vz_fim
    bne @b0
    lda vz_resta
    ora vz_resta+1
    ora vz_resta+2
    bne @b1
    lda #1                  ; acabou: guarda o que ainda falta tocar
    sta vz_fim
    ldx #0
    stx vz_sil
    A16
    lda vz_nivel
    sta vz_cauda
    A8
    lda vz_nivel+2
    sta vz_cauda+2
@b0:
    lda #0
    rts
@b1:
    A16
    lda vz_resta
    sec
    sbc #1
    sta vz_resta
    A8
    lda vz_resta+2
    sbc #0
    sta vz_resta+2
    jmp VozLeRom

; manda 3 bytes da fala se o anel estiver abaixo da folga
; vz_nivel (16.8) = bytes no anel ainda nao tocados
VozBomba:
    .a8
    .i16
    lda vz_est
    bne :+
    rts
:   lda vz_fim              ; depois do fim da fala bastam ~2 quadros de silencio
    beq :+                  ; (ate a voz ser desligada): nao toma o tempo da musica
    ldx vz_sil
    cpx #300
    bcc :+
    rts
:   A16
    lda vz_nivel+1
    cmp vz_folga
    A8
    bcc :+
    rts
:   lda vz_fim              ; lote (como na musica), menos no fim da fala
    beq :+
    jmp @lento
:   A16
    lda vz_anel             ; o bloco final do anel (com flag) vai pelo caminho lento
    cmp #(FALA_LEN - 9)
    bne :+
    A8
    jmp @lento
    .a16
:   bcc :+
    lda #FALA_LEN
    bra :++
:   lda #(FALA_LEN - 9)
:   sec
    sbc vz_anel
    sta lt_n
    lda vz_folga
    sec
    sbc vz_nivel+1
    cmp lt_n
    bcs :+
    sta lt_n
:   lda #0                  ; ate o fim do banco
    sec
    sbc vz_ptr
    beq :+
    cmp lt_n
    bcs :+
    sta lt_n
:   ldx vz_resta+1          ; fim da fala
    cpx #$0100
    bcs :+
    lda vz_resta
    cmp lt_n
    bcs :+
    sta lt_n
:   lda lt_n
    cmp #LOTE_MAX           ; lote de no maximo LOTE_MAX: falas e musica se revezam
    bcc :+
    lda #LOTE_MAX
    sta lt_n
:   cmp #3
    bcs :+
    A8
    jmp @lento
:   A8
    ldx lt_n
    LOTE vz_ptr, $C0
    A16
    tya
    sta lt_n
    clc
    adc vz_ptr
    sta vz_ptr
    bne :+                  ; terminou no fim do banco ($FFFF): passa ao proximo
    lda #$8000
    sta vz_ptr
    A8
    inc vz_ptr+2
    A16
:
    lda vz_resta
    sec
    sbc lt_n
    sta vz_resta
    A8
    lda vz_resta+2
    sbc #0
    sta vz_resta+2
    A16
    lda vz_anel
    clc
    adc lt_n
    bra @conta
    .a8
@lento:
    jsr VozTrio
    A16                     ; ultimo bloco do anel: fim + loop
    lda vz_anel
    cmp #(FALA_LEN - 9)
    A8
    bne :+
    lda vz_tri
    ora #$03
    sta vz_tri
:   lda #$C0
    jsr ApuTrio
    A16
    lda #3
    sta lt_n
    lda vz_anel
    clc
    adc #3
@conta:                     ; A16: A = nova posicao no anel, lt_n = bytes enviados
    cmp #FALA_LEN
    bcc @nv
    A8                      ; deu a volta: ponteiro B no inicio do anel
    ldx #FALA_ARAM
    jsr ApuPonteiroB
    A16
    lda #0
@nv:
    sta vz_anel
    lda vz_nivel+1
    clc
    adc lt_n
    sta vz_nivel+1
    A8
    lda vz_est              ; enchendo e chegou na folga: liga a voz
    cmp #1
    bne :+
    A16
    lda vz_nivel+1
    cmp vz_folga
    A8
    bcc :+
    lda #2
    sta vz_est
    lda #$80
    jsr VozesLiga
:   rts

; uma vez por quadro: o que tocou sai do nivel; fim da fala
VozQuadro:
    .a8
    .i16
    lda vz_cur
    cmp #$FF
    bne :+
    rts
:   lda vz_est
    bne @stream
    A16                     ; fixa: conta os quadros ate acabar
    lda vz_resto
    beq :+
    dec a
    sta vz_resto
:   A8
    bne :+
    lda #$FF
    sta vz_cur
:   rts
@stream:
    cmp #2
    beq :+
    rts                     ; ainda enchendo
:   A16
    lda vz_nivel
    sec
    sbc vz_bpq
    sta vz_nivel
    A8
    lda vz_nivel+2
    sbc #0
    sta vz_nivel+2
    bcs :+
    stz vz_nivel
    stz vz_nivel+1
    stz vz_nivel+2
:   lda apu_endx            ; ENDX (do ultimo comando de DSP): voz 7 deu a volta
    bpl @sem
    A16                     ; a volta pode ter sido ate 1 quadro antes (o ENDX chega
    lda vz_bpq              ; no status do proximo comando): desconta 1 quadro tocado
    xba
    and #$00FF              ; bytes inteiros por quadro
    sta lt_n
    lda vz_anel             ; escrita perto da folga: ja deu a volta (normal); perto
    cmp #(FALA_LEN * 3 / 4) ; do fim do anel: ainda nao (a leitura passou: vazio)
    bcs @zr
    sec
    sbc lt_n
    bcs :+
@zr:
    lda #0
:   sta vz_nivel+1
    A8
    DSP $7C, $00
@sem:
    lda vz_fim
    beq @r
    A16
    lda vz_cauda
    sec
    sbc vz_bpq
    sta vz_cauda
    A8
    lda vz_cauda+2
    sbc #0
    sta vz_cauda+2
    bcs @r
    jsr VozPara
@r: rts

; ---------------------------------------------------------------- musica
; musica gravada em loop na voz 1 (VOZ_TEMA): no titulo e no expediente.
; Liga com MusToca e para com MusPara (PlaySong e StopMusic param tambem)
MusToca:
    .a8
    .i16
    lda mu_est
    beq :+
    rts                     ; ja tocando: continua
:   lda opt_music
    bne :+
    rts
:   jsr VozCargaFim         ; (a carga das fixas usa o mesmo ponteiro A)
    jsr MusFonte
    lda #$02                ; para a voz enquanto o anel enche
    jsr VozesDesliga
    DSP $10, $48            ; volume abaixo das falas
    DSP $11, $48
    DSP $15, $00            ; GAIN direto
    DSP $17, $7F
    DSP $14, SRCN_MUSICA
    lda f:VozPitch+(VOZ_TEMA*2)
    xba
    lda #$12
    tax
    jsr DspWrite
    lda f:VozPitch+(VOZ_TEMA*2)+1
    xba
    lda #$13
    tax
    jsr DspWrite
    ldx #MUSICA_ARAM
    jsr ApuPonteiroA
    DSP $7C, $00
    ldx #0
    stx mu_anel
    stx mu_nivel
    stz mu_nivel+2
    lda #1
    sta mu_est
    rts

MusFonte:
    .a8
    .i16
    A16
    lda f:VozRom+(VOZ_TEMA*3)
    sta mu_ptr
    lda f:VozLen+(VOZ_TEMA*3)
    sta mu_resta
    A8
    lda f:VozRom+(VOZ_TEMA*3)+2
    sta mu_ptr+2
    lda f:VozLen+(VOZ_TEMA*3)+2
    sta mu_resta+2
    rts

MusPara:
    .a8
    .i16
    lda mu_est
    beq :+
    stz mu_est
    lda #$02
    jsr VozesDesliga
:   rts

; proximos 3 bytes da musica (recomeca no fim; o tamanho e multiplo de 9)
MusTrio:
    .a8
    .i16
    lda mu_resta
    ora mu_resta+1
    ora mu_resta+2
    bne :+
    jsr MusFonte
:   A16
    lda mu_ptr
    cmp #$FFFE
    A8
    bcs @lento
    ldy #0
    lda [mu_ptr],y
    sta vz_tri
    iny
    lda [mu_ptr],y
    sta vz_tri+1
    iny
    lda [mu_ptr],y
    sta vz_tri+2
    A16
    lda mu_ptr
    clc
    adc #3
    sta mu_ptr
    bcc @dec
    lda #$8000
    sta mu_ptr
    A8
    inc mu_ptr+2
    bra @dec8
@lento:                     ; troca de banco no meio do trio
    ldx #0
@lb:
    lda [mu_ptr]
    sta vz_tri,x
    A16
    inc mu_ptr
    bne @nb
    lda #$8000
    sta mu_ptr
    A8
    inc mu_ptr+2
@nb:
    A8
    inx
    cpx #3
    bne @lb
@dec8:
    A16
@dec:
    lda mu_resta
    sec
    sbc #3
    sta mu_resta
    A8
    lda mu_resta+2
    sbc #0
    sta mu_resta+2
    rts

MusBomba:
    .a8
    .i16
    lda mu_est
    bne :+
    rts
:   A16
    lda mu_nivel+1
    cmp f:VozFolga+(VOZ_TEMA*2)
    A8
    bcc :+
    rts
:   ; lote: quantos bytes podem ir sem evento (folga, fim do anel, fim da musica, banco)
    lda mu_resta
    ora mu_resta+1
    ora mu_resta+2
    bne :+
    jsr MusFonte            ; recomeca a musica
:   A16
    lda mu_anel             ; o bloco final do anel (com flag) vai pelo caminho lento
    cmp #(MUSICA_LEN - 9)
    bne :+
    A8
    jmp @lento
    .a16
:   bcc :+                  ; antes dele: o lote vai ate ele
    lda #MUSICA_LEN
    bra :++
:   lda #(MUSICA_LEN - 9)
:   sec
    sbc mu_anel
    sta lt_n
    lda f:VozFolga+(VOZ_TEMA*2)
    sec
    sbc mu_nivel+1
    cmp lt_n
    bcs :+
    sta lt_n
:   lda #0                  ; ate o fim do banco
    sec
    sbc mu_ptr
    beq :+                  ; (ptr = $0000 nao acontece; $8000.. sempre)
    cmp lt_n
    bcs :+
    sta lt_n
:   ldx mu_resta+1          ; fim da musica (so se faltar menos de 64 KB)
    cpx #$0100
    bcs :+
    lda mu_resta
    cmp lt_n
    bcs :+
    sta lt_n
:   lda lt_n
    cmp #LOTE_MAX           ; lote de no maximo LOTE_MAX: falas e musica se revezam
    bcc :+
    lda #LOTE_MAX
    sta lt_n
:   cmp #3
    bcs :+
    A8
    jmp @lento
:   A8
    ldx lt_n
    LOTE mu_ptr, $80
    A16
    tya
    sta lt_n
    clc
    adc mu_ptr
    sta mu_ptr
    bne :+                  ; terminou no fim do banco ($FFFF): passa ao proximo
    lda #$8000
    sta mu_ptr
    A8
    inc mu_ptr+2
    A16
:
    lda mu_resta
    sec
    sbc lt_n
    sta mu_resta
    A8
    lda mu_resta+2
    sbc #0
    sta mu_resta+2
    A16
    lda mu_anel
    clc
    adc lt_n
    bra @conta
    .a8
@lento:
    jsr MusTrio
    A16                     ; ultimo bloco do anel: fim + loop
    lda mu_anel
    cmp #(MUSICA_LEN - 9)
    A8
    bne :+
    lda vz_tri
    ora #$03
    sta vz_tri
:   lda #$80
    jsr ApuTrio
    A16
    lda #3
    sta lt_n
    lda mu_anel
    clc
    adc #3
@conta:                     ; A16: A = nova posicao no anel, lt_n = bytes enviados
    cmp #MUSICA_LEN
    bcc @nv
    A8
    ldx #MUSICA_ARAM
    jsr ApuPonteiroA
    A16
    lda #0
@nv:
    sta mu_anel
    lda mu_nivel+1
    clc
    adc lt_n
    sta mu_nivel+1
    A8
    lda mu_est
    cmp #1
    bne :+
    A16
    lda mu_nivel+1
    cmp f:VozFolga+(VOZ_TEMA*2)
    A8
    bcc :+
    lda #2
    sta mu_est
    lda #$02
    jsr VozesLiga
:   rts

MusQuadro:
    .a8
    .i16
    lda mu_est
    cmp #2
    beq :+
    rts
:   A16
    lda mu_nivel
    sec
    sbc f:VozBpq+(VOZ_TEMA*2)
    sta mu_nivel
    A8
    lda mu_nivel+2
    sbc #0
    sta mu_nivel+2
    bcs :+
    stz mu_nivel
    stz mu_nivel+1
    stz mu_nivel+2
:   lda apu_endx            ; ENDX: voz 1 deu a volta no anel
    and #$02
    beq :+
    A16                     ; (como nas falas: desconta 1 quadro tocado)
    lda f:VozBpq+(VOZ_TEMA*2)
    xba
    and #$00FF
    sta lt_n
    lda mu_anel
    cmp #(MUSICA_LEN * 3 / 4)
    bcs @zr
    sec
    sbc lt_n
    bcs @ok
@zr:
    lda #0
@ok:
    sta mu_nivel+1
    A8
    DSP $7C, $00
:   rts
