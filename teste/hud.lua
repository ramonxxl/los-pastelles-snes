-- fotos do HUD do expediente (melhoria 9): balao do tutorial por cima, aviso no
-- rodape, missao, numeros grandes com meta e itens na mao, e a pausa
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local M = emu.memType.snesMemory
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), M) end
local function w8(n, v, i) emu.write(0x7E0000 + L[n] + (i or 0), v, M) end
local function w16(n, v) w8(n, v & 255); w8(n, (v >> 8) & 255, 1) end
local function foto(nome)
  local fh = io.open(dir .. "foto_hud_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
local feitas, fase, t, apertar = {}, 0, 0, nil
emu.addEventCallback(function()
  if apertar then emu.setInput({ [apertar] = true }, 0) end
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  t = t + 1
  if r8("state") ~= 4 then return end
  local livre = r8("tut_step") == 255 and r8("tut_box") == 0 and r8("d_paused") == 0
  if fase == 0 then
    if r8("tut_box") > 1 and not feitas.tut then feitas.tut = true; foto("tutorial") end
    if livre and r8("msg_timer") > 60 and not feitas.msg then feitas.msg = true; foto("aviso") end
    if livre and r8("hud_mis") == 1 and r8("mg_on") == 0 and not feitas.mis then feitas.mis = true; foto("missao") end
    if feitas.msg and feitas.mis then fase, t = 1, 0 end
  elseif fase == 1 then
    -- numeros no maximo das casas, dia com meta (desafio) e itens na mao
    w16("s_day", 123); w16("s_money", 54321); w8("s_money", 0x12, 2); w8("s_money", 0, 3)
    w8("s_level", 21); w16("s_stock", 999); w8("s_rep", 100)
    w8("d_boss", 0); w8("d_goal", 14); w8("d_happy", 7)
    w8("hold_flav", 1); w8("hold_soda", 1)
    if t == 20 then foto("cheio"); fase, t = 2, 0 end
  elseif fase == 2 then
    apertar = (t <= 4) and "start" or nil
    if t == 30 then foto("pausa") end
    if t == 40 then apertar = "b" end
    if t == 44 then apertar = nil; emu.stop(0) end
  end
  if t > 40000 then print("ERRO: nao chegou"); emu.stop(1) end
end, emu.eventType.endFrame)
