-- pasta teste/ (descoberta pelo caminho do script; senao, relativo a raiz do repositorio)
local dir = (debug and debug.getinfo and (debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or "teste/"
dofile(dir .. "botcfg_b.lua")
ENDF = 8700
local SHOP0 = SHOP
local esperou, lastsel, fase = 0, -1, 0
function SHOP(r8, r16, f)
  local sel = r8("menu_sel")
  if sel ~= lastsel then lastsel = sel; esperou = 0 end
  esperou = esperou + 1
  if fase == 0 then
    if sel == 1 and esperou < 120 then return nil end
    if sel == 13 then if esperou < 120 then return nil end fase = 1 end
    if f % 12 ~= 0 then return nil end
    local b = SHOP_IR(r8, 13)
    if b then return b end
  end
  return SHOP0(r8, r16, f)
end
