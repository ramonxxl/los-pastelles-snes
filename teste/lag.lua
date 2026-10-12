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
local out = io.open(dir .. "lag.txt", "w")
local base, cnt, lastt, lastl, jog = nil, 0, 0, 0, 0
emu.addEventCallback(function()
  local t, l = r16("d_timer"), r16("lag_count")
  if r8("state") == 4 and t > 60 and t == lastt + 1 and r8("d_paused") == 0 then
    jog = jog + (l - lastl)
    if not base then base = 0 end
    cnt = cnt + 1
  end
  lastt, lastl = t, l
  if base then
    if cnt % 1000 == 0 then out:write(string.format("quadros=%d atrasados_no_jogo=%d total=%d\n", cnt, jog, l)) out:flush() end
  end
end, emu.eventType.endFrame)
