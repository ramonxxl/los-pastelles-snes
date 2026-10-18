-- Robo que joga Los Pastelles lendo a RAM do jogo (teste automatico no Mesen)
-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
dofile(dir .. (BOTCFG or "botcfg.lua"))
local log = io.open(dir .. "bot.txt", "w")
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local function r16(n, i) return r8(n, i) + 256 * r8(n, (i or 0) + 1) end
local function cpu()
  local s = emu.getState()
  return string.format("pc=%02X:%04X a=%04X x=%04X y=%04X p=%02X sp=%04X", s["cpu.k"], s["cpu.pc"], s["cpu.a"], s["cpu.x"], s["cpu.y"], s["cpu.ps"], s["cpu.sp"])
end
local f, wait, shotn, laststate = 0, 0, 0, -1
tirou = {}
local function shot(tag)
  local fh = io.open(dir .. string.format("b%05d_%s.png", f, tag), "wb")
  fh:write(emu.takeScreenshot()) fh:close()
end

local function botday()
  -- caixa do tutorial: espera um pouco com ela pronta (para a foto) e aperta A
  if L["tut_box"] and r8("tut_box") > 0 then
    tutw = (r8("tut_box") == 1) and (tutw or 0) + 1 or 0
    if tutw > 20 then tutw = 0; return "a" end
    return nil
  end
  local nfl, nfr, nct = r8("n_flav"), r8("n_fry"), r8("n_cnt")
  local hold, hq = r8("hold_flav"), r8("hold_q")
  local row, c0, c1 = r8("cur_row"), r8("cur_col0"), r8("cur_col1")
  local broke = r8("d_broke")
  local function go(trow, tcol)
    if row ~= trow then return trow == 0 and "up" or "down" end
    local c = (trow == 0) and c0 or c1
    if c < tcol then return "right" elseif c > tcol then return "left" end
    return "a"
  end
  if r16("ph_ring") > 0 and hold == 255 then return "y" end
  if r8("mg_on") == 1 then
    local names = {"up", "down", "left", "right", "a", "b", "x", "y"}
    return names[r8("mg_seq", r8("mg_pos")) + 1]
  end
  if hold == 255 and broke ~= 255 and broke < nfr then return go(1, nfl + broke) end
  if hold ~= 255 then
    if hq == 0 or hq == 3 then return "b" end
    for s = 0, nct - 1 do
      if r8("c_state", s) == 2 and r8("c_order", s) == hold then
        if r8("c_combo", s) == 1 and r8("hold_soda") == 0 then return "x" end
        return go(0, s)
      end
    end
    for t = 0, 2 do
      if r8("dv_on", t) == 1 and r8("dv_qty", t) > 0 and r8("dv_flav", t) == hold then return "y" end
    end
    return nil
  end
  for j = 0, nfr - 1 do
    if j ~= broke and r8("f_state", j) == 1 then
      local hi = r8("f_prog", j * 2 + 1)
      if (hi >= 168 and hi < 232) or hi >= 235 then return go(1, nfl + j) end
    end
  end
  local need = {}
  for s = 0, nct - 1 do
    local st = r8("c_state", s)
    if st == 1 or st == 2 then local o = r8("c_order", s); need[o] = (need[o] or 0) + 1 end
  end
  for t = 0, 2 do
    if r8("dv_on", t) == 1 then local o = r8("dv_flav", t); need[o] = (need[o] or 0) + r8("dv_qty", t) end
  end
  for j = 0, nfr - 1 do if r8("f_state", j) == 1 then local o = r8("f_flav", j); if need[o] then need[o] = need[o] - 1 end end end
  local free = false
  for j = 0, nfr - 1 do if j ~= broke and r8("f_state", j) == 0 then free = true end end
  if free and r16("s_stock") > 0 then
    for o = 0, nfl - 1 do if need[o] and need[o] > 0 then return go(1, o) end end
  end
  return nil
end

emu.addEventCallback(function()
  f = f + 1
  if BOT_DESLIGADO then return end          -- o script de teste assumiu o controle
  local st = r8("state")
  if st ~= laststate then
    log:write(string.format("f=%d state=%d dia=%d caixa=%d nivel=%d xp=%d rep=%d estoque=%d missao=%d boss=%d fry=%d cnt=%d\n",
      f, st, r16("s_day"), r16("s_money"), r8("s_level"), r16("s_xp"), r8("s_rep"), r16("s_stock"), r8("s_mission"), r8("s_boss"), r8("s_fryer"), r8("s_counter")))
    log:flush()
    laststate = st
    stf = 0
    if SHOT_STATES[st] then shotn = 40 end
  end
  if shotn > 0 then shotn = shotn - 1; if shotn == 0 then shot("st" .. st) end end
  if SHOT_EVERY and f % SHOT_EVERY == 0 then shot("x") end
  stf = (stf or 0) + 1
  local inp = {}
  if wait > 0 then wait = wait - 1
  else
    local b = nil
    if st == 11 then if f == 90 then shot("abertura") end
    elseif st == 10 and stf == 40 then shot("slots_festa")
    elseif st == 0 then b = "start"
    elseif st == 5 and r8("r_page") == 0 and stf == 90 and not tirou_r then tirou_r = true; shot("resultado")
    elseif st == 5 and r8("r_page") == 1 and not tirou_g then tirou_g = true; shot("grafico")
    elseif (st == 1 and f > 250) or st == 2 or (st == 5 and stf > 100) then if f % 30 == 0 then b = "a"; if st == 2 and CARDSHOT then shot("card") end end
    elseif st == 4 and PAUSETEST and tirou["pausa"] and not tirou["pausa2"] then
      if r8("d_paused") == 0 then b = "start" else tirou["pausa2"] = true; shot("pausa") end
    elseif st == 4 then if not BOT_PARADO then b = botday() end   -- BOT_PARADO: o script de teste controla
    elseif st == 6 then
      if r8("shop_aba") == 1 and stf > 60 and not tirou["loja_aba"] then tirou["loja_aba"] = true; shot("loja_aba") end
      b = SHOP(r8, r16, f)
    elseif st == 7 then if f % 120 == 0 then b = "b" end
    elseif st == 8 then if f % 60 == 0 then b = "b" end
    elseif st == 12 then if stf == 60 then shot("trofeus") end; if stf > 90 and f % 30 == 0 then b = "b" end
    elseif st == 10 then if f % 40 == 0 then if not tirou["slots"] then tirou["slots"] = true; shot("slots") end; b = "a" end
    elseif st == 9 then
      if CHOOSE_SHOT and f % 50 == 0 then shot("escolha") end
      if f % 60 == 0 then if r8("d_unit") ~= (r16("s_day") % 5) then b = "right" else b = "a" end end
    end
    if b then inp[b] = true; wait = 5 end
  end
  emu.setInput(inp, 0)
  if f >= ENDF then log:write("FIM " .. cpu() .. "\n") log:close() emu.stop(0) end
end, emu.eventType.inputPolled)

