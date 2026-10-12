-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
local out = io.open(dir .. "ram.txt", "w")
local done = false
emu.addMemoryCallback(function()
  if done then return end
  done = true
  local t = ""
  for a = 0x1500, 0x1510 do t = t .. string.format("%02X ", emu.read(0x7E0000 + a, emu.memType.snesMemory)) end
  out:write("RAM ao ligar: " .. t .. "\n") out:close()
end, emu.callbackType.exec, 0x8001, 0x8001)
local f = 0
emu.addEventCallback(function() f = f + 1; if f == 30 then emu.stop(0) end end, emu.eventType.endFrame)
