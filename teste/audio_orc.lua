-- orcamento do audio no expediente (melhoria 13): por quadro do dia mede
--   - a linha em que a logica termina e entra no WaitFrame (o resto ate o vblank,
--     linha 225, e o tempo ocioso em que o Bomba manda as falas e a musica);
--   - quantos bytes o Bomba mandou (falas e musica separados);
--   - o nivel dos aneis (bytes ainda nao tocados) de fala e de musica.
-- O robo joga; na primeira loja o save vira um jogo adiantado (mais clientes,
-- cestos, entregas, app), para medir os quadros mais pesados. Resumo em
-- teste/audio_orc.txt. Sai com 0.
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
BOTCFG = BOTCFG or "botcfg_b.lua"
dofile(dir .. "bot.lua")
ENDF = 1e9
local L = {}
for line in io.lines(dir .. "../gen/labels.txt") do
  local a, n = string.match(line, "al (%x+) %.([%w_]+)")
  if a then L[n] = tonumber(a, 16) end
end
local M = emu.memType.snesMemory
local function r8(n, i) return emu.read(0x7E0000 + L[n] + (i or 0), M) end
local function r16(n, i) return r8(n, i) + 256 * r8(n, (i or 0) + 1) end
local function w(n, v, tam) for i = 0, (tam or 1) - 1 do emu.write(0x7E0000 + L[n] + i, (v >> (8 * i)) & 0xFF, M) end end

local DIAS = ORC_DIAS or 2
local entrada, fala, mus = -1, 0, 0
local Q = {}          -- por quadro do dia: {linha, fala, mus, nivel_fala, nivel_mus, fala_tocando}
local adiantado, dias_medidos, ultimo_dia = false, 0, -1

local pcw = L["WaitFrame"]
for _, b in ipairs(ORC_SEMCB and {} or { 0x00, 0x80 }) do
  if not ORC_SEMEXEC then emu.addMemoryCallback(function() if entrada < 0 then entrada = emu.getState()["ppu.scanline"] end end,
    emu.callbackType.exec, (b << 16) | (pcw & 0xFFFF)) end
  if not ORC_SEMWRITE then emu.addMemoryCallback(function(_, v)
    if v & 0x80 ~= 0 then if v & 0x40 ~= 0 then fala = fala + 3 else mus = mus + 3 end end
  end, emu.callbackType.write, (b << 16) | 0x2140, (b << 16) | 0x2140) end
end

