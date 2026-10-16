-- fim do dia com todas as linhas preenchidas (ver resultado.lua)
CHEIO = true
-- historico de lucro (7 dias, com sinal) forcado na entrada do resultado: o dia
-- de hoje entra por cima (HistPush), entao o grafico mostra 7 barras variadas
HIST = { 120, -250, 300, 80, -150, 210 }
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "resultado.lua")
