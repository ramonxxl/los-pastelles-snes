; =====================================================================
;  Telas: titulo, abertura, cartas, resultados, loja, mapa, save
; =====================================================================

StateInit:
    .word TitleInit, IntroInit, CardInit, PreDayInit, DayInit, ResultsInit, ShopInit, MapInit, OptInit, ChooseInit, SlotsInit, SplashInit, TrofInit, SecretInit
StateUpdate:
    .word TitleUpdate, IntroUpdate, CardUpdate, NoUpdate, DayUpdate, ResultsUpdate, ShopUpdate, MapUpdate, OptUpdate, ChooseUpdate, SlotsUpdate, SplashUpdate, TrofUpdate, SecretUpdate

NoUpdate:
    .a8
    .i16
    rts

LoadMenuScene:
    .a8
    .i16
    lda #$80
    sta VMAIN
    VRAM_LOAD MenuTiles, VRAM_BG1TILES, (MenuTiles_end - MenuTiles)
    VRAM_LOAD MenuMap, VRAM_BG1MAP, 2048
    jsr LoadXadrez
    jsr LoadBasePalettes
    PAL_LOAD MenuPal, 32, 32
    PAL_LOAD ChkPal, 48, 32
    jmp UiPanelOn

; xadrez animado do fundo (BG2: tiles no fim da area do BG1, mapa, paleta 3)
LoadXadrez:
    .a8
    .i16
    VRAM_LOAD MenuChkTiles, MENU_CHK_VRAM, (MenuChkTiles_end - MenuChkTiles)
    VRAM_LOAD MenuChkMap, VRAM_BG2MAP, 2048
    rts

LoadLogoScene:
    .a8
    .i16
    lda #$80
    sta VMAIN
    jsr UiOff
    VRAM_LOAD LogoTiles, VRAM_BG1TILES, (LogoTiles_end - LogoTiles)
    VRAM_LOAD LogoMap, VRAM_BG1MAP, 2048
    jsr LoadXadrez          ; o xadrez aparece em volta da logo e do cartao
    jsr LoadBasePalettes
    PAL_LOAD LogoPal, 32, 32
    PAL_LOAD ChkPal, 48, 32
    ; icones (emojis) do menu: sprites, paletas OBJ 3..6
    VRAM_LOAD IconGfx, VRAM_OBJ, (IconGfx_end - IconGfx)
    PAL_LOAD IconPal, 176, 128
    rts

LoadTitleScene:
    .a8
    .i16
    lda #$80
    sta VMAIN
    jsr UiOff
    VRAM_LOAD TitleTiles, VRAM_BG1TILES, (TitleTiles_end - TitleTiles)
    VRAM_LOAD TitleMap, VRAM_BG1MAP, 2048
    jsr LoadBasePalettes
    PAL_LOAD TitlePal, 32, 32
    rts

; letreiro: A = 0 apagado, 1 aceso
SignLight:
    .a8
    .i16
    beq @off
    A16
    lda #$73DF          ; #FDF1E0
    sta cgram_buf+92
    lda #$0E9F          ; #FAA61E
    sta cgram_buf+94
    A8
    bra @d
@off:
    A16
    lda #$2D2A          ; #504858
    sta cgram_buf+92
    lda #$1888          ; #402830
    sta cgram_buf+94
    A8
@d: lda #1
    sta pal_dirty
    rts

; ================================================================ TITULO
TitleInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadLogoScene
    jsr ClearBg3
    jsr OamClear
    jsr UiTituloOn          ; xadrez animado atras da logo
    ldx #0
    stx demo_ocioso
    jsr HasSave
    lda #0
    rol a
    sta title_has_save
    sta menu_sel
    jsr TitleMenu
    jsr TitleSprites
    jsr ScreenOn
    lda mu_est              ; a musica gravada ja esta tocando (voltou ao titulo)
    bne :+
    jsr StopMusic           ; o titulo usa a musica gravada (no lugar do chiptune)
    lda #1                  ; musica e narracao entram assim que as vozes fixas
    sta tema_pend           ; terminarem de carregar (TitleUpdate), sem travar a tela
:   jsr FadeIn
    rts

; menu do titulo no cartao (gerador/logo.py): subtitulo e itens com icone; o
; escolhido fica vermelho, com a pilula atras e o icone balancando
TIT_LIN  = 20               ; linha do 1o item (os outros a cada 2 linhas)
TIT_COL  = 14               ; coluna do texto (o icone fica a esquerda)
TitleMenu:
    .a8
    .i16
    PRINT TXT_TIT_SUB, 6, 18, 5
    PRINT TXT_TIT_AJ, 10, 26, 7
    ; itens: 0 novo jogo, 1 continuar (se houver save), 2 opcoes
    lda #0
    ldx #TXT_TIT_NOVO
    jsr TitItem
    lda title_has_save
    beq :+
    lda #1
    ldx #TXT_TIT_CONT
    jsr TitItem
    lda #2
    ldx #TXT_TIT_OPC
    jmp TitItem
:   lda #1
    ldx #TXT_TIT_OPC
    jmp TitItem

; A = posicao no menu, X = texto
TitItem:
    .a8
    .i16
    sta loop_i
    stx tmp3
    asl a                   ; linha = TIT_LIN + 2 * posicao
    clc
    adc #TIT_LIN
    sta loop_i+1
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #TIT_COL
    sta txt_pos
    A8
    ldy #((4<<2)|$20)       ; marrom; o escolhido em vermelho
    lda loop_i
    cmp menu_sel
    bne :+
    ldy #((5<<2)|$20)
:   sty txt_attr
    ldx tmp3
    jsr PrintStr
    lda loop_i
    cmp menu_sel
    bne @r
    A16                     ; pilula atras do item escolhido (do icone ao fim do texto)
    lda txt_pos
    asl a
    sta ft_pos
    A8
    lda #(TIT_COL*8 - 32)
    sta ft_x0
    lda #(TIT_COL*8 + 72)
    sta ft_x1
    lda loop_i+1
    asl a
    asl a
    asl a
    sec
    sbc #4
    sta ft_y
    jmp PilulaLiga
@r: rts

; numero de itens do menu do titulo
TitleCount:
    .a8
    .i16
    lda title_has_save
    clc
    adc #2
    rts

TitleUpdate:
    .a8
    .i16
    lda tema_pend           ; carga das vozes fixas acabou: musica + narracao
    beq :+
    ldx vz_carga
    bne :+
    stz tema_pend
    jsr MusToca
    lda #VOZ_TITULO         ; "Los Pastelles, o imperio do pastel" por cima da musica
    jsr VozToca
:   jsr DemoTitulo          ; 30 s parado: demonstracao
    bcc :+
    rts
:   jsr TitleSprites
    jsr CodeCheck
    bcc :+
    SFX SFX_NIVEL
    lda #2
    sta sl_mode
    lda #ST_SLOTS
    sta next_state
    rts
:
    lda pad_new+1
    and #KH_UP
    beq @nu
    lda menu_sel
    beq @nu
    dec menu_sel
    SFX SFX_CURSOR
    jsr TitleMenu
@nu:
    lda pad_new+1
    and #(KH_DOWN|KH_SEL)
    beq @nd
    jsr TitleCount
    dec a
    cmp menu_sel
    beq @nd
    inc menu_sel
    SFX SFX_CURSOR
    jsr TitleMenu
