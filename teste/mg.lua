-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local out = io.open(dir .. "mg.txt", "w")
local n = 0
emu.addEventCallback(function()
  if r8("mg_on") == 1 and n < 40 then
    n = n + 1
    local o = ""
    for i = 0, 4 do o = o .. string.format("[%d,%d,%02X,%02X] ", emu.read(i*4, emu.memType.snesSpriteRam), emu.read(i*4+1, emu.memType.snesSpriteRam), emu.read(i*4+2, emu.memType.snesSpriteRam), emu.read(i*4+3, emu.memType.snesSpriteRam)) end
    out:write(string.format("pos=%d len=%d seq=%d,%d,%d,%d oam=%s\n", r8("mg_pos"), r8("mg_len"), r8("mg_seq",0), r8("mg_seq",1), r8("mg_seq",2), r8("mg_seq",3), o))
  end
end, emu.eventType.endFrame)
