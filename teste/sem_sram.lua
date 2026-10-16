-- password (melhoria 12), cartucho SEM SRAM. Rodar com a ROM de
-- `node teste/rom_sem_sram.js` (gen/LosPastelles_sem_sram.sfc):
--   LD_PRELOAD=... teste/mesen/Mesen --testrunner gen/LosPastelles_sem_sram.sfc teste/sem_sram.lua
-- Confere: tem_sram = 0; o titulo so tem NOVO JOGO, PASSWORD e OPCOES; NOVO JOGO
-- comeca sem a escolha de espaco; na loja, VOLTAR AO MENU mostra o password antes
-- do titulo; o password digitado volta para o mesmo dia sem passar pelos espacos.
-- Fotos em teste/foto_semsram_*.png. Sai com 0 se passou.
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local M = emu.memType.snesMemory
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), M) end
local function r16(n) return r8(n) + 256 * r8(n, 1) end
local function r32(n) return r16(n) + 65536 * (r8(n, 2) + 256 * r8(n, 3)) end
local function foto(nome)
  local fh = io.open(dir .. "foto_semsram_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
local ok = true
local function erro(s) ok = false; print("ERRO: " .. s) end

local function idle(n) for _ = 1, n do coroutine.yield({}) end end
local function press(b) for _ = 1, 4 do coroutine.yield({ [b] = true }) end idle(4) end
local function espera(st, max)
  local t = 0
  while r8("state") ~= st do idle(1); t = t + 1; if t > (max or 3000) then erro("estado " .. st .. " nao chegou"); return false end end
  return true
end
local function digita(s)
  for _ = 1, 300 do
    local k = r8("pw_tecla")
    if k == s then break end
    if k % 8 ~= s % 8 then press("right") else press("down") end
  end
  press("a")
end

-- antes de assumir: o robo joga; aqui so se confere o comeco
local viu_slots, viu_intro, conferiu_titulo, viu_abertura = false, false, false, false
emu.addEventCallback(function()
  local st = r8("state")
  if st == 11 then viu_abertura = true end
  if not viu_abertura then return end      -- antes disso a RAM ainda tem lixo
  if st == 10 then viu_slots = true end
  if st == 1 and not viu_intro then
    viu_intro = true
    if viu_slots then erro("NOVO JOGO passou pela escolha de espaco") end
  end
  if st == 0 and not conferiu_titulo and r8("tit_lin") ~= 0 then
    conferiu_titulo = true
    if r8("tem_sram") ~= 0 then erro("tem_sram = 1 num cartucho sem SRAM") end
    if r8("title_has_save") ~= 0 then erro("titulo acha que ha jogo salvo") end
  end
end, emu.eventType.endFrame)

local function roteiro()
  idle(60)
  local dia = r16("s_day")
  local dinheiro = r32("s_money")
  -- VOLTAR AO MENU (item 18): sem SRAM mostra o password primeiro
  for _ = 1, 40 do
    local b = SHOP_IR(r8, 18)
    if not b then break end
    press(b)
  end
  press("a")
  if not espera(14) then return end
  if r8("senha_modo") ~= 2 then erro("VOLTAR AO MENU nao abriu o password para sair") end
  idle(60); foto("sair")
  local sym = {}
  for i = 0, 19 do sym[i] = r8("pw_sym", i) end
  press("a")
  if not espera(0) then return end
  idle(120)
  if r8("title_has_save") ~= 0 then erro("CONTINUAR apareceu sem SRAM") end
  foto("titulo")
  -- PASSWORD e o 2o item quando nao ha jogo salvo
  for _ = 1, 6 do if r8("menu_sel") == 1 then break end press("down") end
  press("a")
  if not espera(14) then return end
  idle(30)
  for i = 0, 19 do digita(sym[i]) end
  press("start")
  for _ = 1, 300 do if r8("state") ~= 14 then break end idle(1) end
  local st = r8("state")
  if st == 10 then erro("sem SRAM o password foi para a escolha de espaco")
  elseif st ~= 2 and st ~= 3 and st ~= 4 and st ~= 9 then erro("password nao voltou ao jogo (estado " .. st .. ")") end
  if r16("s_day") ~= dia or r32("s_money") ~= dinheiro then
    erro(string.format("jogo diferente: dia %d/%d, R$ %d/%d", r16("s_day"), dia, r32("s_money"), dinheiro))
  end
  idle(90); foto("voltou")
end

local co, fim = nil, false
emu.addEventCallback(function()
  if fim then return end
  if not co and r8("state") == 6 then
    BOT_DESLIGADO = true
    co = coroutine.create(roteiro)
  end
  if co then
    local vivo, inp = coroutine.resume(co)
    if coroutine.status(co) == "dead" then
      if not vivo then erro(tostring(inp)) end
      if not conferiu_titulo then erro("nao conferiu o titulo") end
      print(ok and "PASSOU" or "FALHOU")
      fim = true
      emu.stop(ok and 0 or 1)
      return
    end
    emu.setInput(inp or {}, 0)
  end
end, emu.eventType.inputPolled)
local q = 0
emu.addEventCallback(function() q = q + 1; if q > 60000 then print("ERRO: tempo esgotado"); emu.stop(1) end end, emu.eventType.endFrame)
