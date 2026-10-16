-- menu de pausa no balao do tutorial (melhoria 5): fotos com cada item escolhido,
-- B volta ao jogo e o escurecimento some
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local function foto(nome)
  local fh = io.open(dir .. "foto_pausa_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
-- passos: {quadros de espera, botao, verificacao/foto}
local fase, t, ok = 0, 0, true
local function log(s) print(s) end
local apertar = nil
emu.addEventCallback(function()
  if apertar then emu.setInput({ [apertar] = true }, 0) end
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  t = t + 1
  local dia = r8("state") == 4 and r8("tut_step") == 255 and r8("tut_box") == 0 and r8("mg_on") == 0
  if fase == 0 then
    if dia and t > 200 then fase, t = 1, 0 end
  elseif fase == 1 then apertar = (t <= 4) and "start" or nil
    if t == 40 then
      if r8("d_paused") ~= 1 or r8("dim_on") ~= 2 then ok = false; log("ERRO: pausa nao abriu no balao") end
      foto("continuar"); fase, t = 2, 0
    end
  elseif fase == 2 then apertar = (t <= 4) and "up" or nil   -- cima no primeiro item da a volta ate SAIR
    if t == 40 then
      if r8("pause_sel") ~= 2 then ok = false; log("ERRO: cima nao foi para SAIR") end
      foto("sair"); fase, t = 3, 0
    end
  elseif fase == 3 then apertar = (t <= 4) and "b" or nil
    if t == 40 then
      if r8("d_paused") ~= 0 or r8("dim_on") ~= 0 or r8("state") ~= 4 then ok = false; log("ERRO: B nao voltou ao jogo") end
      foto("depois")
      log(ok and "PASSOU" or "FALHOU")
      emu.stop(ok and 0 or 1)
    end
  end
  if t > 30000 then log("ERRO: nao chegou ao dia"); emu.stop(1) end
end, emu.eventType.endFrame)
