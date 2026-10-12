; ---------------------------------------------------------------- variaveis do jogo
.segment "BSS"

; ===== bloco salvo na SRAM (manter contiguo) =====
save_start:
s_magic:    .res 4
s_day:      .res 2
s_money:    .res 4
s_stock:    .res 2
s_level:    .res 1
s_xp:       .res 2
s_rep:      .res 1
s_fryer:    .res 1      ; 1..3 (cestos = nivel + 1)
s_counter:  .res 1      ; 1..3 (lugares = nivel + 1)
s_attend:   .res 1
s_ads:      .res 1
s_stores:   .res 1      ; lojas extras 0..4
s_fran:     .res 1      ; franquias 0..5
s_boss:     .res 1      ; desafios vencidos 0..4
s_mission:  .res 1
s_promo:    .res 1
s_upgrades: .res 1
s_ending:   .res 1
s_chapter:  .res 1      ; capitulo ja anunciado
s_tot_fried:.res 2
s_tot_sales:.res 4
s_tot_happy:.res 2
s_tot_perf: .res 2
save_end:
SAVE_SIZE = save_end - save_start

; ===== estado do dia =====
d_timer:    .res 2
d_hour:     .res 1
d_min:      .res 1
d_sub:      .res 1
d_closed:   .res 1
d_endwait:  .res 1
d_served:   .res 1
d_total:    .res 1
d_perfect:  .res 1
d_waste:    .res 1
d_happy:    .res 1
d_sales:    .res 2
d_tips:     .res 2
d_spawn:    .res 2
d_boss:     .res 1      ; $FF = dia normal
d_event:    .res 1      ; 0 nenhum, 1 concorrente, 2 feira
d_broke:    .res 1      ; cesto quebrado ($FF nenhum)
d_goal:     .res 1
d_mystery:  .res 1      ; ja veio cliente misterioso
d_myst_ok:  .res 1
d_paused:   .res 1
d_patrate:  .res 2
d_speed:    .res 2
d_xp:       .res 2
msg_timer:  .res 1

n_flav:     .res 1
n_fry:      .res 1
n_cnt:      .res 1

; clientes (4)
c_state:    .res 4
c_var:      .res 4
c_order:    .res 4
c_timer:    .res 4
c_x:        .res 8
c_tx:       .res 8
c_pat:      .res 8

; cestos (4)
f_state:    .res 4
f_flav:     .res 4
f_burnt:    .res 4
f_prog:     .res 8

hold_flav:  .res 1
hold_q:     .res 1
hold_soda:  .res 1
mg_on:      .res 1
mg_flav:    .res 1
mg_len:     .res 1
mg_pos:     .res 1
mg_seq:     .res 6
mg_timer:   .res 2
c_combo:    .res 4
c_qty:      .res 4
c_rate:     .res 8
d_lost:     .res 1
coin_t:     .res 1
coin_x:     .res 2
coin_y:     .res 1
r_newtrof:  .res 2
code_pos:   .res 1
dance_cnt:  .res 1
dance_t:    .res 1
; entregas (comandas)
dv_on:      .res 3
dv_flav:    .res 3
dv_qty:     .res 3
dv_qtot:    .res 3
dv_app:     .res 3
dv_t:       .res 6
ph_ring:    .res 2
dv_spawn:   .res 2
pc_flash:   .res 1
moto_x:     .res 2
moto_on:    .res 1
d_deliv:    .res 1
d_dvsales:  .res 2
save_slot:  .res 1
sl_conf:    .res 1
sl_mode:    .res 1
r_duel:     .res 1
tut_step:   .res 1
tut_box:    .res 1
tut_shown:  .res 1
fry_lim:    .res 2      ; teto do progresso da fritura (no tutorial para no ponto)
pause_sel:  .res 1
splash_t:   .res 2
masc_t:     .res 1
opt_diff:   .res 1
opt_music:  .res 1
opt_falas:  .res 1      ; vozes gravadas ligadas (opcoes)
d_unit:     .res 1
echo_on:    .res 1
; bloco extra salvo em SRAM $700300 (preco + historico de lucro)
s_price:    .res 1      ; 0 = -1, 1 = normal, 2 = +1, 3 = +2
hist_n:     .res 1
hist:       .res 14     ; lucro dos ultimos 7 dias (com sinal)
s_trof:     .res 2      ; trofeus conquistados (bits)
s_duels:    .res 1      ; duelos vencidos
s_tflags:   .res 1      ; bit 0: cliente misterioso satisfeito
s_tot_dlv:  .res 2      ; entregas feitas
s_pc:       .res 1      ; computador de pedidos (app)
s_moto:     .res 1      ; motoboy extra
s_freezer:  .res 1      ; ingredientes rendem +15
s_ar:       .res 1      ; ar-condicionado: mais paciencia
s_musica:   .res 1      ; musica ambiente: +1 de gorjeta
s_unif:     .res 1      ; uniforme: +R$ 1 por pastel
s_reforma:  .res 1      ; reforma do salao 0..2
pop_t:      .res 1
pop_x:      .res 2
pop_val:    .res 2
pop_base:   .res 2
mg_mode:    .res 1
mg_tmax:    .res 2      ; 0 fechar pastel, 1 consertar cesto
d_breakat:  .res 2
d_brkonce:  .res 1
r_page:     .res 1
oil_ph:     .res 1
at_best:    .res 1
at_pat:     .res 2
cur_row:    .res 1
cur_col0:   .res 1
cur_col1:   .res 1
cur_x:      .res 2
cur_y:      .res 1
fnd_x:      .res 2
fnd_anim:   .res 1
fnd_tx:     .res 2