@nd:
    lda pad_new+1
    and #KH_START
    bne @go
    lda pad_new
    and #KL_A
    beq @rts
@go:
    A16
    lda frame
    eor rng
    ora #$0001
    sta rng
    A8
    SFX SFX_OK
    ; traduz posicao -> item
    lda menu_sel
    beq @novo
    lda title_has_save
    beq @opc
    lda menu_sel
    cmp #1
    beq @cont
@opc:
    lda #ST_OPTIONS
    sta next_state
    rts
@novo:
    stz sl_mode
    lda #ST_SLOTS
    sta next_state
    rts
@cont:
    lda #1
    sta sl_mode
    lda #ST_SLOTS
    sta next_state
@rts:
    rts

; icones dos itens do menu do titulo (o escolhido balanca)
TitIcones:  .byte ICO_NOVO, ICO_CONT, ICO_OPC
TitIcones2: .byte ICO_NOVO, ICO_OPC
TitleSprites:
    .a8
    .i16
    jsr OamClear
    stz loop_j
@l: A16
    lda #(TIT_COL*8 - 22)
    sta spr_x
    A8
    lda loop_j              ; y = (TIT_LIN + 2 * posicao) * 8 - 4
    asl a
    clc
    adc #TIT_LIN
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
    lda TitIcones,x
    ldy title_has_save
    bne :+
    lda TitIcones2,x
:   pha
    lda loop_j
    cmp menu_sel
    beq :+
    clc                     ; (carry = 1: escolhido, balanca)
:   pla
    jsr IconeSprite
    inc loop_j
    jsr TitleCount
    cmp loop_j
    bne @l
    rts

; ================================================================ ABERTURA
IntroInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    lda #$80
    sta VMAIN
    VRAM_LOAD SprTiles, VRAM_OBJ, 3072   ; (o titulo usa esse espaco para os icones)
    jsr LoadTitleScene
    lda #0
    jsr SignLight
    jsr ClearBg3
    jsr OamClear
    jsr StopMusic
    ldx #0
    stx intro_t
    jsr ScreenOn
    jsr FadeIn
    rts

IntroUpdate:
    .a8
    .i16
    jsr OamClear
    A16
    inc intro_t
    lda intro_t
    cmp #60
    bcs :+
    jmp @rts16
:   cmp #130
    bcs @lit
    A8
    ; piscando enquanto acende
    and #$06
    cmp #$04
    lda #0
    rol a
    jsr SignLight
    rts
@lit:
    .a16
    bne @q
    A8
    lda #1
    jsr SignLight
    SFX SFX_SINO
    rts
@q:
    .a16
    cmp #170
    bne @w
    A8
    PRINT TXT_INTRO_Q, 7, 3, 0
    lda #SONG_TITULO
    jsr PlaySong
    rts
@w:
    .a16
    cmp #200
    bcs :+
    jmp @rts16
:
    A8
    lda pad_new+1
    and #KH_START
    bne @go
    lda pad_new
    and #KL_A
    bne @go
    A16
    lda intro_t
    cmp #720
    bcs :+
    jmp @rts16
:
    A8
@go:
    SFX SFX_OK
    jsr CardReset
    lda #CARD_INTRO_A
    jsr CardAdd
    lda #CARD_INTRO_B
    jsr CardAdd
    lda #CARD_INTRO_C
    jsr CardAdd
    lda #CARD_CLIENTELA
    jsr CardAdd
    lda #CARD_MISSAO1
    jsr CardAdd
    lda #ST_PREDAY
    jmp CardGo
@rts16:
    A8
    rts

; ================================================================ CARTAS
CardReset:
    .a8
    .i16
    stz card_n
    stz card_i
    rts
CardAdd:
    .a8
    .i16
    pha
    lda card_n
    cmp #12
    bcs @full
    A16
    and #$00FF
    tax
    A8
    pla
    sta card_q,x
    inc card_n
    rts
@full:
    pla
    rts
; A = estado seguinte
CardGo:
    .a8
    .i16
    pha
    lda card_n
    bne :+
    pla
    sta next_state
    rts
:   pla
    sta card_next
    stz card_i
    lda #ST_CARD
    sta next_state
    rts

CardInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadMenuScene
    ; retratos por cima dos clientes (so aparecem nas cartas)
    VRAM_LOAD PortGfx, VRAM_OBJ, 2048
    jsr DrawCard
    jsr CardSprite
    jsr ScreenOn
    lda cur_song
    cmp #$FF
    bne :+
    lda #SONG_RESULTADO
    jsr PlaySong
:   jsr FadeIn
    rts

; carta com fala (desafio, vitoria, derrota, trofeu, final): toca a voz
CartaFala:
    .a8
    .i16
    A16
    lda card_i
    and #$00FF
    tax
    A8
    lda card_q,x
    A16
    and #$00FF
    tax
    A8
    lda f:CartaVoz,x
    cmp #$FF
    beq :+
    jmp VozToca
:   rts

; ponteiro da carta atual -> tmp (indice na CardTable)
CardEntry:
    .a8
    .i16
    A16
    lda card_i
    and #$00FF
    tax
    A8
    lda card_q,x
    A16
    and #$00FF
    sta tmp
    asl a
    asl a
    clc
    adc tmp
    tax
    A8
    rts

DrawCard:
    .a8
    .i16
    jsr ClearBg3
    jsr CartaFala
    jsr CardEntry
    lda f:CardTable,x
    cmp #$FF
    beq @noport
    ; retrato: paleta OBJ 7
    phx
    A16
    and #$00FF
    cmp #4
    bne :+
    lda #(7*32)
    clc
    adc #.loword(SprPal)
    bra :++
:   asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #.loword(PortPal)
:   sta dma_src
    A8
    lda #^PortPal
    sta dma_src+2
    ldx #(240*2)
    ldy #32
    jsr CopyPal
    plx
    phx
    A16
    lda f:CardTable+1,x
    tay
    A8
    ldx #(4*32+8)
    stx txt_pos
    lda #((5<<2)|$20)
    sta txt_attr
    tyx
    lda #^CardTable
    jsr PrintStrB
    plx
    bra @body
@noport:
    phx
    A16
    lda f:CardTable+1,x
    tay
    A8
    ldx #(3*32+3)
    stx txt_pos
    lda #((5<<2)|$20)
    sta txt_attr
    tyx
    lda #^CardTable
    jsr PrintStrB
    plx
@body:
    A16
    lda f:CardTable+3,x
    tay
    A8
    ldx #(8*32+3)
    stx txt_pos
    lda #((4<<2)|$20)
    sta txt_attr
    tyx
    lda #^CardTable
    jsr TypeStartB          ; texto aparece letra por letra
    ldx #TXT_C_A
    lda #26
    jsr Footer
    rts

PortTiles: .word SPR_PORT_0, SPR_PORT_1, SPR_PORT_2, SPR_PORT_3, SPR_CUST_4_0, SPR_MASCOTE_0

CardUpdate:
    .a8
    .i16
    jsr CardSprite
    jmp CardInput

