-- perfil do expediente num dia adiantado (melhoria 13): conta as instrucoes
-- executadas por rotina (rotulo mais proximo abaixo do PC) numa janela de quadros
-- do dia, sem o tempo ocioso (WaitFrame/Bomba e o envio de audio). Resultado em
-- teste/perfil.txt. Rodar com --timeout=900 (passa de 100 s).
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
BOTCFG = BOTCFG or "botcfg_b.lua"
dofile(dir .. "bot.lua")
ENDF = 1e9
local L, rot = {}, {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then
    a = tonumber(a, 16); L[n] = a
    if a >= 0x8000 and not n:match("^@") then rot[#rot + 1] = { a & 0x7FFFFF, n } end
  end
end
table.sort(rot, function(x, y) return x[1] < y[1] end)
local function nome(pc)
  pc = pc & 0x7FFFFF
  local lo, hi, r = 1, #rot, "?"
  while lo <= hi do
    local m = (lo + hi) // 2
    if rot[m][1] <= pc then r = rot[m][2]; lo = m + 1 else hi = m - 1 end
  end
  return r
end
local M = emu.memType.snesMemory
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), M) end
local function w(n, v, tam) for i = 0, (tam or 1) - 1 do emu.write(0x7E0000 + L[n] + i, (v >> (8 * i)) & 0xFF, M) end end

local INI, DUR = PERFIL_INI or 900, PERFIL_DUR or 120   -- quadros do dia
local adiantado, nq, conta, total, ids = false, 0, {}, 0, {}
mg_agora = false                -- PERFIL_MG: so os quadros com o minijogo aberto
local chama, nchama = {}, 0
local function ligarChamadas()
  local pc = L["AddSprite"] & 0xFFFF
  for _, b in ipairs({ 0x00, 0x80 }) do
    emu.addMemoryCallback(function()
      local s = emu.getState()
      local sp = s["cpu.sp"]
      local ret = emu.read(sp + 1, emu.memType.snesMemory) + 256 * emu.read(sp + 2, emu.memType.snesMemory)
      local k = nome((s["cpu.k"] << 16) | ret)
      chama[k] = (chama[k] or 0) + 1
      nchama = nchama + 1
    end, emu.callbackType.exec, (b << 16) | pc, (b << 16) | pc)
  end
end
local function ligar()
  if PERFIL_CHAMADAS then return ligarChamadas() end
  for _, b in ipairs({ 0x00, 0x80, 0x9C }) do       -- banco 0 (e espelho) e banco 28
    local id = emu.addMemoryCallback(function(a)
      if PERFIL_MG and not mg_agora then return end
      local s = emu.getState()
      local pc = (s["cpu.k"] << 16) | s["cpu.pc"]
      conta[pc] = (conta[pc] or 0) + 1
      total = total + 1
    end, emu.callbackType.exec, (b << 16) | 0x8000, (b << 16) | 0xFFFF)
    ids[#ids + 1] = { id, b }
  end
end
local function desligar()
  if PERFIL_CHAMADAS then return end
  for _, e in ipairs(ids) do emu.removeMemoryCallback(e[1], emu.callbackType.exec, (e[2] << 16) | 0x8000, (e[2] << 16) | 0xFFFF) end
end
emu.addEventCallback(function()
  local st = r8("state")
  if st == 6 and not adiantado then
    adiantado = true
    w("s_level", 16); w("s_boss", 2); w("s_chapter", 2); w("s_fryer", 3); w("s_counter", 3)
    w("s_attend", 1); w("s_pc", 1); w("s_moto", 1); w("s_ads", 1); w("s_stores", 2)
    w("s_stock", 400, 2); w("s_money", 50000, 4); w("s_rep", 90)
  end
  mg_agora = r8("mg_on") ~= 0
  if st == 4 and adiantado and (not PERFIL_MG or mg_agora) then
    nq = nq + 1
    if nq == INI then ligar() end
    if nq == INI + DUR then
      desligar()
      -- soma por rotina; o laco ocioso (WaitFrame, Bomba e o que ele chama) a parte
      local por = {}
      for pc, n in pairs(conta) do local k = nome(pc); por[k] = (por[k] or 0) + n end
      local ocio = { WaitFrame = 1, Bomba = 1, VozBomba = 1, MusBomba = 1, VozTrio = 1, MusTrio = 1, ApuTrio = 1, VozLeRom = 1 }
      local lst, ocupado = {}, 0
      for k, n in pairs(por) do lst[#lst + 1] = { k, n }; if not ocio[k] then ocupado = ocupado + n end end
      table.sort(lst, function(x, y) return x[2] > y[2] end)
      if PERFIL_CHAMADAS then
        local f = io.open(dir .. "perfil_chamadas.txt", "w")
        local l2 = {}
        for k, n in pairs(chama) do l2[#l2 + 1] = { k, n } end
        table.sort(l2, function(x, y) return x[2] > y[2] end)
        f:write(string.format("AddSprite: %.1f chamadas por quadro\n", nchama / DUR))
        for _, e in ipairs(l2) do f:write(string.format("%-22s %7.1f por quadro\n", e[1], e[2] / DUR)) end
        f:close()
        emu.stop(0)
        return
      end
      local f = io.open(dir .. "perfil.txt", "w")
      f:write(string.format("%d quadros do dia; instrucoes: %d (fora do ocio: %d, %.0f por quadro)\n", DUR, total, ocupado, ocupado / DUR))
      for i = 1, math.min(45, #lst) do
        local k, n = lst[i][1], lst[i][2]
        f:write(string.format("%-22s %9d  %5.1f%%%s\n", k, n, 100 * n / ocupado, ocio[k] and "  (ocio)" or ""))
      end
      f:close()
      emu.stop(0)
    end
  end
end, emu.eventType.endFrame)