-- se o jogo travar (sem leitura de controle), registra a CPU
local ef, lastf, stuck = 0, 0, 0
emu.addEventCallback(function()
  ef = ef + 1
  if f == lastf then stuck = stuck + 1 else stuck = 0 end
  lastf = f
  if stuck == 120 then log:write("TRAVOU " .. cpu() .. " state=" .. r8("state") .. "\n") log:close() emu.stop(1) end
end, emu.eventType.endFrame)
-- registra cada vez que um pastel e retirado: para onde o cursor pulou
local lasthold = 255
local jumps, okj = 0, 0
emu.addEventCallback(function()
  if r8("state") ~= 4 then return end
  local h = r8("hold_flav")
  if lasthold == 255 and h ~= 255 and (r8("hold_q") == 1 or r8("hold_q") == 2) then
    jumps = jumps + 1
    local row, c0 = r8("cur_row"), r8("cur_col0")
    if row == 0 and r8("c_order", c0) == h then okj = okj + 1 end
    if jumps % 10 == 0 then log:write(string.format("pulos=%d corretos=%d\n", jumps, okj)) log:flush() end
  end
  lasthold = h
end, emu.eventType.endFrame)
emu.addEventCallback(function()
  if r8("state") ~= 4 then return end
  local function uma(nome, cond) if cond and not tirou[nome] then tirou[nome] = true; shot(nome) end end
  if r8("state") == 4 then local k = "unit" .. r8("d_unit"); uma(k, r16("d_timer") == 400) end
  uma("conserto", r8("mg_on") == 1 and r8("mg_mode") == 1)
  uma("consertado", tirou["conserto"] and r8("d_broke") == 255 and r8("mg_on") == 0)
  local duplo = false
  for q = 0, 3 do if r8("c_state", q) == 2 and r8("c_qty", q) == 2 then duplo = true end end
  if duplo and not tirou["duplo"] then
    local t = ""
    for q = 0, 3 do t = t .. string.format(" [%d st=%d qty=%d x=%d ord=%d]", q, r8("c_state", q), r8("c_qty", q), r16("c_x", q*2), r8("c_order", q)) end
    log:write("DUPLO" .. t .. "\n")
  end
  if duplo then duploF = (duploF or 0) + 1 else duploF = 0 end
  uma("duplo", duploF == 30)
  uma("duelo", r8("d_event") == 5 and r16("d_timer") == 3000)
  local tipos = {}
  for q = 0, 3 do if r8("c_state", q) == 2 then tipos[r8("c_var", q)] = true end end
  if tipos[5] then turf = (turf or 0) + 1 else turf = 0 end
  uma("turista", turf == 40)
  if r8("coin_t") == 20 then uma("moeda", true) end
  uma("telefone", r16("ph_ring") == 200)
  uma("comandas", r8("dv_on", 0) == 1 and r8("dv_on", 1) == 1)
  uma("moto", r8("moto_on") == 1 and r16("moto_x") > 60 and r16("moto_x") < 200)
  uma("popup", r8("pop_t") == 30)
  uma("quebrou", r8("d_broke") ~= 255 and r8("mg_on") == 0)
  uma("tut0", r8("tut_step") == 0 and r16("d_timer") == 200)
  uma("tut2", r8("tut_step") == 2 and r8("msg_timer") == 0 and (f % 32) == 12)
  uma("tut3", r8("tut_step") == 3 and r8("msg_timer") == 0 and (f % 32) == 12)
  if r8("mg_on") == 1 and r8("mg_pos") == 1 then mgk = (mgk or 0) + 1 else mgk = 0 end
  uma("minijogo", mgk == 4)
  uma("mascote", r8("masc_t") == 60)
  local combo = false
  for s = 0, 3 do if r8("c_state", s) == 2 and r8("c_combo", s) == 1 then combo = true end end
  uma("combo", combo and r8("hold_soda") == 1)
end, emu.eventType.endFrame)
-- teste da pausa: aperta START uma vez no dia
emu.addEventCallback(function()
  if PAUSETEST and r8("state") == 4 and r16("d_timer") == 1500 and not tirou["pausa"] then
    tirou["pausa"] = true
  end
end, emu.eventType.endFrame)