; retrato do personagem da carta atual
CardSprite:
    .a8
    .i16
    jsr OamClear
    jsr CardEntry
    txy
    lda f:CardTable,x
    cmp #$FF
    beq @nop
    A16
    and #$00FF
    asl a
    tax
    lda PortTiles,x
    sta spr_tile
    lda #24
    sta spr_x
    A8
    lda #22
    sta spr_y
    lda #$3E                ; prioridade 3, paleta 7
    sta spr_attr
    phx
    tyx
    lda f:CardTable,x
    plx
    cmp #5
    bne :+
    ; mascote: paleta 1, pisca e pula
    lda #$32
    sta spr_attr
    jsr MascotFrame
:   jsr AddSprite32
@nop:
    rts

; quadro animado do mascote em spr_tile / spr_y (pisca e quica)
MascotFrame:
    .a8
    .i16
    A16
    lda #SPR_MASCOTE_0
    sta spr_tile
    A8
    lda frame
    and #$30
    cmp #$30
    bne :+
    A16
    lda #SPR_MASCOTE_1
    sta spr_tile
    A8
:   lda frame
    lsr a
    lsr a
    lsr a
    and #$03
    cmp #$02
    bcc :+
    eor #$03
:   eor #$FF
    inc a
    clc
    adc spr_y
    sta spr_y
    rts

CardInput:
    .a8
    .i16
    lda pad_new+1
    and #KH_START
    bne @next
    lda pad_new
    and #KL_A
    beq @rts
@next:
    ; texto ainda sendo escrito: o botao so completa a caixa
    lda tw_on
    beq :+
    jmp TypeFinish
:   SFX SFX_CURSOR
    jsr UiReopen
    inc card_i
    lda card_i
    cmp card_n
    bcs @done
    jsr DrawCard
    rts
@done:
    lda card_next
    sta next_state
@rts:
    rts

; ================================================================ ANTES DO DIA
LevelCap: .byte 5, 12, 20, 30, 99

PreDayInit:
    .a8
    .i16
    lda #$FF
    sta d_boss
    stz d_event
    jsr CardReset
    ; anuncio de capitulo
    lda s_chapter
    cmp s_boss
    bcs @nochap
    lda s_boss
    sta s_chapter
    dec a
    clc
    adc #CARD_CAP_2
    jsr CardAdd
@nochap:
    ; dia de desafio?
    lda s_boss
    cmp #4
    bcs @noboss
    A16
    and #$00FF
    tax
    A8
    lda s_level
    cmp LevelCap,x
    bcc @noboss
    lda s_boss
    sta d_boss
    clc
    adc #CARD_BOSS_0
    jsr CardAdd
    jmp @go
@noboss:
    ; duelo semanal: dias 7, 14, 21...
    A16
    lda s_day
    cmp #7
    bcc @nodu
@m7:
    cmp #7
    bcc :+
    sec
    sbc #7
    bra @m7
:   cmp #0
    bne @nodu
    A8
    lda #5
    sta d_event
    lda s_level
    lsr a
    clc
    adc #8
    cmp #23
    bcc :+
    lda #22
:   sta d_goal
    lda #CARD_DUELO
    jsr CardAdd
    jmp @go
@nodu:
    A8
    A16
    lda s_day
    cmp #3
    A8
    bcc @go
    lda #10
    jsr RandBelow
    cmp #2
    bcs :+
    lda #1
    sta d_event
    lda #CARD_EV_CONC
    jsr CardAdd
    jmp @go
:   cmp #4
    bcs :+
    lda #2
    sta d_event
    lda #CARD_EV_FEIRA
    jsr CardAdd
    jmp @go
:   cmp #5
    bcs :+
    lda #3
    sta d_event
    lda #CARD_EV_CHUVA
    jsr CardAdd
    jmp @go
:   cmp #6
    bcs :+
    lda #4
    sta d_event
    lda #CARD_EV_FUTEBOL
    jsr CardAdd
    jmp @go
:   cmp #7
    bcs :+
    lda #6
    sta d_event
    lda #CARD_EV_FESTIVAL
    jsr CardAdd
    jmp @go
:   cmp #8
    bcs @go
    lda #7
    sta d_event
    lda #CARD_EV_CRITICO
    jsr CardAdd
@go:
    ; com mais de uma loja, escolhe onde trabalhar
    lda s_stores
    bne :+
    stz d_unit
    lda #ST_DAY
    jmp CardGo
:   lda #ST_CHOOSE
    jmp CardGo

; ================================================================ RESULTADOS
StoreIncome: .word 60, 70, 80, 110
BossBonus:   .word 150, 300, 600, 1500

ResultsInit:
    .a8
    .i16
    jsr FadeOut
    stz sizzle_want
    jsr AudioUpdate
    jsr ScreenOff
    jsr LoadMenuScene
    jsr ClearBg3
    jsr OamClear
    lda s_level
    sta r_oldlvl
    stz r_levels
    stz r_bossres
    ; aluguel = 25 + 5*balcao + 5*fritadeira
    A16
    lda s_counter
    and #$00FF
    sta tmp
    lda s_fryer
    and #$00FF
    clc
    adc tmp
    sta tmp
    asl a
    asl a
    clc
    adc tmp
    clc
    adc #25
    sta r_rent
    stz r_salary
    A8
    lda s_attend
    beq :+
    ldx #20
    stx r_salary
:   lda s_moto
    beq :+
    A16
    lda r_salary
    clc
    adc #15
    sta r_salary
    A8
:   ; outras unidades
    ldx #0
    stx r_other
    ldy #0
@st:
    tya
    cmp s_stores
    bcs @stdone
    inc a
    cmp d_unit
    bne :+
    iny
    bra @st
:   A16
    tya
    asl a
    tax
    lda StoreIncome,x
    clc
    adc r_other
    sta r_other
    lda s_rep
    and #$00FF
    lsr a
    lsr a
    clc
    adc r_other
    sta r_other
    A8
    iny
    bra @st
@stdone:
    lda d_unit
    beq :+
    ; trabalhou fora da matriz: a matriz rende sozinha
    A16
    lda s_rep
    and #$00FF
    lsr a
    lsr a
    clc
    adc #50
    clc
    adc r_other
    sta r_other
    A8
:   lda s_fran
    beq @nofr
    sta WRMPYA
    lda #150
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    clc
    adc r_other
    sta r_other
    A8
@nofr:
    ; caixa += outras - aluguel - salarios
    A16
    lda r_other
    sta tmp
    jsr AddMoney16
    lda r_rent
    clc
    adc r_salary
    sta tmp
    lda s_money
    sec
    sbc tmp
    sta s_money
    lda s_money+2
    sbc #0
    sta s_money+2
    bpl :+
    stz s_money
    stz s_money+2
:   ; lucro do dia (com sinal)
    lda d_sales
    clc
    adc d_tips
    clc
    adc r_other
    sec
    sbc tmp
    sta r_profit
    A8
    ; desafio
    lda d_boss
    cmp #$FF
    beq @noboss
    lda #2
    sta r_bossres
    lda d_boss
    cmp #1
    bne :+
    lda d_perfect
    bra :++
:   lda d_happy
:   cmp d_goal
    bcc @noboss
    lda #1
    sta r_bossres
    inc s_boss
    A16
    lda d_boss
    and #$00FF
    asl a
    tax
    lda BossBonus,x
    sta tmp
    jsr AddMoney16
    lda d_xp
    clc
    adc #100
    sta d_xp
    A8
