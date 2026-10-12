; =====================================================================
;  LOS PASTELLES: O IMPERIO DO PASTEL  -  ROM de Super Nintendo
;  Montador: ca65 (cc65).  Mapa: LoROM SlowROM, 1 MB, 2 KB SRAM
;  Convencao: A 8 bits / X,Y 16 bits, DBR = $80, D = $0000
; =====================================================================
.p816
.smart -

; ---------------------------------------------------------------- registradores
INIDISP  = $2100
OBSEL    = $2101
OAMADDL  = $2102
BGMODE   = $2105
BG1SC    = $2107
BG2SC    = $2108
BG3SC    = $2109
BG12NBA  = $210B
BG34NBA  = $210C
BG1HOFS  = $210D
BG1VOFS  = $210E
BG2HOFS  = $210F
BG2VOFS  = $2110
BG3HOFS  = $2111
BG3VOFS  = $2112
VMAIN    = $2115
VMADDL   = $2116
CGADD    = $2121
TM       = $212C
APUIO0   = $2140
APUIO1   = $2141
APUIO2   = $2142
APUIO3   = $2143
NMITIMEN = $4200
WRMPYA   = $4202
WRMPYB   = $4203
WRDIVL   = $4204
WRDIVB   = $4206
MDMAEN   = $420B
MEMSEL   = $420D
RDNMI    = $4210
HVBJOY   = $4212
RDDIVL   = $4214
RDMPYL   = $4216
JOY1L    = $4218

; VRAM (enderecos em palavras)
VRAM_BG1TILES = $0000
VRAM_BG3TILES = $4000
VRAM_BG1MAP   = $5000
VRAM_BG3MAP   = $5400
VRAM_BG2MAP   = $5800   ; xadrez dos menus
VRAM_OBJ      = $6000

; botoes (byte alto de pad)
KH_B     = $80
KH_Y     = $40
KH_SEL   = $20
KH_START = $10
KH_UP    = $08
KH_DOWN  = $04
KH_LEFT  = $02
KH_RIGHT = $01
; botoes (byte baixo)
KL_A     = $80
KL_X     = $40
KL_L     = $20
KL_R     = $10

.include "src/macros.inc"
.include "gen/assets.inc"

; ---------------------------------------------------------------- variaveis
.segment "ZEROPAGE"
tmp:        .res 2
tmp2:       .res 2
tmp3:       .res 2
tmp4:       .res 2
dma_src:    .res 3
dma_len:    .res 2
frame:      .res 2
nmi_ready:  .res 1
bright:     .res 1
bg3_dirty:  .res 1
pal_dirty:  .res 1
pad:        .res 2
pad_old:    .res 2
pad_new:    .res 2
rng:        .res 2
state:      .res 1
next_state: .res 1
oam_idx:    .res 2
spr_x:      .res 2
spr_y:      .res 1
spr_tile:   .res 2
spr_attr:   .res 1
spr_size:   .res 1
spr_hi:     .res 1
txt_pos:    .res 2
txt_attr:   .res 1
txt_ptr:    .res 3
num:        .res 4
num_w:      .res 2
num_pad:    .res 1
mptr:       .res 2
ch_x:       .res 2
ch_x2:      .res 2
tmp_note:   .res 1
tmp_vreg:   .res 1
tmp_pitch:  .res 2
apu_cnt:    .res 1
apu_ult:    .res 1      ; ultimo valor enviado na porta 0 (espera o eco dele)
kon_pend:   .res 1
kof_pend:   .res 1
cur_song:   .res 1
sfx_next:   .res 1
sizzle_on:  .res 1
sizzle_want:.res 1
lag_count:  .res 2
dim_on:     .res 1
tw_ptr:     .res 3      ; texto letra por letra (ponteiro longo)
vz_ptr:     .res 3      ; falas: ponteiro longo na ROM (src/voz.s)
mu_ptr:     .res 3      ; musica gravada: ponteiro longo na ROM
lt_b0:      .res 1      ; lote do stream (src/voz.s)
lt_b1:      .res 1
lt_b2:      .res 1
lt_n:       .res 2
lt_ant:     .res 2

