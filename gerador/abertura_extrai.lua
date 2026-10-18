-- Extrai a abertura da Konami de uma ROM do Sunset Riders (USA) para a homenagem
-- "RAMON" (ferramenta de uso unico; a ROM nao fica no repositorio). Uso, da raiz:
--   teste/mesen/Mesen --testrunner "Sunset Riders (USA).sfc" gerador/abertura_extrai.lua
--   python3 gerador/abertura_ramon.py
-- Grava em gen/abertura_rom/: a VRAM no quadro 150 (cortina do BG1 com o laser e a
-- faisca), a VRAM no quadro 400 (logo pronta no BG2) e a CGRAM de todos os quadros
-- de 136 (a paleta da abertura e carregada) a 690 (512 bytes por quadro). No quadro
-- 313, logo depois de o jogo pedir o jingle (que comeca no 315), grava o estado do
-- SPC700 como um arquivo .spc (jingle.spc), que o ffmpeg toca com a libgme.
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "gerador/"
local saida = dir .. "../gen/abertura_rom/"
os.execute('mkdir "' .. saida .. '"')   -- (ja existir nao e erro)

local function grava(nome, tipo, tam)
  local t = {}
  for i = 0, tam - 1 do t[#t + 1] = string.char(emu.read(i, tipo)) end
  local fh = assert(io.open(saida .. nome, "wb"))
  fh:write(table.concat(t)); fh:close()
end

-- retrato do SPC700 (formato SPC v0.30): registradores, 64 KB de RAM (com os
-- registradores de E/S $F0-$FF), 128 registradores do DSP e a RAM sob a IPL
local function grava_spc(nome)
  local s = emu.getState()
  local h = {}
  local sig = "SNES-SPC700 Sound File Data v0.30"
  for i = 1, 256 do h[i] = 0 end
  for i = 1, #sig do h[i] = sig:byte(i) end
  h[0x22] = 26; h[0x23] = 26; h[0x24] = 27; h[0x25] = 30   -- sem tag ID666, versao 30
  h[0x26] = s["spc.pc"] & 255; h[0x27] = s["spc.pc"] >> 8
  h[0x28] = s["spc.a"]; h[0x29] = s["spc.x"]; h[0x2A] = s["spc.y"]; h[0x2B] = s["spc.ps"]; h[0x2C] = s["spc.sp"]
  local ram = {}
  for i = 0, 65535 do ram[i] = emu.read(i, emu.memType.spcRam) end
  local ctl = 0
  for t = 0, 2 do if s["spc.timer" .. t .. ".enabled"] then ctl = ctl | (1 << t) end end
  if s["spc.romEnabled"] then ctl = ctl | 0x80 end
  ram[0xF0] = 0x0A; ram[0xF1] = ctl; ram[0xF2] = 0; ram[0xF3] = 0
  for i = 0, 3 do ram[0xF4 + i] = s["spc.cpuRegs[" .. i .. "]"] end
  ram[0xF8] = s["spc.ramReg[0]"]; ram[0xF9] = s["spc.ramReg[1]"]
  for t = 0, 2 do
    ram[0xFA + t] = s["spc.timer" .. t .. ".target"]
    ram[0xFD + t] = s["spc.timer" .. t .. ".output"] & 15
  end
  local o = {}
  for i = 1, 256 do o[#o + 1] = string.char(h[i]) end
  for i = 0, 65535 do o[#o + 1] = string.char(ram[i]) end
  for i = 0, 127 do
    local v = emu.read(i, emu.memType.spcDspRegisters)
    if i == 0x4C then v = 0 end                           -- KON ja consumido
    o[#o + 1] = string.char(v)
  end
  for i = 0, 63 do o[#o + 1] = string.char(0) end
  for i = 0, 63 do o[#o + 1] = string.char(ram[0xFFC0 + i]) end
  local fh = assert(io.open(saida .. nome, "wb"))
  fh:write(table.concat(o)); fh:close()
end

local Q0, Q1 = 136, 690
local cg = assert(io.open(saida .. "cg.bin", "wb"))
local q = 0
emu.addEventCallback(function()
  q = q + 1
  if q >= Q0 and q <= Q1 then
    local t = {}
    for i = 0, 511 do t[#t + 1] = string.char(emu.read(i, emu.memType.snesCgRam)) end
    cg:write(table.concat(t))
  end
  if q == 150 then grava("vram150.bin", emu.memType.snesVideoRam, 65536) end
  if q == 400 then grava("vram400.bin", emu.memType.snesVideoRam, 65536) end
  if q == 313 then grava_spc("jingle.spc") end
  if q > Q1 then cg:close(); emu.stop(0) end
end, emu.eventType.endFrame)
