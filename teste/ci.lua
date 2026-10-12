-- Teste automatico (CI): o robo (bot.lua) joga um jogo novo e este script confere
-- os marcos do jogo. Passou: emu.stop(0); falhou: emu.stop(1). O resumo vai para
-- teste/ci.txt (e o robo registra o dele em teste/bot.txt).
-- Uso: Mesen --testrunner LosPastelles.sfc teste/ci.lua
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script

local LIMITE = 15000            -- quadros para chegar ao dia 2
local MAX_LAG = 4               -- quadros atrasados aceitos jogando (expediente, sem caixa aberta)

local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local function r16(n) return r8(n) + 256 * r8(n, 1) end

local out = io.open(dir .. "ci.txt", "w")
local function msg(s) out:write(s, "\n") out:flush() end
local marcos = {
  { "dia 1 comecou",        function() return r8("state") == 4 and r16("s_day") == 1 end },
  { "tutorial concluido",   function() return (r8("s_tflags") & 8) ~= 0 end },
  { "fim do dia (resultado)", function() return r8("state") == 5 end },
  { "loja aberta",          function() return r8("state") == 6 end },
  { "dia 2 comecou",        function() return r8("state") == 4 and r16("s_day") == 2 end },
}
local prox, f = 1, 0
local lag, lag_ant, jogando_ant = 0, 0, false

local function fim(ok, motivo)
  if ok and lag > MAX_LAG then ok, motivo = false, "quadros atrasados demais: " .. lag end
  if ok then
    -- jogo salvo valido no espaco 1 da SRAM ("LPST" no inicio)
    local m = ""
    for i = 0, 3 do m = m .. string.char(emu.read(i, emu.memType.snesSaveRam)) end
    if m ~= "LPST" then ok, motivo = false, "jogo salvo nao encontrado na SRAM (" .. m .. ")" end
  end
  msg(string.format("quadros=%d atrasados=%d", f, lag))
  msg(ok and "PASSOU" or ("FALHOU: " .. motivo))
  out:close()
  emu.stop(ok and 0 or 1)
end

emu.addEventCallback(function()
  f = f + 1
  -- atraso so conta com o jogo rodando (carregar cenas e abrir caixas param o laco de proposito)
  local lc = r16("lag_count")
  local jogando = r8("state") == 4 and r8("tut_box") == 0 and r8("d_paused") == 0
  if jogando and jogando_ant then lag = lag + ((lc - lag_ant) & 0xFFFF) end
  lag_ant, jogando_ant = lc, jogando
  while prox <= #marcos and marcos[prox][2]() do
    msg(string.format("ok  f=%-6d %s", f, marcos[prox][1]))
    prox = prox + 1
  end
  if prox > #marcos then fim(true) return end
  if f >= LIMITE then fim(false, "nao chegou a '" .. marcos[prox][1] .. "' em " .. LIMITE .. " quadros") end
end, emu.eventType.inputPolled)