.segment "BSS"
oam_buf:    .res 544
bg3_buf:    .res 2048
cgram_buf:  .res 512
numdig:     .res 8
numstr:     .res 10
ch_ptr:     .res 12
ch_loop:    .res 12
ch_wait:    .res 6
ch_on:      .res 6

.include "src/vars.inc"

; =====================================================================
.segment "CODE"

EmptyHandler:
    rti

ResetHandler:
    sei
    clc
    xce
    jml FastReset
FastReset:
    rep #$38
    .a16
    .i16
    ldx #$1FFF
    txs
    lda #$0000
    tcd
    A8
    lda #$80
    pha
    plb
    lda #$01
    sta MEMSEL
    lda #$8F
    sta INIDISP
    stz NMITIMEN
    ; zera a RAM baixa ($0000-$1EFF)
    ldx #0
@clr:
    stz $0000,x
    inx
    cpx #$1F00
    bne @clr
    jsr InitHardware
    jsr ClearVram
    jsr ApuUpload
    jsr AudioInit
    jsr LoadOptions
    A16
    lda #$ACE1
    sta rng
    A8
    lda #$FF
    sta cur_song
    ; graficos permanentes: sprites, fonte
    lda #$80
    sta VMAIN
    VRAM_LOAD SprTiles, VRAM_OBJ, 16384
    VRAM_LOAD FontTiles, VRAM_BG3TILES, (FontTiles_end - FontTiles)
    ; registradores de video
    lda #$09                ; modo 1, BG3 com prioridade alta
    sta BGMODE
    lda #(VRAM_BG1MAP >> 8)
    sta BG1SC
    lda #(VRAM_BG3MAP >> 8)
    sta BG3SC
    lda #(VRAM_BG2MAP >> 8)
    sta BG2SC
    lda #(VRAM_BG1TILES >> 12)
    sta BG12NBA
    lda #(VRAM_BG3TILES >> 12)
    sta BG34NBA
    lda #(VRAM_OBJ >> 13)    ; sprites 8x8 / 16x16
    sta OBSEL
    lda #$FF
    sta BG1VOFS
    lda #$03
    sta BG1VOFS
    lda #$FF
    sta BG3VOFS
    lda #$03
    sta BG3VOFS
    lda #$15                ; BG1 + BG3 + OBJ
    sta TM
    jsr OamClear
    jsr ClearBg3
    stz bright
    lda #$FF
    sta next_state
    lda #ST_SPLASH
    sta next_state
    jsr UiOff
    lda #$81                ; NMI + leitura automatica do controle
    sta NMITIMEN

MainLoop:
    .a8
    .i16
    lda next_state
    cmp #$FF
    beq @run
    sta state
    lda #$FF
    sta next_state
    ldx #0
    stx pad_new
    A16
    lda state
    and #$00FF
    asl a
    tax
    A8
    jsr (StateInit,x)
    bra MainLoop
@run:
    A16
    lda state
    and #$00FF
    asl a
    tax
    A8
    jsr (StateUpdate,x)
    jsr UiUpdate
    jsr AudioUpdate
    jsr WaitFrame
    jsr ReadPad
    jsr DemoControle        ; demonstracao: a CPU joga (ou um botao encerra)
    bra MainLoop

; ---------------------------------------------------------------- NMI
NmiHandler:
    jml NmiFast
NmiFast:
    rep #$30
    .a16
    .i16
    pha
    phx
    phy
    phb
    phd
    lda #$0000
    tcd
    A8
    lda #$80
    pha
    plb
    lda RDNMI
    lda nmi_ready
    bne :+
    jmp @late
:   ; OAM
    ldx #0
    stx OAMADDL
    stz $4300
    lda #$04
    sta $4301
    ldx #.loword(oam_buf)
    stx $4302
    lda #$80
    sta $4304
    ldx #544
    stx $4305
    lda #$01
    sta MDMAEN
    ; mapa BG3
    lda bg3_dirty
    beq @nobg3
    stz bg3_dirty
    lda #$80
    sta VMAIN
    ldx #VRAM_BG3MAP
    stx VMADDL
    lda #$01
    sta $4300
    lda #$18
    sta $4301
    ldx #.loword(bg3_buf)
    stx $4302
    lda #$80
    sta $4304
    ldx #2048
    stx $4305
    lda #$01
    sta MDMAEN
