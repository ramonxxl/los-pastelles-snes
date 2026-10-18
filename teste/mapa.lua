-- fotos do mapa da expansao (melhoria 8) com 0, algumas e todas as unidades
-- compradas (forca s_stores/s_fran na RAM e abre o mapa a partir da loja) e da
-- escolha da loja do dia com todas as lojas
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local function w8(n, v) emu.write(0x7E0000 + L[n], v, emu.memType.snesMemory) end
function SHOP() return nil end  -- o robo fica parado na loja
local CASOS = { { 0, 0, "0" }, { 2, 2, "meio" }, { 4, 5, "cheio" } }
local caso, t, fase = 1, 0, "loja"
local function foto(nome)
  local fh = io.open(dir .. "foto_mapa_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
emu.addEventCallback(function()
  t = t + 1
  local st = r8("state")
  if fase == "loja" then
    if st == 6 and t > 60 then
      local c = CASOS[caso]
      w8("s_stores", c[1]); w8("s_fran", c[2]); w8("next_state", 7)
      fase, t = "mapa", 0
    end
  elseif fase == "mapa" then
    if t == 90 then
      foto(CASOS[caso][3])
      if caso == #CASOS then
        -- escolha da loja do dia (ST_CHOOSE) com todas as lojas, cursor na ultima
        w8("d_unit", 4); w8("next_state", 9); fase, t = "escolha", 0
      else
        caso = caso + 1; w8("next_state", 6); fase, t = "loja", 0
      end
    end
  elseif fase == "escolha" then
    if t == 90 then foto("escolha"); emu.stop(0) end
  end
  if t > 30000 then print("ERRO: nao chegou a loja"); emu.stop(1) end
end, emu.eventType.endFrame)
