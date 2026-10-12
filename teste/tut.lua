-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local out = io.open(dir .. "tut.txt", "w")
local k = 0
emu.addEventCallback(function()
  if r8("state") == 4 then
    k = k + 1
    if k % 40 == 0 and k < 1600 then
      local row = ""
      for c = 1, 12 do row = row .. string.format("%02X", r8("bg3_buf", (2*32+c)*2)) end
      out:write(string.format("k=%d tut=%d msg=%d mg=%d hold=%d row2=%s\n", k, r8("tut_step"), r8("msg_timer"), r8("mg_on"), r8("hold_flav"), row))
    end
  end
end, emu.eventType.endFrame)