@nobg3:
    lda pal_dirty
    beq @nopal
    stz pal_dirty
    stz CGADD
    stz $4300
    lda #$22
    sta $4301
    ldx #.loword(cgram_buf)
    stx $4302
    lda #$80
    sta $4304
    ldx #512
    stx $4305
    lda #$01
    sta MDMAEN
@nopal:
    stz nmi_ready
    bra @upd
@late:
    ; quadro atrasado: a logica nao terminou a tempo
    A16
    inc lag_count
    A8
@upd:
    stz $212E               ; janelas (so o tutorial usa)
    stz $2123
    ; escurece o cenario na pausa (subtracao de cor no BG1 e sprites)
    lda dim_on
    beq @nodim
    stz HDMAEN
    lda #$15
    sta TM
    stz $2130
    lda #$B1
    sta $2131
    lda dim_on              ; 2 = caixa do tutorial: cenario bem mais escuro
    cmp #2
    lda #$EC
    bcc :+
    jsr TutNmi
    lda #$F6
:   sta $2132
    bra @dimd
@nodim:
    jsr UiNmi
@dimd:
    lda bright
    sta INIDISP
    A16
    inc frame
    rep #$30
    pld
    plb
    ply
    plx
    pla
    rti

; ---------------------------------------------------------------- hardware
InitHardware:
    .a8
    .i16
    ldx #$2101
@a: stz $0000,x
    inx
    cpx #$210D
    bne @a
@b: stz $0000,x
    stz $0000,x
    inx
    cpx #$2115
    bne @b
    lda #$80
    sta VMAIN
    stz $2116
    stz $2117
    stz $211A
    stz $211B
    lda #$01
    sta $211B
    stz $211C
    stz $211C
    stz $211D
    stz $211D
    stz $211E
    sta $211E
    stz $211F
    stz $211F
    stz $2120
    stz $2120
    ldx #$2121
@c: stz $0000,x
    inx
    cpx #$2134
    bne @c
    lda #$30
    sta $2130
    lda #$E0
    sta $2132
    lda #$FF
    sta $4201
    ldx #$4202
@d: stz $0000,x
    inx
    cpx #$420D
    bne @d
    rts

ClearVram:
    .a8
    .i16
    lda #$80
    sta VMAIN
    ldx #0
    stx VMADDL
    lda #$09
    sta $4300
    lda #$18
    sta $4301
    ldx #.loword(ZeroWord)
    stx $4302
    lda #^ZeroWord
    sta $4304
    ldx #0
    stx $4305
    lda #$01
    sta MDMAEN
    rts

; DMA: dma_src -> VRAM (endereco ja definido em VMADDL)
DmaVram:
    .a8
    .i16
    lda #$01
    sta $4300
    lda #$18
    sta $4301
    ldx dma_src
    stx $4302
    lda dma_src+2
    sta $4304
    ldx dma_len
    stx $4305
    lda #$01
    sta MDMAEN
    rts

; copia Y bytes de [dma_src] para cgram_buf+X
CopyPal:
    .a8
    .i16
    sty tmp
    ldy #0
@l: lda [dma_src],y
    sta cgram_buf,x
    inx
    iny
    cpy tmp
    bne @l
    lda #1
    sta pal_dirty
    rts

; tela desligada (para carregar graficos fora do vblank)
ScreenOff:
    .a8
    .i16
    lda #$80
    sta bright
    sta INIDISP
    lda #$01
    sta NMITIMEN
    rts
ScreenOn:
    .a8
    .i16
    lda #$81
    sta NMITIMEN
    rts

; espera o proximo quadro (o NMI envia os buffers)
WaitFrame:
    .a8
    .i16
    lda #1
    sta nmi_ready