@noboss:
    stz r_duel
    lda d_event
    cmp #5
    bne @nodu
    lda #2
    sta r_duel
    lda d_happy
    cmp d_goal
    bcc @dlose
    lda #1
    sta r_duel
    A16
    lda #100
    sta tmp
    jsr AddMoney16
    A8
    lda #5
    jsr RepUp
    inc s_duels
    bra @nodu
@dlose:
    lda #5
    jsr RepDown
@nodu:
    lda d_myst_ok
    beq :+
    lda #1
    tsb s_tflags
:
    ; experiencia
    A16
    lda d_xp
    clc
    adc #20
    clc
    adc s_xp
    bcc :+
    lda #$FFFF
:   sta s_xp
    A8
    jsr LevelUp
    stz s_promo
    lda s_mission
    sta r_misdone
    jsr CheckMission
    jsr TrophyCheck
    jsr HistPush
    stz r_page
    jsr DrawResults
    A16
    inc s_day
    A8
    jsr ScreenOn
    lda r_bossres
    cmp #2
    bne :+
    lda #SONG_DERROTA
    bra :+++
:   cmp #1
    bne :+
    lda #SONG_VITORIA
    bra :++
:   lda #SONG_RESULTADO
:   jsr PlaySong
    jsr FadeIn
    rts

; guarda o lucro do dia no historico (7 dias)
HistPush:
    .a8
    .i16
    ldx #0
@sh:
    A16
    lda hist+2,x
    sta hist,x
    A8
    inx
    inx
    cpx #12
    bne @sh
    A16
    lda r_profit
    sta hist+12
    A8
    lda hist_n
    cmp #7
    bcs :+
    inc hist_n
:   rts

; grafico de barras: verde = lucro, vermelho = prejuizo
DrawChart:
    .a8
    .i16
    jsr ClearBg3
    PRINT TXT_G_TIT, 3, 3, 5
    lda hist_n
    bne :+
    PRINT TXT_G_VAZIO, 3, 10, 4
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
    adc #(22*32)
    sta txt_pos
    lda num+2
    sta num
    stz num+2
    A8
    lda #((4<<2)|$20)
    sta txt_attr
    lda #3
    sta num_w
    jsr PrintNum
    inc loop_i
    jmp @bar
@foot:
    PRINT TXT_G_MELHOR, 3, 24, 6
    PRINT TXT_G_RS, 10, 24, 6
    PRINTNUM16 tmp4, 13, 24, 6, 5
    ldx #TXT_R_CONT
    lda #26
    jsr Footer
    rts

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

; xp necessario = 60 + 20*nivel -> tmp
XpNeed:
    .a8
    .i16
    A16
    lda s_level
    and #$00FF
    sta tmp
    asl a
    asl a
    clc
    adc tmp
    sta tmp
    asl a
    asl a
    clc
    adc tmp
    clc
    adc #80
    sta tmp
    A8
    rts

LevelUp:
    .a8
    .i16
@lp:
    jsr XpNeed
    A16
    lda s_xp
    cmp tmp
    A8
    bcc @done
    lda s_boss
    A16
    and #$00FF
    tax
    A8
    lda s_level
    cmp LevelCap,x
    bcc @up
    ; no limite: segura o xp
    A16
    lda tmp
    dec a
    sta s_xp
    A8
    rts
@up:
    A16
    lda s_xp
    sec
    sbc tmp
    sta s_xp
    A8
    inc s_level
    inc r_levels
    bra @lp
@done:
    rts

DrawResults:
    .a8
    .i16
    PRINT TXT_R_FIM, 3, 3, 5
    PRINTNUM16 s_day, 14, 3, 5, 3
    PRINT TXT_R_CLI, 3, 5, 4
    PRINTNUM8 d_served, 22, 5, 4, 3
    PRINT TXT_HUD_BAR, 25, 5, 4
    PRINTNUM8 d_total, 26, 5, 4, 2
    PRINT TXT_R_PERF, 3, 6, 4
    PRINTNUM8 d_perfect, 25, 6, 4, 3
    PRINT TXT_R_DESP, 3, 7, 4
    PRINTNUM8 d_waste, 25, 7, 4, 3
    lda s_level
    cmp #TEL_LV
    bcc :+
    PRINT TXT_R_ENTR, 3, 8, 7
    PRINTNUM8 d_deliv, 14, 8, 7, 3
    PRINT TXT_R_RS, 19, 8, 7
    PRINTNUM16 d_dvsales, 22, 8, 7, 6
:   PRINT TXT_R_VEND, 3, 9, 4
    PRINT TXT_R_RS, 19, 9, 4
    PRINTNUM16 d_sales, 22, 9, 4, 6
    PRINT TXT_R_GORJ, 3, 10, 4
    PRINT TXT_R_RS, 19, 10, 4
    PRINTNUM16 d_tips, 22, 10, 4, 6
    PRINT TXT_R_OUTR, 3, 11, 4
    PRINT TXT_R_RS, 19, 11, 4
    PRINTNUM16 r_other, 22, 11, 4, 6
    PRINT TXT_R_ALUG, 3, 12, 5
    PRINT TXT_R_MRS, 18, 12, 5
    PRINTNUM16 r_rent, 22, 12, 5, 6
    PRINT TXT_R_SAL, 3, 13, 5
    PRINT TXT_R_MRS, 18, 13, 5
    PRINTNUM16 r_salary, 22, 13, 5, 6
    ; lucro ou prejuizo
    A16
    lda r_profit
    bmi @neg
    A8
    PRINT TXT_R_LUCRO, 3, 15, 6
    PRINT TXT_R_RS, 19, 15, 6
    PRINTNUM16 r_profit, 22, 15, 6, 6
    bra @cx
@neg:
    .a16
    eor #$FFFF
    inc a
    sta r_profit
    A8
    PRINT TXT_R_PREJ, 3, 15, 5
    PRINT TXT_R_MRS, 18, 15, 5
    PRINTNUM16 r_profit, 22, 15, 5, 6
@cx:
    PRINT TXT_R_CAIXA, 3, 17, 7
    PRINT TXT_R_RS, 19, 17, 7
    A16
    lda s_money
    sta num
    lda s_money+2
    sta num+2
    A8
    ldx #(17*32+21)
    stx txt_pos
    lda #((7<<2)|$20)
    sta txt_attr
    lda #7
    sta num_w
    jsr PrintNum
    PRINT TXT_R_REP, 3, 18, 4
    PRINTNUM8 s_rep, 22, 18, 4, 3
    PRINT TXT_R_100, 25, 18, 4
    PRINT TXT_R_NIVEL, 3, 19, 4
    PRINTNUM8 s_level, 9, 19, 4, 2
    PRINT TXT_R_XP, 13, 19, 4
    PRINTNUM16 s_xp, 16, 19, 4, 5
    PRINT TXT_HUD_BAR, 21, 19, 4
    jsr XpNeed
    PRINTNUM16 tmp, 22, 19, 4, 4
    lda r_levels
    beq :+
    PRINT TXT_R_SUBIU, 3, 20, 6
:   lda r_bossres
    bne :+
    lda r_duel
    beq @nob
:
    cmp #1
    bne :+
    PRINT TXT_R_META_OK, 3, 21, 6
    bra @nob
