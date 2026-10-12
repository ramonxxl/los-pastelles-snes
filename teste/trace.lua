-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
local done = false
emu.addMemoryCallback(function()
  if done then return end
  done = true
  local tl = io.open(dir .. "trace.txt", "w")
  local s = emu.getState()
  tl:write(string.format("%02X:%04X a=%04X x=%04X y=%04X p=%02X sp=%04X\n", s["cpu.k"], s["cpu.pc"], s["cpu.a"], s["cpu.x"], s["cpu.y"], s["cpu.ps"], s["cpu.sp"]))
  for a = s["cpu.sp"] + 1, s["cpu.sp"] + 16 do tl:write(string.format("%04X:%02X ", a, emu.read(0x7E0000 + a, emu.memType.snesMemory))) end
  tl:write("\n")
  tl:close()
end, emu.callbackType.exec, 0x0100, 0x1FFF)