@w: jsr Bomba               ; tempo ocioso: alimenta os streams (falas e musica)
    lda nmi_ready
    bne @w
    rts

ReadPad:
    .a8
    .i16
@w: lda HVBJOY
    and #$01
    bne @w
    A16
    lda JOY1L
    sta pad
    lda pad_old
    eor #$FFFF
    and pad
    sta pad_new
    lda pad
    sta pad_old
    A8
    rts

FadeIn:
    .a8
    .i16
    stz bright
@l: jsr WaitFrame
    jsr AudioUpdate
    lda bright
    inc a
    sta bright
    cmp #$0F
    bne @l
    rts
FadeOut:
    .a8
    .i16
    lda bright
    and #$0F
    sta bright
@l: jsr WaitFrame
    jsr AudioUpdate
    lda bright
    beq @done
    dec a
    sta bright
    bra @l
@done:
    rts

; espera A quadros
Delay:
    .a8
    .i16
    sta tmp4
@l: jsr WaitFrame
    jsr AudioUpdate
    dec tmp4
    bne @l
    rts

; ---------------------------------------------------------------- aleatorio
Rand:
    .a8
    .i16
    A16
    lda rng
    lsr a
    bcc :+
    eor #$B400
:   sta rng
    A8
    rts
; A = n (1..255) -> A = 0..n-1
RandBelow:
    .a8
    .i16
    pha
    jsr Rand
    jsr Rand
    sta WRMPYA
    pla
    sta WRMPYB
    nop
    nop
    nop
    nop
    lda RDMPYL+1
    rts

; ---------------------------------------------------------------- texto (BG3)
ClearBg3:
    .a8
    .i16
    stz tw_on
    ldx #0
@l: stz bg3_buf,x
    inx
    cpx #2048
    bne @l
    lda #1
    sta bg3_dirty
    rts

; apaga a linha A (0..31) da camada de texto
ClearRow:
    .a8
    .i16
    A16
    and #$00FF
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    tax
    A8
    ldy #32
@l: stz bg3_buf,x
    stz bg3_buf+1,x
    inx
    inx
    dey
    bne @l
    lda #1
    sta bg3_dirty
    rts

; X = endereco do texto (banco $80); txt_pos = linha*32+coluna; txt_attr
PrintStr:
    .a8
    .i16
    lda #0                  ; textos comuns ficam no banco 0
; X = endereco, A = banco (textos das cartas)
PrintStrB:
    .a8
    .i16
    sta txt_ptr+2
    stx txt_ptr
    A16
    lda txt_pos
    asl a
    tax
    sta tmp2
    A8
    ldy #0
@lp:
    lda [txt_ptr],y
    cmp #$FF
    beq @done
    cmp #$FE
    bne @ch
    A16
    lda tmp2
    clc
    adc #64
    sta tmp2
    tax
    A8
    iny
    bra @lp
@ch:
    sta bg3_buf,x
    cmp #FONT_BTN0
    bcc @attr
    cmp #(FONT_BTN0+N_BTN)
    bcs @attr
    jsr BtnReg              ; botao: o sprite colorido e desenhado por cima
@attr:
    lda txt_attr
    sta bg3_buf+1,x
    inx
    inx
    iny
    bra @lp
@done:
    lda #1
    sta bg3_dirty
    rts

; num (32 bits) -> numdig[8]
NumConv:
    .a8
    .i16
    ldx #0
    ldy #0
@digit:
    lda #0
    sta numdig,y
    A16
@sub:
    lda num
    sec
    sbc Pow10,x
    sta tmp
    lda num+2
    sbc Pow10+2,x
    bcc @next
    sta num+2
    lda tmp
    sta num
    A8
    lda numdig,y
    inc a
    sta numdig,y
    A16
    bra @sub
@next:
    A8
    inx
    inx
    inx
    inx
    iny
    cpy #8
    bne @digit
    rts

; imprime num com largura num_w (espacos a esquerda)
PrintNum:
    .a8
    .i16
    jsr NumConv
    A16
    lda num_w
    and #$00FF
    sta tmp3
    lda #8
    sec
    sbc tmp3
    tax
    A8
    ldy #0
    stz tmp3
