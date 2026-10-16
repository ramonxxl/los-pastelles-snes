-- codigo secreto na tela de digitar o password. Roda com e sem SRAM:
--   LD_PRELOAD=... teste/mesen/Mesen --testrunner LosPastelles.sfc teste/senha_secreto.lua
--   LD_PRELOAD=... teste/mesen/Mesen --testrunner gen/LosPastelles_sem_sram.sfc teste/senha_secreto.lua
-- Confere: sem SRAM, o codigo no titulo abre o password ja aceito; o codigo com o password vazio nao volta ao titulo e nao digita nada;
-- com o password cheio nao muda nenhum simbolo; START abre o menu secreto com o
-- jogo do password; um truque vale; SALVAR E JOGAR (sem SRAM: SEGUIR JOGANDO)
-- segue para o dia (com SRAM passando pela escolha de espaco). Fotos em
-- teste/foto_pwsec_*.png. Sai com 0 se passou.
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
local ok = true
local function erro(s) ok = false; print("ERRO: " .. s) end
local sram
local function foto(nome)
  local fh = io.open(dir .. "foto_pwsec_" .. (sram and "sram_" or "semsram_") .. nome .. ".png", "wb")
  fh:write(emu.takeScreenshot()); fh:close()
end

local function idle(n) for _ = 1, n do coroutine.yield({}) end end
local function press(b) for _ = 1, 4 do coroutine.yield({ [b] = true }) end idle(4) end
local function espera(st, max)
  local t = 0
  while r8("state") ~= st do idle(1); t = t + 1; if t > (max or 3000) then erro("estado " .. st .. " nao chegou (esta em " .. r8("state") .. ")"); return false end end
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
local KONAMI = { "up", "up", "down", "down", "left", "right", "left", "right", "b", "a" }
local function konami() for _, b in ipairs(KONAMI) do press(b) end end
local function vai(item)
  for _ = 1, 40 do
    local b = SHOP_IR(r8, item)
    if not b then break end
    press(b)
  end
end

local function roteiro()
  idle(60)
  sram = r8("tem_sram") ~= 0
  print(sram and "com SRAM" or "sem SRAM")
  local dia, dinheiro = r16("s_day"), r32("s_money")
  local sym = {}
  if sram then
    vai(20); press("a")                   -- VER PASSWORD
    if not espera(14) then return end
    idle(30)
    for i = 0, 19 do sym[i] = r8("pw_sym", i) end
    press("a")
    if not espera(6) then return end
    idle(30)
  end
  vai(18); press("a")                     -- VOLTAR AO MENU
  if not sram then
    if not espera(14) then return end
    idle(30)
    for i = 0, 19 do sym[i] = r8("pw_sym", i) end
    press("a")
  end
  if not espera(0) then return end
  idle(120)
  if sram then
    local idx = (r8("title_has_save") ~= 0) and 2 or 1
    for _ = 1, 6 do if r8("menu_sel") == idx then break end press("down") end
    press("a")
    if not espera(14) then return end
  else
    -- sem SRAM o codigo no titulo abre o password ja com o codigo aceito
    konami()
    if not espera(14, 300) then return end
    if r8("senha_modo") ~= 0 then erro("codigo no titulo nao abriu o password para digitar") end
    if r8("pw_festa") ~= 1 then erro("codigo no titulo nao chegou aceito ao password") end
  end
  idle(30)
  -- codigo com o password vazio: o B nao sai, nada e digitado
  konami(); idle(10)
  if r8("state") ~= 14 then erro("codigo com password vazio saiu da tela (estado " .. r8("state") .. ")"); return end
  if r8("pw_cur") ~= 0 then erro("codigo com password vazio deixou " .. r8("pw_cur") .. " simbolos") end
  if r8("pw_festa") ~= 1 then erro("codigo com password vazio nao foi aceito") end
  foto("vazio")
  for i = 0, 19 do digita(sym[i]) end
  -- de novo com o password cheio: o B do codigo nao apaga, o A nao digita
  konami(); idle(10)
  if r8("pw_cur") ~= 20 then erro("codigo com password cheio deixou " .. r8("pw_cur") .. " simbolos") end
  for i = 0, 19 do
    if r8("pw_sym", i) ~= sym[i] then erro("codigo mudou o simbolo " .. i) end
  end
  if r8("pw_festa") ~= 1 then erro("codigo com password cheio nao foi aceito") end
  foto("cheio")
  press("start")
  if not espera(13, 300) then return end
  if r16("s_day") ~= dia or r32("s_money") ~= dinheiro then erro("o menu secreto nao tem o jogo do password") end
  idle(60); foto("menu")
  press("a")                              -- +R$ 1.000
  idle(10)
  if r32("s_money") ~= dinheiro + 1000 then erro(string.format("truque nao valeu: R$ %d", r32("s_money"))) end
  for _ = 1, 10 do if r8("menu_sel") == 5 then break end press("down") end
  press("a")                              -- SALVAR E JOGAR / SEGUIR JOGANDO
  if r8("pw_festa") ~= 0 then erro("pw_festa ficou ligado") end
  if sram then
    if not espera(10, 300) then return end
    if r8("sl_mode") ~= 3 then erro("escolha de espaco sem sl_mode 3") end
    idle(30); foto("espaco")
    press("a"); idle(10)
    if r8("state") == 10 then press("a") end  -- espaco ocupado: confirma
  end
  for _ = 1, 300 do if r8("state") ~= 13 and r8("state") ~= 10 then break end idle(1) end
  local st = r8("state")
  if st ~= 2 and st ~= 3 and st ~= 4 and st ~= 9 then erro("nao seguiu para o jogo (estado " .. st .. ")") end
  if r16("s_day") ~= dia or r32("s_money") ~= dinheiro + 1000 then erro("o jogo que seguiu nao e o turbinado") end
  idle(90); foto("seguiu")
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
