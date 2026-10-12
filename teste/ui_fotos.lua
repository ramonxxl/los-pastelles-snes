-- capturas da interface nova (usa BOTCFG)
-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
BOTCFG = BOTCFG or "botcfg_b.lua"
dofile(dir .. "bot.lua")
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local cnt, last, feitas = {}, -1, {}
local function foto(nome)
  if feitas[nome] then return end
  feitas[nome] = true
  local fh = io.open(dir .. "ui/" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
local QUAIS = { [2] = {2, 4, 6, 8, 10, 14, 40, 120}, [6] = {3, 6, 9, 12, 40, 70, 90}, [4] = {200, 400},
  [5] = {60}, [12] = {40}, [3] = {40}, [9] = {40}, [10] = {40}, [11] = {40} }
emu.addEventCallback(function()
  local st = r8("state")
  if st ~= last then cnt[st] = 0; last = st end
  cnt[st] = cnt[st] + 1
  local q = QUAIS[st]
  if q then for _, k in ipairs(q) do if cnt[st] == k then foto(string.format("s%02d_%04d", st, k)) end end end
  if st == 6 then
    local sel = r8("menu_sel")
    if cnt[st] % 7 == 0 then foto(string.format("loja_sel%02d_%d", sel, cnt[st] % 2)) end
  end
end, emu.eventType.endFrame)