@lp:
    lda numdig,x
    bne @nz
    lda tmp3
    bne @dig
    cpx #7
    beq @dig
    lda num_pad
    bra @put
@nz:
    inc tmp3
@dig:
    lda numdig,x
    clc
    adc #FONT_0
@put:
    sta numstr,y
    iny
    inx
    cpx #8
    bne @lp
    lda #$FF
    sta numstr,y
    stz num_pad
    ldx #numstr
    jmp PrintStr

; ---------------------------------------------------------------- sprites
OamClear:
    .a8
    .i16
    ldx #0
    lda #$F0
@l: stz oam_buf,x
    sta oam_buf+1,x
    stz oam_buf+2,x
    stz oam_buf+3,x
    inx
    inx
    inx
    inx
    cpx #512
    bne @l
    ldx #0
@h: stz oam_buf+512,x
    inx
    cpx #32
    bne @h
    ldx #0
    stx oam_idx
    rts

; adiciona sprite: spr_x(16, com sinal), spr_y, spr_tile(9 bits), spr_attr, spr_size(0=8x8 1=16x16)
AddSprite:
    .a8
    .i16
    A16
    lda spr_x
    bmi @neg
    cmp #256
    bcs @skip16
    bra @ok
@neg:
    cmp #$FFE1
    bcc @skip16
@ok:
    A8
    ldx oam_idx
    cpx #OAM_BTN            ; os ultimos slots ficam para os botoes do texto
    bcs @skip
    lda spr_x
    sta oam_buf,x
    lda spr_y
    sta oam_buf+1,x
    lda spr_tile
    sta oam_buf+2,x
    lda spr_tile+1
    and #$01
    ora spr_attr
    sta oam_buf+3,x
    ; bits altos: x9 e tamanho
    lda spr_x+1
    and #$01
    sta spr_hi
    lda spr_size
    beq :+
    lda spr_hi
    ora #$02
    sta spr_hi
:   lda spr_hi
    beq @adv
    A16
    txa
    lsr a
    lsr a
    and #$0003
    tay
    txa
    lsr a
    lsr a
    lsr a
    lsr a
    tax
    A8
    lda spr_hi
@sh:
    cpy #0
    beq @shd
    asl a
    asl a
    dey
    bra @sh
@shd:
    ora oam_buf+512,x
    sta oam_buf+512,x
@adv:
    A16
    lda oam_idx
    clc
    adc #4
    sta oam_idx
@skip16:
    A8
@skip:
    rts

; sprite 32x32 (4 sprites de 16x16) em spr_x/spr_y, spr_tile = canto superior esquerdo
AddSprite32:
    .a8
    .i16
    lda #1
    sta spr_size
    jsr AddSprite
    A16
    lda spr_x
    clc
    adc #16
    sta spr_x
    inc spr_tile
    inc spr_tile
    A8
    jsr AddSprite
    lda spr_y
    clc
    adc #16
    sta spr_y
    A16
    lda spr_tile
    clc
    adc #32
    sta spr_tile
    A8
    jsr AddSprite
    A16
    lda spr_x
    sec
    sbc #16
    sta spr_x
    dec spr_tile
    dec spr_tile
    A8
    jsr AddSprite
    lda spr_y
    sec
    sbc #16
    sta spr_y
    A16
    lda spr_tile
    sec
    sbc #32
    sta spr_tile
    A8
    rts

; ---------------------------------------------------------------- paletas comuns
LoadBasePalettes:
    .a8
    .i16
    PAL_LOAD TextPal, 0, 64
    PAL_LOAD SprPal, 128, 256
    rts

.include "src/audio.s"
.include "src/voz.s"
.include "src/game.s"
.include "src/telas.s"
.include "src/extra.s"
.include "src/segredo.s"
.include "src/ui.s"
.include "src/demo.s"

; ---------------------------------------------------------------- dados
.segment "RODATA"
ZeroWord: .word 0
Pow10: .dword 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1
.include "gen/data.inc"

