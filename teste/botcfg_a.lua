-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "botcfg.lua")
ENDF = 2600
GRAVA_NOME = "a"
function GRAVA_QUANDO(st, ef, t) return ef < 2700 end
