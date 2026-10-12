-- grava quadros do jogo (30 fps) enquanto o robo joga
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
local out = dir .. "../trailer/quadros2/" .. GRAVA_NOME .. "_"
local idx = io.open(dir .. "../trailer/quadros2/" .. GRAVA_NOME .. ".txt", "w")
local ef, n = 0, 0
emu.addEventCallback(function()
  ef = ef + 1
  if ef % 2 ~= 0 then return end
  local st = r8("state")
  if GRAVA_QUANDO(st, ef, r16("d_timer")) then
    n = n + 1
    local fh = io.open(out .. string.format("%05d", n) .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
    local dv = 0
    for t = 0, 2 do dv = dv + r8("dv_on", t) end
    local ring = 0
    if r16("ph_ring") > 0 then ring = 1 end
    idx:write(string.format("%d %d %d %d %d %d %d %d\n", n, ef, st, r16("d_timer"), dv, r8("moto_on"), ring, r8("mg_on"))); idx:flush()
  end
end, emu.eventType.endFrame)
