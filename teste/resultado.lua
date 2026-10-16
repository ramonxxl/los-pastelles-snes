-- fotos da tela de fim do dia (pagina dos numeros e pagina do grafico)
-- CHEIO = true (antes do dofile, ver resultado_cheio.lua): forca na RAM, durante o
-- dia, os valores que so aparecem mais tarde no jogo (entregas, salarios, lojas,
-- desafio, caixa grande) para conferir o layout com todas as linhas
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local n1, n2, q = 0, 0, 0
local function w8(n, v, i) emu.write(0x7E0000 + L[n] + (i or 0), v, emu.memType.snesMemory) end
local sufixo = CHEIO and "cheio_" or ""
local function foto(nome)
  local fh = io.open(dir .. "foto_res_" .. sufixo .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
emu.addEventCallback(function()
  q = q + 1
  if CHEIO and r8("state") == 4 then
    w8("s_level", 13); w8("s_attend", 1); w8("s_moto", 1); w8("s_stores", 2); w8("s_fran", 1)
    w8("d_deliv", 12); w8("d_dvsales", 0xE8); w8("d_dvsales", 3, 1)  -- 1000
    w8("s_money", 0x87, 0); w8("s_money", 0xD6, 1); w8("s_money", 0x12, 2); w8("s_money", 0, 3)  -- 1234567
    w8("d_boss", 1); w8("d_goal", 200)                                -- desafio do sabor falhou
  end
  if HIST and r8("state") == 4 then
    w8("hist_n", 6); w8("s_day", 10); w8("s_day", 0, 1)  -- dias 4..10 embaixo das barras
    for i, v in ipairs(HIST) do
      if v < 0 then v = v + 65536 end
      w8("hist", v % 256, 2 * i); w8("hist", v // 256, 2 * i + 1)  -- entradas 1..6; HistPush desloca
    end
  end
  if r8("state") == 5 then
    if r8("r_page") == 0 then n1 = n1 + 1; if n1 == 70 then foto("1") end
    else n2 = n2 + 1; if n2 == 12 then foto("2"); emu.stop(0) end end
  end
  if q > 20000 then emu.stop(1) end
end, emu.eventType.endFrame)