:   PRINT TXT_R_META_NO, 3, 21, 5
@nob:
    PRINT TXT_R_MISSAO, 3, 22, 7
    A16
    lda s_mission
    and #$00FF
    asl a
    tax
    lda MissionTxt,x
    tax
    A8
    ldy #(23*32+3)
    sty txt_pos
    lda #((6<<2)|$20)
    sta txt_attr
    jsr PrintStr
    ldx #TXT_R_CONT
    lda #26
    jsr Footer
    rts

ResultsUpdate:
    .a8
    .i16
    lda pad_new+1
    and #KH_START
    bne @go
    lda pad_new
    and #KL_A
    bne @go
    rts
@go:
    SFX SFX_OK
    ; primeira tecla: pagina do grafico de lucro
    lda r_page
    bne :+
    inc r_page
    jmp DrawChart
:
    jsr CardReset
    lda r_bossres
    beq @nb
    cmp #1
    bne :+
    lda #CARD_VITORIA
    bra :++
:   lda #CARD_DERROTA
:   jsr CardAdd
@nb:
    lda r_duel
    beq @nd
    cmp #1
    bne :+
    lda #CARD_DUELO_OK
    bra :++
:   lda #CARD_DUELO_NO
:   jsr CardAdd
@nd:
    lda d_myst_ok
    beq :+
    lda #CARD_MISTERIO
    jsr CardAdd
:   jsr TrophyCards
   ; desbloqueios por nivel
    lda r_oldlvl
@lv:
    cmp s_level
    bcs @lvdone
    inc a
    sta r_oldlvl
    cmp #3
    bne :+
    lda #CARD_UN_CALAB
    jsr CardAdd
:   lda r_oldlvl
    cmp #6
    bne :+
    lda #CARD_UN_CATUP
    jsr CardAdd
    lda #CARD_UN_ATEND
    jsr CardAdd
    lda #CARD_UN_TEL
    jsr CardAdd
:   lda r_oldlvl
    cmp #7
    bne :+
    lda #CARD_UN_REFRI
    jsr CardAdd
:   lda r_oldlvl
    cmp #9
    bne :+
    lda #CARD_UN_BACON
    jsr CardAdd
:   lda r_oldlvl
    cmp #10
    bne :+
    lda #CARD_UN_PUBLI
    jsr CardAdd
:   lda r_oldlvl
    cmp #13
    bne :+
    lda #CARD_UN_LOJA
    jsr CardAdd
    lda #CARD_UN_PC
    jsr CardAdd
:   lda r_oldlvl
    cmp #21
    bne :+
    lda #CARD_UN_FRAN
    jsr CardAdd
:   lda r_oldlvl
    bra @lv
@lvdone:
    ; final do jogo
    lda s_ending
    bne :+
    jsr Units
    cmp #10
    bcc :+
    lda #1
    sta s_ending
    lda #CARD_FIM
    jsr CardAdd
    lda #CARD_CREDITOS
    jsr CardAdd
    lda #CARD_DICA
    jsr CardAdd
:   ; sem estoque e sem dinheiro: ajuda do mestre
    A16
    lda s_stock
    bne @ok
    lda s_money+2
    bne @ok
    lda s_money
    cmp #30
    bcs @ok
    lda #10
    sta s_stock
    A8
    lda #CARD_FALIU
    jsr CardAdd
@ok:
    A8
    lda #ST_SHOP
    jmp CardGo

; A = total de unidades (1 + lojas + franquias)
Units:
    .a8
    .i16
    lda s_stores
    clc
    adc s_fran
    inc a
    rts

; ================================================================ MISSOES
CheckMission:
    .a8
    .i16
@lp:
    lda s_mission
    cmp #14
    bcs @done
    A16
    and #$00FF
    asl a
    tax
    A8
    jsr (MissionCond,x)
    bcc @done
    inc s_mission
    A16
    lda #50
    sta tmp
    jsr AddMoney16
    lda s_xp
    clc
    adc #30
    bcc :+
    lda #$FFFF
:   sta s_xp
    A8
    bra @lp
@done:
    rts

MissionCond:
    .word MC0, MC1, MC2, MC3, MC4, MC5, MC6, MC7, MC8, MC9, MC10, MC11, MC12, MC13

MC0:
    .a8
    .i16
    A16
    lda s_tot_fried
    cmp #5
    A8
    rts
MC1:
    .a8
    .i16
    A16
    lda s_tot_sales+2
    bne :+
    lda s_tot_sales
    cmp #100
    A8
    rts
:   A8
    sec
    rts
MC2:
    .a8
    .i16
    lda s_upgrades
    cmp #1
    rts
MC3:
    .a8
    .i16
    A16
    lda s_tot_happy
    cmp #10
    A8
    rts
MC4:
    .a8
    .i16
    A16
    lda s_tot_perf
    cmp #5
    A8
    rts
MC5:
    .a8
    .i16
    lda s_boss
    cmp #1
    rts
MC6:
    .a8
    .i16
    A16
    lda s_tot_happy
    cmp #50
    A8
    rts
MC7:
    .a8
    .i16
    lda s_attend
    cmp #1
    rts
MC8:
    .a8
    .i16
    lda s_boss
    cmp #2
    rts
MC9:
    .a8
    .i16
    lda s_stores
    cmp #1
    rts
MC10:
    .a8
    .i16
    lda s_boss
    cmp #3
    rts
MC11:
    .a8
    .i16
    lda s_fran
    cmp #1
    rts
MC12:
    .a8
    .i16
    lda s_boss
    cmp #4
    rts
MC13:
    .a8
    .i16
    jsr Units
    cmp #10
    rts

; ================================================================ LOJA
ShopInit:
    .a8
    .i16
    jsr FadeOut
    jsr ScreenOff
    jsr LoadMenuScene
    ; icones (emojis) por cima dos clientes; paletas OBJ 3..6
    VRAM_LOAD IconGfx, VRAM_OBJ, (IconGfx_end - IconGfx)
    PAL_LOAD IconPal, 176, 128
    jsr OamClear
    stz menu_msg
    lda menu_sel
    cmp #SH_N
    bcc :+
    stz menu_sel
:   jsr ShopScroll
    jsr DrawShop
    jsr ShopSprite
    jsr ScreenOn
    lda #SONG_RESULTADO
    jsr PlaySong
    jsr FadeIn
    rts

; preco do item A -> tmp (16 bits). Codigos: $FFFF maximo, $FFFE bloqueado (nivel em tmp2),
; $FFFD ativo, $FFFC precisa rep 70, $0000 sem preco
ItemPrice:
    .a8
    .i16
    A16
    and #$00FF
    asl a
    tax
    A8
    jmp (PriceFn,x)
PriceFn: .word P0, P1, P2, P3, P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P15, P8, P8, P8, P8, P8

.macro SETP val
    ldx #val
    stx tmp
.endmacro

P0:
    .a8
    .i16
    SETP 30
    rts
P1:
    .a8
    .i16
    lda s_fryer
    cmp #3
    JCS PMax
    cmp #2
    bcs :+
    SETP 120
    rts
:   SETP 300
    rts
P2:
    .a8
    .i16
    lda s_counter
    cmp #3
    JCS PMax
    cmp #2
    bcs :+
    SETP 100
    rts
