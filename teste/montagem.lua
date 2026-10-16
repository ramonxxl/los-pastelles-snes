-- animacao grande da montagem do pastel (melhoria 10): fotos de cada quadro-chave
-- num minijogo jogado pelo robo, depois um minijogo com botao errado (o cartao
-- passa para a animacao da lixeira e some no fim; detalhes em teste/lixeira.lua). Confere que o envio dos tiles (AnimDma) termina dentro do vblank.
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
  local fh = io.open(dir .. "foto_mga_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
local ok, msgs = true, {}
local function erro(s) ok = false; msgs[#msgs + 1] = s; print("ERRO: " .. s) end

-- chaves (relativas) lidas da ROM: AnimMontagemChaves
local CHAVES = {}
local function rom(a) return ((a >> 16) & 0x7F) * 0x8000 + (a & 0x7FFF) end
for i = 0, 4 do CHAVES[i] = emu.read(rom(L["AnimMontagemChaves"]) + i, emu.memType.snesPrgRom) end

-- envio dos tiles: linha do PPU quando a NMI chega na AnimNmi (depois de todos os DMAs)
local dma, maxlin, ndma = false, 0, 0
emu.addMemoryCallback(function() dma = true; ndma = ndma + 1 end, emu.callbackType.exec, L["AnimDma"])
emu.addMemoryCallback(function()
  if dma then
    dma = false
    local lin = emu.getState()["ppu.scanline"]
    if lin < 200 then lin = lin + 262 end      -- passou do fim do quadro
    if lin > maxlin then maxlin = lin end
  end
end, emu.callbackType.exec, L["AnimNmi"])

local BOTOES = { "up", "down", "left", "right", "a", "b", "x", "y" }
local apertar = nil
emu.addEventCallback(function()
  if apertar then emu.setInput({ [apertar] = true }, 0) end
end, emu.eventType.inputPolled)

local fase, t, vistas, nvistas, espera, ultimo, sumiu, agenda, lixo = 0, 0, {}, 0, 0, -1, false, nil, false
emu.addEventCallback(function()
  t = t + 1
  local jogo = r8("state") == 4 and r8("tut_step") == 255 and r8("tut_box") == 0
  if fase == 0 then
    -- minijogo jogado pelo robo: uma foto em cada quadro-chave (depois do envio)
    -- (a captura de tela do Mesen sai 2 quadros atrasada: a foto e agendada)
    local pronto = jogo and r8("anim_vis") == 1 and r8("anim_ok") == 1 and r8("anim_sujo") == 0
    local rel = r8("anim_cur") - C.ANIM_MONTAGEM
    if pronto and rel == ultimo and not agenda then
      for k = 0, 4 do
        if rel == CHAVES[k] and not vistas[k] then
          vistas[k] = true; nvistas = nvistas + 1
          agenda = { "chave" .. k, t + 2 }
        end
      end
      if rel == 1 and not vistas.i then vistas.i = true; agenda = { "intermediario", t + 2 } end
    end
    ultimo = pronto and rel or -1
    if agenda and t == agenda[2] then foto(agenda[1]); agenda = nil end
    if nvistas == 5 and not agenda and r8("anim_vis") == 0 then fase, t = 1, 0 end
  elseif fase == 1 then
    -- proximo minijogo: espera o primeiro acerto e erra o segundo botao
    if jogo and r8("mg_on") == 1 and r8("mg_mode") == 0 then
      if r8("mg_pos") >= 1 and espera == 0 then
        local certo = r8("mg_seq", r8("mg_pos"))
        apertar = BOTOES[((certo + 1) % 8) + 1]
        espera = 1
      end
    end
    if espera > 0 then
      espera = espera + 1
      if espera == 6 then apertar = nil end
      local rel = r8("anim_cur") - C.ANIM_LIXEIRA
      if espera <= 15 and r8("anim_vis") == 1 and rel >= 0 and rel < C.ANIM_LIXEIRA_N then lixo = true end
      -- some no fim (ou da lugar a montagem, se o robo ja comecou outro pastel)
      if lixo and (r8("anim_vis") == 0 or rel < 0 or rel >= C.ANIM_LIXEIRA_N) then sumiu = true end
      if espera == 3 then foto("erro") end
      if espera == 20 and r8("mg_on") ~= 0 then erro("o botao errado nao encerrou o minijogo") end
      if espera == 200 then
        if not lixo then erro("o erro nao mostrou a lixeira") end
        if not sumiu then erro("o cartao nao sumiu depois da lixeira") end
        foto("depois")
        fase = 2
      end
    end
  end
  if fase == 2 then
    if ndma == 0 then erro("nenhum envio de quadro") end
    print(string.format("envios: %d, ultima linha do PPU depois dos DMAs: %d (vblank vai ate 261)", ndma, maxlin))
    if maxlin > 261 then erro("o envio passou do vblank") end
    print(ok and "PASSOU" or "FALHOU")
    emu.stop(ok and 0 or 1)
  end
  if t > 30000 then erro("nao terminou (fase " .. fase .. ", chaves vistas " .. nvistas .. ")"); print("FALHOU"); emu.stop(1) end
end, emu.eventType.endFrame)
