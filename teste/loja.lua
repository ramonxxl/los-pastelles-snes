-- fotos da loja com abas (melhoria 4): uma por aba, com o cursor no ultimo item
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local aba, parado, fim = 0, 0, false
-- substitui o comprador do robo: desce ate o fim de cada aba, tira a foto e aperta R
function SHOP(r8b, r16, f)
  if fim then return nil end
  if r8("shop_aba") ~= aba then return nil end
  if r8("shop_pos") + 1 < #SHOP_ABAS[aba + 1] then
    if f % 12 == 0 then return "down" end
    return nil
  end
  parado = parado + 1
  if parado < 60 then return nil end
  local fh = io.open(dir .. "foto_loja_aba" .. aba .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
  parado = 0
  aba = aba + 1
  if aba == #SHOP_ABAS then fim = true; return nil end
  return "r"
end
local q = 0
emu.addEventCallback(function()
  q = q + 1
  if fim or q > 30000 then emu.stop(0) end
end, emu.eventType.endFrame)
