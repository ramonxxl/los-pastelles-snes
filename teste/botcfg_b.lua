-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "botcfg.lua")
ENDF = 7900
GRAVA_NOME = "b"
function GRAVA_QUANDO(st, ef, t) return st == 9 or (st == 4 and t < 3200) or st == 5 or st == 6 or st == 7 or st == 12 end