:   SETP 250
    rts
P3:
    .a8
    .i16
    lda s_promo
    JNE PAtivo
    SETP 40
    rts
P4:
    .a8
    .i16
    lda #6
    jsr PLock
    JCS PRet
    lda s_attend
    JNE PAtivo
    SETP 150
    rts
P5:
    .a8
    .i16
    lda #10
    jsr PLock
    JCS PRet
    lda s_ads
    JNE PAtivo
    SETP 250
    rts
P6:
    .a8
    .i16
    lda #13
    jsr PLock
    JCS PRet
    lda s_stores
    cmp #4
    JCS PMax
    ; 1500 + 500*lojas
    sta WRMPYA
    lda #250
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    asl a
    clc
    adc #1500
    sta tmp
    A8
    rts
P7:
    .a8
    .i16
    lda #21
    jsr PLock
    JCS PRet
    lda s_boss
    cmp #3
    bcs :+
    lda #21
    sta lock_lv
    SETP $FFFE
    rts
:   lda s_fran
    cmp #5
    JCS PMax
    lda s_rep
    cmp #70
    bcs :+
    SETP $FFFC
    rts
:   SETP 4000
    rts
P9: ; computador de pedidos (nivel 13)
    lda #13
    jsr PLock
    bcs P9r
    lda s_pc
    beq :+
    jmp PAtivo
:   SETP 600
P9r:
    rts
P10: ; motoboy extra (nivel 6)
    lda #6
    jsr PLock
    bcs P10r
    lda s_moto
    beq :+
    jmp PAtivo
:   SETP 300
P10r:
    rts
.macro ITEM_UNICO nivel, var, preco
    .local fim
    lda #nivel
    jsr PLock
    bcs fim
    lda var
    beq :+
    jmp PAtivo
:   SETP preco
fim:
    rts
.endmacro
P11: ; freezer
    ITEM_UNICO 4, s_freezer, 250
P12: ; ar-condicionado
    ITEM_UNICO 7, s_ar, 400
P13: ; musica ambiente
    ITEM_UNICO 5, s_musica, 150
P14: ; uniforme da marca
    ITEM_UNICO 10, s_unif, 300
P15: ; reforma do salao (2 etapas)
    lda s_reforma
    cmp #2
    bcc :+
    jmp PMax
:   cmp #1
    bcs :+
    lda #8
    jsr PLock
    bcs P15r
    SETP 900
    rts
:   lda #14
    jsr PLock
    bcs P15r
    SETP 2500
P15r:
    rts
P8:
    .a8
    .i16
    SETP 0
    rts
PMax:
    .a8
    .i16
    SETP $FFFF
PRet:
    .a8
    .i16
    rts
PAtivo:
    .a8
    .i16
    SETP $FFFD
    rts
; A = nivel minimo; carry = bloqueado (tmp = $FFFE)
PLock:
    .a8
    .i16
    sta lock_lv
    lda s_level
    cmp lock_lv
    bcs :+
    SETP $FFFE
    sec
    rts
:   clc
    rts

DrawShop:
    .a8
    .i16
    jsr ClearBg3
    PRINT TXT_S_TIT, 3, 2, 5
    PRINT TXT_S_CAIXA, 3, 3, 7
    A16
    lda s_money
    sta num
    lda s_money+2
    sta num+2
    A8
    ldx #(3*32+12)
    stx txt_pos
    lda #((7<<2)|$20)
    sta txt_attr
    lda #7
    sta num_w
    jsr PrintNum
    PRINT TXT_S_EST, 3, 4, 7
    PRINTNUM16 s_stock, 11, 4, 7, 3
    PRINT TXT_HUD_DIA, 19, 4, 7
    PRINTNUM16 s_day, 23, 4, 7, 3
    ; itens visiveis: menu_top .. menu_top+SH_VIS-1
    lda menu_top
@it:
    sta loop_i
    ; linha = 6 + 2 * (i - topo)  (16 px por item, com icone)
    sec
    sbc menu_top
    asl a
    clc
    adc #6
    sta loop_i+1
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #5
    sta txt_pos
    lda loop_i
    and #$00FF
    asl a
    tax
    lda ShopName,x
    tax
    A8
    ldy #4
    lda loop_i
    cmp menu_sel
    bne :+
    ldy #5
:   tya
    asl a
    asl a
    ora #$20
    sta txt_attr
    jsr PrintStr
    ; seta
    lda loop_i
    cmp menu_sel
    bne :+
    ; faixa pulsante de 16 linhas centrada no item
    lda loop_i+1
    asl a
    asl a
    asl a
    sec
    sbc #4
    sta hl_y
    lda #16
    sta hl_h
:   ; preco / estado (coluna 22)
    lda loop_i
    jsr ItemPrice
    A16
    lda loop_i+1
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #22
    sta txt_pos
    lda tmp
    A8
    lda #((4<<2)|$20)
    sta txt_attr
    A16
    lda tmp
    beq @np
    cmp #$FFFF
    bne :+
    A8
    ldx #TXT_ST_MAX
    jsr PrintStr
    jmp @np8
:   .a16
    cmp #$FFFE
    bne :+
    A8
    ldx #TXT_ST_NV
    jsr PrintStr
    A16
    inc txt_pos
    inc txt_pos
    inc txt_pos
    lda lock_lv
    and #$00FF
    sta num
    stz num+2
    A8
    lda #2
    sta num_w
    jsr PrintNum
    jmp @np8
:   .a16
    cmp #$FFFD
    bne :+
    A8
    ldx #TXT_ST_ATIVO
    jsr PrintStr
    jmp @np8
:   .a16
    cmp #$FFFC
    bne :+
    A8
    ldx #TXT_ST_REP
    jsr PrintStr
    jmp @np8
:   .a16
    sta num
    stz num+2
    A8
    ldx #TXT_ST_RS
    jsr PrintStr
    A16
    lda txt_pos
    clc
    adc #3
    sta txt_pos
    A8
    lda #4
    sta num_w
    jsr PrintNum
    jmp @np8
@np:
    A8
    lda loop_i
    cmp #SH_PRECO
    bne @np8
    A16
    lda s_price
    and #$00FF
    asl a
    tax
    lda PriceLvTxt,x
    tax
    A8
    lda #((7<<2)|$20)
    sta txt_attr
    jsr PrintStr
@np8:
    lda loop_i
    inc a
    cmp #SH_N
    beq :+
    sta tmp4
    sec
    sbc menu_top
    cmp #SH_VIS
    bcs :+
    lda tmp4
    jmp @it
:   ; setas de rolagem
    lda menu_top
    beq :+
    PRINT TXT_SH_UP, 29, 6, 5
:   lda menu_top
    clc
    adc #SH_VIS
    cmp #SH_N
    bcs :+
    PRINT TXT_SH_DN, 29, 16, 5
:   ; descricao
    A16
    lda menu_sel
    and #$00FF
    asl a
    tax
    lda ShopDesc,x
    tax
    A8
    ldy #(19*32+3)
    sty txt_pos
    lda #((7<<2)|$20)
    sta txt_attr
    jsr TypeStart           ; descricao letra por letra
    ; mensagem
    lda menu_msg
    beq :+
    A16
    and #$00FF
    asl a
    tax
    lda ShopMsgs-2,x
    tax
    A8
    ldy #(23*32+3)
    sty txt_pos
    lda #((5<<2)|$20)
    sta txt_attr
    jsr PrintStr
