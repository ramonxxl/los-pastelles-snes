-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local function r16(n, i) return r8(n, i) + 256 * r8(n, (i or 0) + 1) end
local feitas, ef, st0 = {}, 0, {}
local function foto(nome)
  if feitas[nome] then return end
  feitas[nome] = true
  local fh = io.open(dir .. "foto_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
emu.addEventCallback(function()
  ef = ef + 1
  local st = r8("state")
  st0[st] = (st0[st] or 0) + 1
  if st == 12 and st0[12] == 50 then foto("trofeus") end
  if st == 9 and st0[9] == 60 then foto("bairro") end
  if st == 4 then
    local n = 0
    for q = 0, 3 do if r8("c_state", q) == 2 then n = n + 1 end end
    if n >= 3 and r16("d_timer") > 1500 and r8("mg_on") == 0 and r8("dv_on", 0) == 1 then foto("jogo") end
    if r8("moto_on") == 1 and r16("moto_x") > 90 and r16("moto_x") < 140 then foto("entrega") end
    if r8("mg_on") == 1 and r8("mg_pos") == 1 then mgf = (mgf or 0) + 1 else mgf = 0 end
    if mgf == 4 and r16("d_timer") > 600 then foto("minijogo") end
  end
  if st == 5 and st0[5] == 70 then foto("resultado") end
  if st == 6 and st0[6] == 60 then foto("loja") end
  if st == 6 and r8("menu_sel") >= 13 and not feitas["loja2"] then foto("loja2") end
end, emu.eventType.endFrame)
