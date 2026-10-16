-- fotos do cenario do expediente nos 5 bairros x 3 reformas (melhoria 7): chega ao
-- dia 1 e reinicia o dia com d_unit/s_reforma trocados na RAM (teste/foto_cen_<b>_<r>.png)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n) return emu.read(0x7E0000 + L[n], emu.memType.snesMemory) end
local function w8(n, v) emu.write(0x7E0000 + L[n], v, emu.memType.snesMemory) end
local q, t, combo, fase = 0, 0, 0, 0
emu.addEventCallback(function()
  local st = r8("state")
  local inp = {}
  -- ate o dia: START no titulo, A nas telas de texto
  if fase == 0 and st ~= 4 and q % 40 < 4 then inp = (st == 11 or st == 0) and { start = true } or { a = true } end
  emu.setInput(inp, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  q = q + 1
  local st = r8("state")
  if fase == 0 then
    if st == 4 then fase, t = 1, 0 end
  else
    t = t + 1
    if t == 2 then
      w8("d_unit", combo // 3); w8("s_reforma", combo % 3); w8("tut_step", 255); w8("next_state", 4)
    elseif t == 70 then
      local fh = io.open(string.format("%sfoto_cen_%d_%d.png", dir, combo // 3, combo % 3), "wb")
      fh:write(emu.takeScreenshot()); fh:close()
      combo = combo + 1; t = 0
      if combo == 15 then emu.stop(0) end
    end
  end
  if q > 20000 then emu.stop(1) end
end, emu.eventType.endFrame)