:   rts

PriceLvTxt: .word TXT_ST_P0, TXT_ST_P1, TXT_ST_P2, TXT_ST_P3

SH_PRECO = 15
SH_MAPA  = 16
SH_TROF  = 17
SH_MENU  = 18               ; voltar ao menu (titulo): salva e sai do jogo
SH_ABRIR = 19
SH_N     = 20
SH_VIS   = 6               ; itens visiveis (a lista rola)

ShopMsgs: .word TXT_SM_OK, TXT_SM_SEM, TXT_SM_BLOQ, TXT_SM_REP, TXT_SM_MAX, TXT_SM_ATIVO

ShopSprite:
    .a8
    .i16
    jsr OamClear
    ; icones dos itens visiveis (o escolhido pula)
    lda menu_top
    sta loop_j
@ic:
    A16
    lda #18
    sta spr_x
    lda loop_j
    and #$00FF
    tax
    A8
    lda f:IconPalTab,x
    asl a
    ora #$30
    sta spr_attr
    ; tile = (i % 8) * 2 + (i / 8) * 32
    txa
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
    ; y = (6 + 2 * (i - topo)) * 8 - 4
    lda loop_j
    sec
    sbc menu_top
    asl a
    clc
    adc #6
    asl a
    asl a
    asl a
    sec
    sbc #5
    sta spr_y
    lda loop_j
    cmp menu_sel
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
:   lda #1
    sta spr_size
    jsr AddSprite
    stz spr_size
    inc loop_j
    lda loop_j
    cmp #SH_N
    beq :+
    sec
    sbc menu_top
    cmp #SH_VIS
    bcc @ic
:   A16
    lda #206
    sta spr_x
    A8
    lda #14
    sta spr_y
    lda #$32
    sta spr_attr
    jsr MascotFrame
    jmp AddSprite32

; mantem o item escolhido dentro da janela visivel
ShopScroll:
    .a8
    .i16
    lda menu_sel
    cmp menu_top
    bcs :+
    sta menu_top
    rts
:   sec
    sbc #(SH_VIS-1)
    bcc :+
    cmp menu_top
    bcc :+
    sta menu_top
:   rts

ShopUpdate:
    .a8
    .i16
    jsr ShopSprite
    lda pad_new+1
    and #KH_UP
    beq @nu
    lda menu_sel
    dec a
    bpl :+
    lda #(SH_N-1)
:   sta menu_sel
    stz menu_msg
    jsr ShopScroll
    SFX SFX_CURSOR
    jsr DrawShop
@nu:
    lda pad_new+1
    and #KH_DOWN
    beq @nd
    lda menu_sel
    inc a
    cmp #SH_N
    bcc :+
    lda #0
:   sta menu_sel
    stz menu_msg
    jsr ShopScroll
    SFX SFX_CURSOR
    jsr DrawShop
@nd:
    lda pad_new
    and #KL_A
    bne @buy
    rts
@buy:
    lda menu_sel
    cmp #SH_PRECO
    bne :+
    ; preco do pastel: alterna -1 / normal / +1 / +2
    lda s_price
    inc a
    cmp #4
    bcc @pk
    lda #0
@pk:
    sta s_price
    SFX SFX_OK
    jmp DrawShop
:   cmp #SH_MAPA
    bne :+
    SFX SFX_OK
    lda #ST_MAP
    sta next_state
    rts
:   cmp #SH_TROF
    bne :+
    SFX SFX_OK
    lda #ST_TROF
    sta next_state
    rts
:   cmp #SH_MENU
    bne :+
    jsr SaveGame            ; salva e volta para a tela de titulo (CONTINUAR retoma)
    SFX SFX_OK
    lda #ST_TITLE
    sta next_state
    rts
:   cmp #SH_ABRIR
    bne :+
    jsr SaveGame
    SFX SFX_OK
    lda #ST_PREDAY
    sta next_state
    rts
:   jsr ItemPrice
    A16
    lda tmp
    cmp #$FFFF
    bne :+
    A8
    lda #5
    bra @msgerr
:   .a16
    cmp #$FFFE
    bne :+
    A8
    lda #3
    bra @msgerr
:   .a16
    cmp #$FFFD
    bne :+
    A8
    lda #6
    bra @msgerr
:   .a16
    cmp #$FFFC
    bne :+
    A8
    lda #4
    bra @msgerr
:   .a16
    ; tem dinheiro?
    lda s_money+2
    bne @pay
    lda s_money
    cmp tmp
    bcs @pay
    A8
    lda #2
@msgerr:
    sta menu_msg
    SFX SFX_ERRO
    jmp DrawShop
@pay:
    .a16
    lda s_money
    sec
    sbc tmp
    sta s_money
    lda s_money+2
    sbc #0
    sta s_money+2
    A8
    lda menu_sel
    A16
    and #$00FF
    asl a
    tax
    A8
    jsr (BuyFn,x)
    lda #1
    sta menu_msg
    SFX SFX_OK
    jsr CheckMission
    jmp DrawShop

BuyFn: .word B0, B1, B2, B3, B4, B5, B6, B7, B8, B9, B10, B11, B12, B13, B14
B0:
    .a8
    .i16
    A16
    lda s_stock
    clc
    adc #10
    sta tmp
    A8
    lda s_freezer
    A16
    beq :+
    lda tmp
    clc
    adc #5
    sta tmp
:   lda tmp
    cmp #999
    bcc :+
    lda #999
:   sta s_stock
    A8
    rts
B1:
    .a8
    .i16
    inc s_fryer
    inc s_upgrades
    rts
B2:
    .a8
    .i16
    inc s_counter
    inc s_upgrades
    rts
B3:
    .a8
    .i16
    lda #1
    sta s_promo
    rts
B4:
    .a8
    .i16
    lda #1
    sta s_attend
    rts
B5:
    .a8
    .i16
    lda #1
    sta s_ads
    rts
B6:
    .a8
    .i16
    inc s_stores
    rts
B7:
    .a8
    .i16
    inc s_fran
    rts
B8: lda #1
    sta s_pc
    rts
B9: lda #1
    sta s_moto
    rts
B10:
    lda #1
    sta s_freezer
    rts
B11:
    lda #1
    sta s_ar
    rts
B12:
    lda #1
    sta s_musica
    rts
B13:
    lda #1
    sta s_unif
    rts
B14:
    inc s_reforma
    rts

; ================================================================ MAPA
MapInit:
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
    jsr OamClear
    PRINT TXT_MP_TIT, 8, 1, 1
    PRINT TXT_MP_LOJAS, 2, 25, 0
    lda s_stores
    inc a
    sta tmp4
    PRINTNUM8 tmp4, 8, 25, 1, 1
    PRINT TXT_HUD_BAR, 9, 25, 0
    lda #5
    sta tmp4
    PRINTNUM8 tmp4, 10, 25, 0, 1
    PRINT TXT_MP_FRAN, 13, 25, 0
    PRINTNUM8 s_fran, 23, 25, 1, 1
    PRINT TXT_HUD_BAR, 24, 25, 0
    PRINTNUM8 tmp4, 25, 25, 0, 1
    PRINT TXT_MP_VOLTAR, 2, 26, 0
    jsr MapUpdate
    jsr ScreenOn
    jsr FadeIn
    rts