.segment "BANK1"
SprTiles:   .incbin "gen/spr_tiles.bin"
FontTiles:  .incbin "gen/font.bin"
FontTiles_end:
    .a8
    .i16
SprPal:     .incbin "gen/spr_pal.bin"
PortPal:    .incbin "gen/port_pal.bin"
PortGfx:    .incbin "gen/port_tiles.bin"
TextPal:    .incbin "gen/text_pal.bin"
SpcBlob:    .incbin "gen/spc.bin"

.segment "BANK12"
UiPanelTab: .incbin "gen/ui_panel.bin"
UiHudTab:   .incbin "gen/ui_hud.bin"
UiBand8:    .incbin "gen/ui_band8.bin"
UiBand16:   .incbin "gen/ui_band16.bin"
UiOpenTab:  .incbin "gen/ui_open.bin"
IconGfx:    .incbin "gen/icon_tiles.bin"
IconGfx_end:
IconPal:    .incbin "gen/icon_pal.bin"
.include "gen/icon_pal.inc"
.include "gen/voz.inc"         ; tabelas das vozes (acesso longo, f:)
.segment "BANK11"
.include "gen/cards.inc"

.segment "BANK2"
MenuTiles:  .incbin "gen/menu_tiles.bin"
MenuTiles_end:
    .a8
    .i16
MenuMap:    .incbin "gen/menu_map.bin"
MenuPal:    .incbin "gen/menu_pal.bin"
MenuChkTiles: .incbin "gen/menu_chk_tiles.bin"
MenuChkTiles_end:
MenuChkMap:   .incbin "gen/menu_chk_map.bin"
ChkPal:     .incbin "gen/chk_pal.bin"
TutTiles:   .incbin "gen/tut_tiles.bin"
TutTiles_end:
TutMap:     .incbin "gen/tut_map.bin"
TutPal:     .incbin "gen/tut_pal.bin"

.segment "BANK3"
TitleTiles: .incbin "gen/title_tiles.bin"
TitleTiles_end:
    .a8
    .i16
TitleMap:   .incbin "gen/title_map.bin"
TitlePal:   .incbin "gen/title_pal.bin"

.segment "BANK5"
LogoTiles:  .incbin "gen/logo_tiles.bin"
LogoTiles_end:
LogoMap:    .incbin "gen/logo_map.bin"
LogoPal:    .incbin "gen/logo_pal.bin"

.segment "BANK4"
MapTiles:   .incbin "gen/map_tiles.bin"
MapTiles_end:
    .a8
    .i16
MapMap:     .incbin "gen/map_map.bin"
MapPal:     .incbin "gen/map_pal.bin"

.segment "BANK6"
Shop0_0Tiles: .incbin "gen/shop0_0_tiles.bin"
Shop0_0Tiles_end:
Shop0_0Map:   .incbin "gen/shop0_0_map.bin"
Shop0_0Pal:   .incbin "gen/shop0_0_pal.bin"
Shop0_1Tiles: .incbin "gen/shop0_1_tiles.bin"
Shop0_1Tiles_end:
Shop0_1Map:   .incbin "gen/shop0_1_map.bin"
Shop0_1Pal:   .incbin "gen/shop0_1_pal.bin"
Shop0_2Tiles: .incbin "gen/shop0_2_tiles.bin"
Shop0_2Tiles_end:
Shop0_2Map:   .incbin "gen/shop0_2_map.bin"
Shop0_2Pal:   .incbin "gen/shop0_2_pal.bin"

.segment "BANK7"
Shop1_0Tiles: .incbin "gen/shop1_0_tiles.bin"
Shop1_0Tiles_end:
Shop1_0Map:   .incbin "gen/shop1_0_map.bin"
Shop1_0Pal:   .incbin "gen/shop1_0_pal.bin"
Shop1_1Tiles: .incbin "gen/shop1_1_tiles.bin"
Shop1_1Tiles_end:
Shop1_1Map:   .incbin "gen/shop1_1_map.bin"
Shop1_1Pal:   .incbin "gen/shop1_1_pal.bin"
Shop1_2Tiles: .incbin "gen/shop1_2_tiles.bin"
Shop1_2Tiles_end:
Shop1_2Map:   .incbin "gen/shop1_2_map.bin"
Shop1_2Pal:   .incbin "gen/shop1_2_pal.bin"

