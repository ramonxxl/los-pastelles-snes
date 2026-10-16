-- animacao de erro: o pastel cai na lixeira (melhoria 11). Erra de proposito no
-- minijogo do tutorial (la nao pode aparecer), depois aperta um botao errado num
-- minijogo normal (fotos dos 5 quadros-chave) e deixa o tempo acabar no seguinte
-- (foto). Confere que o cartao some no fim e que o envio cabe no vblank.
-- Sai com 0 se tudo deu certo.
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "bot.lua")
ENDF = 1e9                      -- quem encerra e este script
local L, C = {}, {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
for line in io.lines(dir .. "../gen/assets.inc") do
  local n, v = string.match(line, "^([%w_]+) = (%d+)$")
  if n then C[n] = tonumber(v) end
end
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), emu.memType.snesMemory) end
local function foto(nome)
  local fh = io.open(dir .. "foto_lix_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
local ok = true
local function erro(s) ok = false; print("ERRO: " .. s) end

local CHAVES = {}
local function rom(a) return ((a >> 16) & 0x7F) * 0x8000 + (a & 0x7FFF) end
for i = 0, 4 do CHAVES[i] = emu.read(rom(L["AnimLixeiraChaves"]) + i, emu.memType.snesPrgRom) end

-- envio dos tiles dentro do vblank (linha do PPU quando a NMI chega na AnimNmi)
local dma, maxlin = false, 0
emu.addMemoryCallback(function() dma = true end, emu.callbackType.exec, L["AnimDma"])
emu.addMemoryCallback(function()
  if dma then
    dma = false
    local lin = emu.getState()["ppu.scanline"]
    if lin < 200 then lin = lin + 262 end
    if lin > maxlin then maxlin = lin end
  end
end, emu.callbackType.exec, L["AnimNmi"])

-- entrada: nil = o robo joga; {} = ninguem aperta; {b=true}... (o robo fica parado: BOT_PARADO)
local BOTOES = { "up", "down", "left", "right", "a", "b", "x", "y" }
local entrada = nil
emu.addEventCallback(function()
  BOT_PARADO = entrada ~= nil
  if entrada then emu.setInput(entrada, 0) end
end, emu.eventType.inputPolled)

local function lixeira()
  local rel = r8("anim_cur") - C.ANIM_LIXEIRA
  return r8("anim_vis") == 1 and rel >= 0 and rel < C.ANIM_LIXEIRA_N, rel
end
local function errado()
  local certo = r8("mg_seq", r8("mg_pos"))
  return { [BOTOES[((certo + 1) % 8) + 1]] = true }
end

local fase, t, tut_erros, vistas, nvistas, agenda, ultimo = 0, 0, 0, {}, 0, nil, -1
local function quadro()
  t = t + 1
  local st = r8("state")
  local tut = r8("tut_step") ~= 255
  local mg = st == 4 and r8("mg_on") == 1 and r8("mg_mode") == 0 and r8("tut_box") == 0 and r8("d_paused") == 0
  if lixeira() and tut then erro("a lixeira apareceu no tutorial") end
  if fase == 0 then
    -- tutorial: botao errado no minijogo so faz o som de erro
    if mg and tut then
      if t % 20 < 4 then entrada = errado() else entrada = {} end
      if t % 20 == 4 then tut_erros = tut_erros + 1 end
      if tut_erros >= 3 then entrada = nil; fase = 1 end
    else
      entrada = nil
    end
  elseif fase == 1 then
    -- minijogo normal: errar o primeiro botao
    if mg and not tut then entrada = errado(); fase, t = 2, 0 end
  elseif fase == 2 then
    if t == 4 then entrada = {} end            -- solta e segura o robo ate o fim
    local vis, rel = lixeira()
    local pronto = vis and r8("anim_ok") == 1 and r8("anim_sujo") == 0
    if pronto and rel == ultimo and not agenda then
      for k = 0, 4 do
        if rel == CHAVES[k] and not vistas[k] then
          vistas[k] = true; nvistas = nvistas + 1
          agenda = { "botao_chave" .. k, t + 2 }   -- a captura do Mesen sai 2 quadros atrasada
        end
      end
    end
    ultimo = pronto and rel or -1
    if agenda and t == agenda[2] then foto(agenda[1]); agenda = nil end
    if t > 20 and r8("anim_vis") == 0 and not agenda then
      if nvistas < 5 then erro("so " .. nvistas .. " quadros-chave da lixeira apareceram") end
      foto("botao_depois")
      entrada = nil; fase, t = 3, 0
    end
    if t > 400 then erro("o cartao da lixeira nao sumiu"); fase, t = 3, 0; entrada = nil end
  elseif fase == 3 then
    -- proximo minijogo: ninguem aperta, o tempo acaba
    if mg and not tut then entrada = {}; fase, t = 4, 0 end
  elseif fase == 4 then
    local vis, rel = lixeira()
    if vis and rel == CHAVES[2] and not agenda and not vistas.tempo then vistas.tempo = true; agenda = { "tempo", t + 2 } end
    if agenda and t == agenda[2] then foto(agenda[1]); agenda = nil end
    if vistas.tempo and not agenda and r8("anim_vis") == 0 then
      if r8("mg_on") ~= 0 then erro("o tempo esgotado nao encerrou o minijogo") end
      foto("tempo_depois")
      fase = 5
    end
    if t > 900 then erro(vistas.tempo and "o cartao nao sumiu depois do tempo esgotado" or "o tempo esgotado nao mostrou a lixeira"); fase = 5 end
  end
  if fase == 5 then
    if tut_erros < 3 then erro("nao conseguiu errar no tutorial") end
    print(string.format("ultima linha do PPU depois dos DMAs: %d (vblank vai ate 261)", maxlin))
    if maxlin > 261 then erro("o envio passou do vblank") end
    print(ok and "PASSOU" or "FALHOU")
    emu.stop(ok and 0 or 1)
  end
  if t > 30000 then erro("nao terminou (fase " .. fase .. ")"); print("FALHOU"); emu.stop(1) end
end
emu.addEventCallback(function()
  local okc, e = pcall(quadro)
  if not okc then print("ERRO no script: " .. tostring(e)); emu.stop(1) end
end, emu.eventType.endFrame)
