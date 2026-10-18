ENDF = 7700
SHOT_STATES = {}
SHOT_EVERY = nil
local mapdone = false
trofdone = false
-- abas da loja: itens na ordem da tela (repete ShopOrd em src/telas.s)
SHOP_ABAS = { {0, 3, 15, 20, 19, 18}, {1, 2, 10, 11, 12, 14}, {4, 9, 13, 8}, {5, 6, 7, 16, 17} }
-- botao para levar o cursor da loja ate o item alvo (nil = ja esta nele)
function SHOP_IR(r8, alvo)
  local aba, pos = r8("shop_aba") + 1, r8("shop_pos") + 1
  for a, itens in ipairs(SHOP_ABAS) do
    for p, item in ipairs(itens) do
      if item == alvo then
        if a ~= aba then return a > aba and "r" or "l" end
        if p ~= pos then return p > pos and "down" or "up" end
        return nil
      end
    end
  end
end
function SHOP(r8, r16, f)
  if f % 12 ~= 0 then return nil end
  local sel = r8("menu_sel")
  local money = r16("s_money") + 65536 * r16("s_money", 2)
  local lvl = r8("s_level")
  local target = 19                 -- abrir a loja (18 = voltar ao menu)
  if not trofdone then target = 17
  elseif not mapdone and r8("s_stores") >= 1 then target = 16
  elseif r8("s_price") == 1 then target = 15
  elseif r8("s_reforma") < 2 and lvl >= 14 and money >= 2600 then target = 14
  elseif r8("s_ar") == 0 and lvl >= 7 and money >= 450 then target = 11
  elseif r8("s_freezer") == 0 and lvl >= 4 and money >= 300 then target = 10
  elseif r8("s_musica") == 0 and lvl >= 5 and money >= 200 then target = 12
  elseif r8("s_unif") == 0 and lvl >= 10 and money >= 350 then target = 13
  elseif r16("s_stock") < 30 and money >= 60 then target = 0
  elseif r8("s_fryer") < 3 and money >= (r8("s_fryer") == 1 and 160 or 340) then target = 1
  elseif r8("s_counter") < 3 and money >= (r8("s_counter") == 1 and 140 or 290) then target = 2
  elseif r8("s_attend") == 0 and lvl >= 6 and money >= 190 then target = 4
  elseif r8("s_ads") == 0 and lvl >= 10 and money >= 300 then target = 5
  elseif r8("s_stores") < 4 and lvl >= 13 and money >= 1550 + 500 * r8("s_stores") then target = 6
  elseif r8("s_fran") < 5 and lvl >= 21 and r8("s_boss") >= 3 and money >= 4050 then target = 7
  end
  local b = SHOP_IR(r8, target)
  if b then return b end
  if target == 16 then mapdone = true end
  if target == 17 then trofdone = true end
  return "a"
end
CARDSHOT = false
CHOOSE_SHOT = false
PAUSETEST = false