StoreXY: .byte 54,128, 114,66, 54,66, 114,128, 173,66
FranXY:  .byte 11,31, 211,29, 11,171, 121,173, 231,121

MapUpdate:
    .a8
    .i16
    jsr OamClear
    lda #1
    sta spr_size
    ; lojas (a primeira sempre existe)
    ldy #0
@st:
    tya
    beq :+
    dec a
    cmp s_stores
    bcs @stdone
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
    ; pulinho
    lda frame
    lsr a
    lsr a
    lsr a
    and #$01
    clc
    adc spr_y
    sta spr_y
    A16
    lda #SPR_LOJA
    sta spr_tile
    A8
    lda #$30
    sta spr_attr
    jsr AddSprite
    ply
    iny
    cpy #5
    bne @st
@stdone:
    ldy #0
@fr:
    tya
    cmp s_fran
    bcs @frdone
    phy
    A16
    tya
    asl a
    tax
    A8
    lda FranXY,x
    sta spr_x
    stz spr_x+1
    lda FranXY+1,x
    sta spr_y
    A16
    lda #SPR_FRANQUIA
    sta spr_tile
    A8
    lda #$30
    sta spr_attr
    jsr AddSprite
    ply
    iny
    cpy #5
    bne @fr
@frdone:
    lda pad_new+1
    and #(KH_B|KH_START)
    bne @back
    lda pad_new
    and #KL_A
    bne @back
    rts
@back:
    lda state
    cmp #ST_MAP
    bne :+
    SFX SFX_CURSOR
    lda #ST_SHOP
    sta next_state
:   rts

; ================================================================ JOGO NOVO / SAVE
NewGame:
    .a8
    .i16
    ldx #0
@c: stz save_start,x
    inx
    cpx #SAVE_SIZE
    bne @c
    lda #'L'
    sta s_magic
    lda #'P'
    sta s_magic+1
    lda #'S'
    sta s_magic+2
    lda #'T'
    sta s_magic+3
    ldx #1
    stx s_day
    ldx #150
    stx s_money
    ldx #25
    stx s_stock
    lda #1
    sta s_level
    sta s_fryer
    sta s_counter
    lda #50
    sta s_rep
    stz menu_sel
    lda #1
    sta s_price
    stz hist_n
    ldx #0
    stx s_trof
    stz s_duels
    stz s_tflags
    stx s_tot_dlv
    stz s_pc
    stz s_moto
    stz s_freezer
    stz s_ar
    stz s_musica
    stz s_unif
    stz s_reforma
    rts

SRAM = $700000
EXT_SRAM = $700300
; espacos de jogo salvo: principal e bloco extra (o espaco 0 e o formato antigo)
SlotBase: .word $0000, $0080, $0100
ExtBase:  .word $0300, $0340, $0380

; soma de verificacao do bloco em RAM -> tmp
SaveSum:
    .a8
    .i16
    ldx #0
    A16
    stz tmp
    A8
@l: lda save_start,x
    A16
    and #$00FF
    clc
    adc tmp
    sta tmp
    A8
    inx
    cpx #SAVE_SIZE
    bne @l
    rts

; tmp2 = base do espaco A (principal), tmp4 = base do bloco extra
SlotAddr:
    .a8
    .i16
    A16
    and #$00FF
    asl a
    tax
    lda SlotBase,x
    sta tmp2
    lda ExtBase,x
    sta tmp4
    A8
    rts

SaveGame:
    .a8
    .i16
    jsr SaveSum
    lda save_slot
    jsr SlotAddr
    ldx tmp2
    ldy #0
@l: lda save_start,y
    sta f:SRAM,x
    inx
    iny
    cpy #SAVE_SIZE
    bne @l
    lda tmp
    sta f:SRAM,x
    lda tmp+1
    sta f:SRAM+1,x
    ; bloco extra
    ldx tmp4
    lda #'E'
    sta f:SRAM,x
    lda #'W'
    sta f:SRAM+1,x
    ldy #0
@e: lda s_price,y
    sta f:SRAM+2,x
    inx
    iny
    cpy #29
    bne @e
    rts

; grava so o byte s_tflags no bloco extra do espaco atual (o bloco extra nao
; tem soma de verificacao; NewGame ja gravou o espaco inteiro)
SaveTFlags:
    .a8
    .i16
    ldx tmp2
    phx
    ldx tmp4
    phx
    lda save_slot
    jsr SlotAddr
    ldx tmp4
    lda s_tflags
    sta f:SRAM+2+(s_tflags-s_price),x
    plx
    stx tmp4
    plx
    stx tmp2
    rts

; A = espaco -> carry = 1 se ha jogo valido (tmp2 = base)
HasSaveSlot:
    .a8
    .i16
    jsr SlotAddr
    ldx tmp2
    lda f:SRAM,x
    cmp #'L'
    bne @no
    lda f:SRAM+1,x
    cmp #'P'
    bne @no
    lda f:SRAM+2,x
    cmp #'S'
    bne @no
    lda f:SRAM+3,x
    cmp #'T'
    bne @no
    A16
    stz tmp
    A8
    ldy #0
@l: lda f:SRAM,x
    A16
    and #$00FF
    clc
    adc tmp
    sta tmp
    A8
    inx
    iny
    cpy #SAVE_SIZE
    bne @l
    lda f:SRAM,x
    cmp tmp
    bne @no
    lda f:SRAM+1,x
    cmp tmp+1
    bne @no
    sec
    rts
@no:
    clc
    rts

; carry = 1 se algum espaco tem jogo
HasSave:
    .a8
    .i16
    lda #0
    jsr HasSaveSlot
    bcs @y
    lda #1
    jsr HasSaveSlot
    bcs @y
    lda #2
    jsr HasSaveSlot
@y: rts

LoadGame:
    .a8
    .i16
    lda save_slot
    jsr SlotAddr
    ldx tmp2
    ldy #0
@l: lda f:SRAM,x
    sta save_start,y
    inx
    iny
    cpy #SAVE_SIZE
    bne @l
    stz menu_sel
    lda #1
    sta s_price
    stz hist_n
    ldx #0
    stx s_trof
    stz s_duels
    stz s_tflags
    stx s_tot_dlv
    stz s_pc
    stz s_moto
    stz s_freezer
    stz s_ar
    stz s_musica
    stz s_unif
    stz s_reforma
    ; bloco extra: 'EW' = 29, 'EZ' = 24, 'EY' = 20 (trofeus), 'EX' = antigo de 16
    ldx tmp4
    lda f:SRAM,x
    cmp #'E'
    bne @x
    ldy #29
    lda f:SRAM+1,x
    cmp #'W'
    beq :+
    ldy #24
    cmp #'Z'
    beq :+
    ldy #20
    cmp #'Y'
    beq :+
    ldy #16
    cmp #'X'
    bne @x
:   sty tmp
    ldy #0
@e: lda f:SRAM+2,x
    sta s_price,y
    inx
    iny
    cpy tmp
    bne @e
    lda s_price
    cmp #4
    bcc @x
    lda #1
    sta s_price
@x: rts