; resultados / economia
r_other:    .res 2
r_rent:     .res 2
r_salary:   .res 2
r_profit:   .res 4      ; com sinal
r_levels:   .res 1
r_oldlvl:   .res 1
r_misdone:  .res 1
r_bossres:  .res 1      ; 0 nada, 1 venceu, 2 perdeu

; fila de cartas
card_q:     .res 12
card_n:     .res 1
card_i:     .res 1
card_next:  .res 1

; menus
menu_sel:   .res 1
menu_top:   .res 1
loop_i:     .res 2
loop_j:     .res 1
lock_lv:    .res 2
menu_msg:   .res 1
title_has_save: .res 1
intro_t:    .res 2
sign_t:     .res 1

; ----- interface (src/ui.s)
ui_mode:    .res 1      ; 0 nada, 1 painel, 2 HUD do expediente
ui_open:    .res 1      ; passo da abertura elastica (0 = parada)
hl_y:       .res 1      ; linha (pixel) do item escolhido; 0 = sem faixa
hl_h:       .res 1      ; altura da faixa: 8 ou 16
hl_cur:     .res 1      ; posicao atual (desliza ate hl_y)
hl_old:     .res 1      ; faixa desenhada no quadro anterior
hl_oldh:    .res 1
ui_ln:      .res 1
ui_cnt:     .res 1
ui_src:     .res 2
tw_on:      .res 1
tw_pos:     .res 2
tw_line:    .res 2
tw_attr:    .res 1
tw_n:       .res 1
hdma_tab:   .res 452
; slots reservados no fim da OAM: botoes do texto (na frente) e pilula do rodape
PILL_SLOTS = 16
BTN_SLOTS  = 12
OAM_PILL   = 4 * (128 - PILL_SLOTS)
OAM_BTN    = OAM_PILL - 4 * BTN_SLOTS   ; AddSprite nao passa daqui
btn_tab:    .res BTN_SLOTS * 4      ; [posicao no bg3_buf (2), glifo (1; 0 = livre), -]
btn_tpos:   .res 2
; vozes gravadas (src/voz.s)
vz_cur:     .res 1      ; voz tocando ($FF = nenhuma)
vz_carga:   .res 2      ; trios das vozes fixas que faltam carregar (boot)
vz_pri:     .res 1
vz_est:     .res 1      ; stream: 0 parado, 1 enchendo o anel, 2 tocando
vz_resto:   .res 2      ; fixa: quadros que faltam
vz_resta:   .res 3      ; stream: bytes da fonte que faltam
vz_fim:     .res 1      ; a fonte acabou (manda silencio)
vz_sil:     .res 2      ; bytes de silencio ja mandados depois do fim
vz_nivel:   .res 3      ; bytes no anel ainda nao tocados (16.8)
vz_cauda:   .res 3      ; o que faltava tocar quando a fonte acabou (16.8)
vz_bpq:     .res 2      ; bytes tocados por quadro (8.8)
vz_folga:   .res 2      ; bytes a manter no anel
vz_anel:    .res 2      ; posicao de escrita no anel
vz_tri:     .res 3
vz_tmp:     .res 1
vz_tmp2:    .res 2
vz_ultima:  .res VOZ_N * 2   ; quadro em que cada voz tocou (para nao repetir)
vz_modo:    .res 1
tema_pend:  .res 1      ; titulo: musica + narracao quando a carga das vozes acabar
; demonstracao (src/demo.s)
demo_on:    .res 1
demo_ocioso:.res 2
demo_pad:   .res 2
demo_lin:   .res 1
demo_col:   .res 1
demo_falta: .res 6
apu_endx:   .res 1      ; ENDX lido no quadro
mu_est:     .res 1      ; musica gravada: 0 parada, 1 enchendo, 2 tocando
mu_resta:   .res 3
mu_nivel:   .res 3
mu_anel:    .res 2
btn_tcode:  .res 1
; pilula do rodape (Footer em ui.s)
ft_on:      .res 1
ft_pos:     .res 2      ; posicao do 1o caractere no bg3_buf
ft_code:    .res 1      ; glifo esperado ali (se mudar, a pilula some)
ft_x0:      .res 1
ft_x1:      .res 1      ; x da peca da direita
ft_y:       .res 1
