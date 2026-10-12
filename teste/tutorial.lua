-- Teste do tutorial guiado (CI): um jogador "do contra" tenta errar tudo no
-- primeiro pedido (direcionais, B/X/Y, botoes errados no minijogo, A cedo demais,
-- esperar com o pastel no oleo) e o script confere que o jogo segura: cursor
-- travado, relogio parado, um cliente so pedindo carne, pastel que nao queima e
-- entrega perfeita sem desperdicio. Passou: emu.stop(0); falhou: emu.stop(1).
-- Resumo em teste/tutorial.txt. Uso: Mesen --testrunner LosPastelles.sfc teste/tutorial.lua
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do local a, n = string.match(line, "al (%x+) %.([%w_]+)") if a then L[n] = tonumber(a, 16) end end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local function r16(n, i) return r8(n, i) + 256 * r8(n, (i or 0) + 1) end
local log = io.open(dir .. "tutorial.txt", "w")
local f, ent, last, falhas, fase_mg, frit_t, viu = 0, 0, -1, 0, 0, 0, {}
local ERRADOS = { "left", "right", "up", "down", "b", "x", "y" }
local MAPA = { [0] = "up", "down", "left", "right", "a", "b", "x", "y" }
local function falha(s) falhas = falhas + 1 if falhas < 20 then log:write("FALHA f=", f, ": ", s, "\n") end end
local function marca(s) if not viu[s] then viu[s] = true log:write("ok f=", f, " ", s, "\n") end end
emu.addEventCallback(function()
  f = f + 1
  local st = r8("state")
  if st ~= last then ent = f last = st end
  local t = f - ent
  local inp = {}
  if st == 11 or st == 0 then if f % 40 < 4 then inp.start = true end
  elseif st == 10 then if t >= 60 and t < 64 then inp.a = true end
  elseif st == 1 or st == 2 then if t % 40 < 4 then inp.a = true end
  elseif st == 4 and t > 90 then              -- depois da transicao (init da tela)
    local tut = r8("tut_step")
    if tut == 255 and not viu["minijogo aberto"] then
      log:write("FALHOU: o tutorial nem comecou (jogo salvo antigo em teste/mesen/Saves? apague a pasta)\n")
      log:close() emu.stop(1) return
    end
    if tut == 255 then
      log:write(string.format("tutorial terminou f=%d: servidos=%d perfeitos=%d desperdicio=%d perdidos=%d total=%d timer=%d\n",
        f, r8("d_served"), r8("d_perfect"), r8("d_waste"), r8("d_lost"), r8("d_total"), r16("d_timer")))
      if r8("d_perfect") ~= 1 then falha("entrega nao foi perfeita") end
      if r8("d_waste") ~= 0 then falha("houve desperdicio") end
      if r8("d_lost") ~= 0 then falha("cliente foi embora") end
      log:write(falhas == 0 and "PASSOU\n" or "FALHOU\n") log:close() emu.stop(falhas == 0 and 0 or 1) return
    end
    -- invariantes do tutorial
    if r16("d_timer") ~= 0 then falha("relogio andou: " .. r16("d_timer")) end
    if r8("d_total") > 1 then falha("chegou mais de um cliente") end
    for q = 0, 3 do if r8("c_state", q) ~= 0 and r8("c_order", q) ~= 0 then falha("pedido nao e carne") end end
    for b = 0, 3 do if r8("f_state", b) ~= 0 and r8("f_burnt", b) ~= 0 then falha("pastel queimou") end end
    local tb = r8("tut_box")
    if tb == 1 then
      if f % 20 < 3 then inp.a = true end            -- fecha a caixa
    elseif tb == 0 then
      local hold = r8("hold_flav")
      local frit = -1
      for b = 0, 3 do if r8("f_state", b) ~= 0 then frit = b end end
      if r8("mg_on") == 1 then
        marca("minijogo aberto")
        fase_mg = fase_mg + 1
        local certo = MAPA[r8("mg_seq", r8("mg_pos"))]
        if fase_mg < 200 then                         -- 200 quadros apertando errado
          if fase_mg % 12 < 3 then
            local e = ERRADOS[(fase_mg // 12) % #ERRADOS + 1]
            if e == certo then e = (certo == "b") and "y" or "b" end
            inp[e] = true
          end
        elseif fase_mg % 12 < 3 then inp[certo] = true end
      elseif hold ~= 255 then
        marca("pastel na mao (cursor no cliente)")
        if r8("cur_row") ~= 0 then falha("cursor nao foi ao cliente") end
        if f % 30 < 3 then inp[ERRADOS[(f // 30) % #ERRADOS + 1]] = true end
        if f % 90 == 45 then inp = { a = true } end
      elseif frit >= 0 then
        marca("pastel no oleo (cursor no cesto)")
        frit_t = frit_t + 1
        if frit_t > 1 and (r8("cur_row") ~= 1 or r8("cur_col1") ~= r8("n_flav") + frit) then falha("cursor fora do cesto") end
        local p = r8("f_prog", frit * 2 + 1)
        if frit_t < 20 and f % 6 < 3 then inp.a = true end            -- A cedo demais (cru)
        if p >= 160 then marca("pastel no ponto") end
        if frit_t == 700 then log:write("progresso apos 700 quadros no oleo: ", p, "\n") end
        if frit_t > 700 and f % 20 < 3 then inp.a = true end          -- espera bem e tira
        if frit_t < 700 and f % 25 < 3 then inp[ERRADOS[(f // 25) % #ERRADOS + 1]] = true end
      else
        if r8("cur_row") ~= 1 or r8("cur_col1") ~= 0 then falha("cursor saiu da carne") end
        local cliente = false
        for q = 0, 3 do if r8("c_state", q) == 2 then cliente = true end end
        if not cliente then
          if f % 10 < 3 then inp.a = true end           -- A antes do cliente: nada
        else
          marca("cliente na loja")
          if f % 30 < 3 then inp[ERRADOS[(f // 30) % #ERRADOS + 1]] = true end
          if f % 120 == 60 then inp = { a = true } end
        end
      end
    end
  end
  emu.setInput(inp, 0)
  if f > 20000 then log:write("TIMEOUT\nFALHOU\n") log:close() emu.stop(1) end
end, emu.eventType.inputPolled)
