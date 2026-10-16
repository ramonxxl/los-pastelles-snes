-- foto da mao ao lado do cursor (melhoria 2): pastel na mao, latinha e os dois
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local feitas, conta, q = {}, {}, 0
local function foto(nome)
  conta[nome] = (conta[nome] or 0) + 1
  if feitas[nome] or conta[nome] < 6 then return end
  feitas[nome] = true
  local fh = io.open(dir .. "foto_mao_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
emu.addEventCallback(function()
  q = q + 1
  if r8("state") == 4 and r8("mg_on") == 0 then
    local f, s, row = r8("hold_flav"), r8("hold_soda"), r8("cur_row")
    if f ~= 255 and s == 0 and r8("tut_step") == 255 then foto("pastel" .. row) end
    -- latinha forcada so para a foto (o combo so libera no nivel 7)
    if feitas.pastel0 and not feitas.combo and f ~= 255 then emu.write(0x7E0000 + L["hold_soda"], 1, emu.memType.snesMemory) end
        if f ~= 255 and s ~= 0 then foto("combo") end
    if f == 255 and s ~= 0 then foto("refri") end
  end
  if q > 30000 or (feitas.pastel0 and feitas.combo) then emu.stop(0) end
end, emu.eventType.endFrame)
