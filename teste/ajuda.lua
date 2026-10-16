-- ajuda da pausa (melhoria 6): abre pela pausa, tira foto de cada pagina de cada
-- aba (R troca de aba, baixo troca de pagina), confere que B volta para a pausa e
-- que B de novo volta ao jogo. Sai com 0 se tudo passou.
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
  local fh = io.open(dir .. "foto_ajuda_" .. nome .. ".png", "wb"); fh:write(emu.takeScreenshot()); fh:close()
end
local ok, t, passo, apertar, assumiu = true, 0, 1, nil, false
local function erro(s) ok = false; print("ERRO: " .. s) end
-- depois que o teste assume, so este script aperta botoes (o robo fica de fora)
emu.addEventCallback(function()
  if assumiu then emu.setInput(apertar and { [apertar] = true } or {}, 0) end
end, emu.eventType.inputPolled)

-- roteiro: { botao, verificacao depois de 40 quadros }
local roteiro = {
  { "start", function() if r8("d_paused") ~= 1 then erro("pausa nao abriu") end end },
  { "down",  function() if r8("pause_sel") ~= 1 then erro("cursor nao foi para AJUDA") end; foto("pausa") end },
  { "a",     function() if r8("aj_on") ~= 1 or r8("dim_on") ~= 3 then erro("ajuda nao abriu") end end },
}
-- paginas por aba (lidas da ROM: AjPagIni no banco 11, endereco do gen/labels.txt)
local function pagIni(i) return emu.read(L["AjPagIni"] + i, emu.memType.snesMemory) end
local abas = 4
for a = 0, abas - 1 do
  local n = pagIni(a + 1) - pagIni(a)
  for p = 0, n - 1 do
    local aa, pp = a, p
    table.insert(roteiro, { nil, function()
      if r8("aj_aba") ~= aa or r8("aj_pag") ~= pp then erro(string.format("esperava aba %d pagina %d, esta em %d/%d", aa, pp, r8("aj_aba"), r8("aj_pag"))) end
      foto(string.format("aba%d_p%d", aa, pp + 1))
    end })
    if p < n - 1 then table.insert(roteiro, { "down", nil }) end
  end
  table.insert(roteiro, { "r", nil })
end
-- depois da ultima aba, R volta para a primeira
table.insert(roteiro, { nil, function() if r8("aj_aba") ~= 0 or r8("aj_pag") ~= 0 then erro("R na ultima aba nao voltou para a primeira") end end })
table.insert(roteiro, { "l", function() if r8("aj_aba") ~= abas - 1 then erro("L na primeira aba nao foi para a ultima") end end })
table.insert(roteiro, { "b", function()
  if r8("aj_on") ~= 0 or r8("dim_on") ~= 2 or r8("d_paused") ~= 1 then erro("B nao voltou para a pausa") end
  foto("volta_pausa") end })
table.insert(roteiro, { "b", function()
  if r8("d_paused") ~= 0 or r8("dim_on") ~= 0 or r8("state") ~= 4 then erro("B na pausa nao voltou ao jogo") end end })

emu.addEventCallback(function()
  t = t + 1
  if not assumiu then
    -- espera o dia andar depois do tutorial (o robo joga ate la)
    if r8("state") == 4 and r8("tut_step") == 255 and r8("tut_box") == 0 and r8("mg_on") == 0 and t > 200 then assumiu, t = true, 0 end
    if t > 30000 then print("ERRO: nao chegou ao dia"); emu.stop(1) end
    return
  end
  local r = roteiro[passo]
  apertar = (r[1] and t <= 4) and r[1] or nil
  if t == 40 then
    if r[2] then r[2]() end
    passo, t = passo + 1, 0
    if passo > #roteiro then
      print(ok and "PASSOU" or "FALHOU")
      emu.stop(ok and 0 or 1)
    end
  end
end, emu.eventType.endFrame)