local function quadro()
  local st = r8("state")
  if st == 6 and not adiantado then
    adiantado = true
    if ORC_LEVE then return end
    -- jogo adiantado: nivel 16, 3 cestos, balcao cheio, atendente, app, motoboy, 2 lojas
    w("s_level", 16); w("s_boss", 2); w("s_chapter", 2); w("s_fryer", 3); w("s_counter", 3)
    w("s_attend", 1); w("s_pc", 1); w("s_moto", 1); w("s_ads", 1); w("s_stores", 2)
    w("s_stock", 400, 2); w("s_money", 50000, 4); w("s_rep", 90)
  end
  if st == 4 and adiantado and r8("tut_box") == 0 and r8("d_paused") == 0 then
    local d = r16("s_day")
    if d ~= ultimo_dia then ultimo_dia = d; dias_medidos = dias_medidos + 1 end
    Q[#Q + 1] = { entrada, fala, mus, r16("vz_nivel", 1), r16("mu_nivel", 1), r8("vz_est") == 2, r8("mg_on") ~= 0, r8("mu_est") }
  end
  entrada, fala, mus = -1, 0, 0
  if dias_medidos > DIAS or #Q > 30000 then
    -- resumo
    local f = io.open(dir .. "audio_orc.txt", "w")
    local lin, atras, tot_f, tot_m, qf = {}, 0, 0, 0, 0
    local cap = {}                         -- bytes por linha ociosa quando havia demanda
    local min_vz, min_mu, vazio_vz, vazio_mu, enchendo = 1e9, 1e9, 0, 0, 0
    for _, q in ipairs(Q) do
      if q[1] < 0 or q[1] >= 225 then atras = atras + 1 else lin[#lin + 1] = 225 - q[1] end
      tot_f, tot_m = tot_f + q[2], tot_m + q[3]
      if q[6] then
        qf = qf + 1
        if q[4] < min_vz then min_vz = q[4] end
        if q[4] == 0 then vazio_vz = vazio_vz + 1 end
      end
      if q[8] == 2 then
        if q[5] < min_mu then min_mu = q[5] end
        if q[5] == 0 then vazio_mu = vazio_mu + 1 end
      end
      if q[8] == 1 then enchendo = enchendo + 1 end
    end
    table.sort(lin)
    local function p(x) return lin[math.max(1, math.floor(#lin * x))] or -1 end
    local soma = 0 for _, v in ipairs(lin) do soma = soma + v end
    f:write(string.format("quadros do dia medidos: %d (sem chegar ao WaitFrame antes do vblank: %d)\n", #Q, atras))
    f:write(string.format("linhas ociosas antes do vblank: min %d  p5 %d  p10 %d  media %.1f  p50 %d\n",
      lin[1] or -1, p(0.05), p(0.10), soma / math.max(1, #lin), p(0.5)))
    local mg = {}
    for _, q in ipairs(Q) do if q[7] and q[1] >= 0 and q[1] < 225 then mg[#mg + 1] = 225 - q[1] end end
    table.sort(mg)
    if #mg > 0 then
      f:write(string.format("so no minijogo (%d quadros): linhas ociosas p10 %d  p50 %d\n", #mg, mg[math.max(1, #mg // 10)], mg[#mg // 2 + 1]))
    end
    f:write(string.format("bytes/quadro: fala %.1f  musica %.1f\n", tot_f / #Q, tot_m / #Q))
    -- vazao: nos quadros em que fala e musica mandaram bastante, bytes por linha ociosa
    local melhor = 0
    for _, q in ipairs(Q) do
      if q[1] >= 0 and q[1] < 225 and (225 - q[1]) > 20 then
        local v = (q[2] + q[3]) / (225 - q[1])
        if v > melhor then melhor = v end
      end
    end
    f:write(string.format("vazao maxima observada: %.2f bytes por linha ociosa\n", melhor))
    f:write(string.format("fala tocando em %d quadros; nivel minimo %d bytes; quadros com anel vazio: %d\n", qf, min_vz == 1e9 and -1 or min_vz, vazio_vz))
    -- contexto de cada quadro com a musica vazia: os 40 quadros antes
    for k, q in ipairs(Q) do
      if q[8] == 2 and q[5] == 0 then
        f:write(string.format("vazio no quadro %d:\n", k))
        for j = math.max(1, k - 40), k do
          local r = Q[j]
          f:write(string.format("  %d lin=%d fala=%d mus=%d nivF=%d nivM=%d falaTocando=%s mg=%s\n", j, r[1] >= 0 and 225 - r[1] or -1, r[2], r[3], r[4], r[5], tostring(r[6]), tostring(r[7])))
        end
        break
      end
    end
    f:write(string.format("musica tocando: nivel minimo %d bytes; quadros com anel vazio: %d; quadros enchendo (sem tocar): %d\n", min_mu, vazio_mu, enchendo))
    -- histograma das linhas ociosas
    local h = {}
    for _, v in ipairs(lin) do local k = (v // 10) * 10; h[k] = (h[k] or 0) + 1 end
    local ks = {} for k in pairs(h) do ks[#ks + 1] = k end table.sort(ks)
    for _, k in ipairs(ks) do f:write(string.format("  %3d-%3d linhas: %d\n", k, k + 9, h[k])) end
    f:close()
    emu.stop(0)
  end
end
emu.addEventCallback(function()
  local ok, e = pcall(quadro)
  if not ok then local f = io.open(dir .. "audio_orc.txt", "w"); f:write("ERRO LUA: " .. tostring(e) .. "\n"); f:close(); emu.stop(1) end
end, emu.eventType.endFrame)
