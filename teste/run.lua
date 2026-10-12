-- roteiro: tabela de {quadro, botoes} e quadros de screenshot (definidos em cenario.lua)
-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "cenario.lua")
local f = 0
local log = io.open(dir .. "log.txt", "w")
emu.addEventCallback(function()
  f = f + 1
  local inp = {}
  for _,ev in ipairs(INPUTS) do
    if f >= ev[1] and f < ev[1] + (ev[3] or 3) then for b in string.gmatch(ev[2], "%a+") do inp[b] = true end end
  end
  emu.setInput(inp, 0)
  for _,s in ipairs(SHOTS) do
    if s == f then
      local fh = io.open(dir .. "s" .. string.format("%05d", f) .. ".png", "wb")
      fh:write(emu.takeScreenshot()) fh:close()
      local st = emu.getState()
      log:write(string.format("f=%d pc=%02X:%04X state=%d\n", f, st["cpu.k"], st["cpu.pc"], emu.read(0x7E0000 + STATE_ADDR, emu.memType.snesMemory)))
    end
  end
  if f >= ENDF then log:close() emu.stop(0) end
end, emu.eventType.inputPolled)
