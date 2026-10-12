BOTCFG = "botcfg_b.lua"
-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local lg = io.open(dir .. "ui_log.txt", "w")
local k = 0
emu.addEventCallback(function()
  if r8("state") == 6 then
    k = k + 1
    if k < 400 then lg:write(string.format("%d on=%d pos=%d sel=%d ptr=%02X%02X%02X pad=%d\n", k, r8("tw_on"), r8("tw_pos") + 256 * r8("tw_pos", 1), r8("menu_sel"), r8("tw_ptr", 2), r8("tw_ptr", 1), r8("tw_ptr"), r8("pad_new"))) lg:flush() end
  end
end, emu.eventType.endFrame)