.segment "BANK8"
Shop2_0Tiles: .incbin "gen/shop2_0_tiles.bin"
Shop2_0Tiles_end:
Shop2_0Map:   .incbin "gen/shop2_0_map.bin"
Shop2_0Pal:   .incbin "gen/shop2_0_pal.bin"
Shop2_1Tiles: .incbin "gen/shop2_1_tiles.bin"
Shop2_1Tiles_end:
Shop2_1Map:   .incbin "gen/shop2_1_map.bin"
Shop2_1Pal:   .incbin "gen/shop2_1_pal.bin"
Shop2_2Tiles: .incbin "gen/shop2_2_tiles.bin"
Shop2_2Tiles_end:
Shop2_2Map:   .incbin "gen/shop2_2_map.bin"
Shop2_2Pal:   .incbin "gen/shop2_2_pal.bin"

.segment "BANK9"
Shop3_0Tiles: .incbin "gen/shop3_0_tiles.bin"
Shop3_0Tiles_end:
Shop3_0Map:   .incbin "gen/shop3_0_map.bin"
Shop3_0Pal:   .incbin "gen/shop3_0_pal.bin"
Shop3_1Tiles: .incbin "gen/shop3_1_tiles.bin"
Shop3_1Tiles_end:
Shop3_1Map:   .incbin "gen/shop3_1_map.bin"
Shop3_1Pal:   .incbin "gen/shop3_1_pal.bin"
Shop3_2Tiles: .incbin "gen/shop3_2_tiles.bin"
Shop3_2Tiles_end:
Shop3_2Map:   .incbin "gen/shop3_2_map.bin"
Shop3_2Pal:   .incbin "gen/shop3_2_pal.bin"

.segment "BANK10"
Shop4_0Tiles: .incbin "gen/shop4_0_tiles.bin"
Shop4_0Tiles_end:
Shop4_0Map:   .incbin "gen/shop4_0_map.bin"
Shop4_0Pal:   .incbin "gen/shop4_0_pal.bin"
Shop4_1Tiles: .incbin "gen/shop4_1_tiles.bin"
Shop4_1Tiles_end:
Shop4_1Map:   .incbin "gen/shop4_1_map.bin"
Shop4_1Pal:   .incbin "gen/shop4_1_pal.bin"
Shop4_2Tiles: .incbin "gen/shop4_2_tiles.bin"
Shop4_2Tiles_end:
Shop4_2Map:   .incbin "gen/shop4_2_map.bin"
Shop4_2Pal:   .incbin "gen/shop4_2_pal.bin"

; vozes e musica gravadas (bancos 13+)
.include "gen/sons.inc"

; ---------------------------------------------------------------- cabecalho
.segment "HEADER"
    .byte "LOS PASTELLES        "
    .byte $20               ; LoROM
    .byte $02               ; ROM + RAM + bateria
    .byte $0A               ; 1 MB
    .byte $01               ; 2 KB de SRAM
    .byte $01               ; America do Norte (NTSC)
    .byte $00
    .byte $00
    .word $FFFF
    .word $0000

.segment "VECTORS"
    .word 0, 0
    .word .loword(EmptyHandler)     ; COP
    .word .loword(EmptyHandler)     ; BRK
    .word .loword(EmptyHandler)     ; ABORT
    .word .loword(NmiHandler)       ; NMI
    .word 0
    .word .loword(EmptyHandler)     ; IRQ
    .word 0, 0
    .word .loword(EmptyHandler)     ; COP
    .word 0
    .word .loword(EmptyHandler)     ; ABORT
    .word .loword(EmptyHandler)     ; NMI
    .word .loword(ResetHandler)     ; RESET
    .word .loword(EmptyHandler)     ; IRQ/BRK
