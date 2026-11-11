local _, ns = ...

---------------------------------------------------------------------------
-- Learning a vendor's goods in the game (11.11.2026, Daniel: "bitte nicht wie bei Profitdon, dass wir die
-- Classic-Werte haben", then "ja soll er mitlernen"). The shipped goods come from CMaNGOS (Classic) and ForeverDB; for
-- some vendors Forever sells something else. Whenever a vendor's window opens, Finddon reads what it really sells and
-- keeps it in FinddonDB.goods:
--   [npc id] = { t = time, loc = client language, items = { item id, ... }, limited = { [item id] = true } or nil,
--                names = { [item id] = name } or nil (items the shipped data does not know),
--                npc = { name, mapID, x, y, side } or nil (a vendor the shipped data does not know) }
-- From then on the search takes this list for that vendor in place of the shipped one (Data.lua ns.Sellers).
-- tools/finddon_learned.py collects the lists for the data build. Reads only: own events, no hooks.
---------------------------------------------------------------------------
local ALL_FILTER = 1 -- LE_LOOT_FILTER_ALL: the vendor shows everything, not only the goods of the player's class

local function NpcID()
  local guid = ns.Str(ns.Call(UnitGUID, "npc"))
  if not guid then return nil end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if kind ~= "Creature" then return nil end
  return tonumber(id)
end

-- item id, name and how many are left (-1 or nil = no limit) of the vendor's slot i
local function Slot(i)
  local id = ns.Num(ns.Call(GetMerchantItemID, i))
  if not id then
    local link = ns.Str(ns.Call(GetMerchantItemLink, i))
    id = link and tonumber(link:match("item:(%d+)"))
  end
  local name, left
  local info = C_MerchantFrame and ns.Call(C_MerchantFrame.GetItemInfo, i)
  if type(info) == "table" then
    name, left = ns.Str(info.name), ns.Num(info.numAvailable)
  elseif type(GetMerchantItemInfo) == "function" then
    local ok, n, _, _, _, a = pcall(GetMerchantItemInfo, i)
    if ok then name, left = ns.Str(n), ns.Num(a) end
  end
  return id, name, left
end

local function Learn()
  local npc = NpcID()
  if not npc then return end
  local n = ns.Num(ns.Call(GetMerchantNumItems)) or 0
  if n == 0 then return end
  -- a vendor that shows only the goods of the player's class would be learned with half its list
  local filter = ns.Num(ns.Call(GetMerchantFilter))
  if filter and filter ~= (ns.Num(LE_LOOT_FILTER_ALL) or ALL_FILTER) then return end
  local items, limited, names, seen = {}, nil, nil, {}
  for i = 1, n do
    local id, name, left = Slot(i)
    if not id then return end -- the list is not loaded yet: MERCHANT_UPDATE comes
    if not seen[id] then
      seen[id] = true
      items[#items + 1] = id
      if left and left >= 0 then
        limited = limited or {}
        limited[id] = true
      end
      if name and not ns.KnownGood(id) then
        names = names or {}
        names[id] = name
      end
    end
  end
  table.sort(items)
  local key = table.concat(items, ",")
  local old = ns.db.goods[npc]
  local rec = { t = time(), loc = ns.Str(ns.Call(GetLocale)), items = items, limited = limited, names = names }
  if not ns.NPCByID(npc) then
    local api = ns.Map()
    local map, x, y
    if api and api.PlayerPosition then map, x, y = api.PlayerPosition() end
    rec.npc = { ns.Str(ns.Call(UnitName, "npc")) or "?", ns.Num(map) or 0, ns.Num(x) and math.floor(x * 1000 + 0.5) / 1000 or 0,
      ns.Num(y) and math.floor(y * 1000 + 0.5) / 1000 or 0, ns.PlayerSide() or "N" }
  end
  ns.db.goods[npc] = rec
  if type(old) == "table" and type(old.items) == "table" and table.concat(old.items, ",") == key then return end
  -- another list than before: an open search shows it at once
  local _, win = ns.WindowState()
  if win and win:IsShown() and ns.RunSearch then ns.RunSearch() end
end

ns.On("MERCHANT_SHOW", function() Learn() end)
ns.On("MERCHANT_UPDATE", function() Learn() end)

-- how many vendors' goods were learned in the game (/fd diag)
function ns.LearnedCount()
  local n = 0
  for _ in pairs(ns.db and ns.db.goods or {}) do n = n + 1 end
  return n
end
