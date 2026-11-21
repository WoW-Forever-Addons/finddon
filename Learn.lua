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

-- (21.11.2026, Ruckler) MERCHANT_UPDATE comes often while the window is open: the list is read into tables kept
-- here, and a new record is made only when it differs from the one kept (else only its time and place are new)
local seenS, itemsS, limitedS, namesS = {}, {}, {}, {}
local function Wipe(t) for k in pairs(t) do t[k] = nil end end
local function SameSet(a, b) -- a: a set kept here, b: the record's (nil = empty)
  if b == nil then return next(a) == nil end
  if type(b) ~= "table" then return false end
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local function Copy(a)
  if next(a) == nil then return nil end
  local c = {}
  for k, v in pairs(a) do c[k] = v end
  return c
end

local function Learn()
  local npc = NpcID()
  if not npc then return end
  local n = ns.Num(ns.Call(GetMerchantNumItems)) or 0
  if n == 0 then return end
  -- a vendor that shows only the goods of the player's class would be learned with half its list
  local filter = ns.Num(ns.Call(GetMerchantFilter))
  if filter and filter ~= (ns.Num(LE_LOOT_FILTER_ALL) or ALL_FILTER) then return end
  Wipe(seenS) Wipe(limitedS) Wipe(namesS)
  local count = 0
  for i = 1, n do
    local id, name, left = Slot(i)
    if not id then return end -- the list is not loaded yet: MERCHANT_UPDATE comes
    if not seenS[id] then
      seenS[id] = true
      count = count + 1
      itemsS[count] = id
      if left and left >= 0 then limitedS[id] = true end
      if name and not ns.KnownGood(id) then namesS[id] = name end
    end
  end
  for i = #itemsS, count + 1, -1 do itemsS[i] = nil end
  table.sort(itemsS)
  local old = ns.db.goods[npc]
  local known = ns.NPCByID(npc) ~= nil
  local sameItems = type(old) == "table" and type(old.items) == "table" and #old.items == count
  if sameItems then
    for i = 1, count do if old.items[i] ~= itemsS[i] then sameItems = false break end end
  end
  local rec
  if sameItems and SameSet(limitedS, old.limited) and SameSet(namesS, old.names)
    and (known and old.npc == nil or not known and type(old.npc) == "table") then
    rec = old
    rec.t, rec.loc = time(), ns.Str(ns.Call(GetLocale))
  else
    local items = {}
    for i = 1, count do items[i] = itemsS[i] end
    rec = { t = time(), loc = ns.Str(ns.Call(GetLocale)), items = items, limited = Copy(limitedS), names = Copy(namesS) }
  end
  if not known then
    local api = ns.Map()
    local map, x, y
    if api and api.PlayerPosition then map, x, y = api.PlayerPosition() end
    local p = rec.npc or {}
    p[1], p[2], p[3], p[4], p[5] = ns.Str(ns.Call(UnitName, "npc")) or "?", ns.Num(map) or 0,
      ns.Num(x) and math.floor(x * 1000 + 0.5) / 1000 or 0, ns.Num(y) and math.floor(y * 1000 + 0.5) / 1000 or 0,
      ns.PlayerSide() or "N"
    rec.npc = p
  end
  ns.db.goods[npc] = rec
  if sameItems then return end
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

-- (21.11.2026, Ruckler) the shipped goods and NPCs are parsed a few seconds after login, out of combat, each in its own
-- frame, so the first vendor of a session does not hitch (Data.lua ns.ParseGoodsAhead, ns.ParseNPCsAhead)
local AHEAD_DELAY, AHEAD_RETRY = 5, 3
local aheadQueued
local function Ahead(step)
  if InCombatLockdown and InCombatLockdown() then ns.After(AHEAD_RETRY, function() Ahead(step) end) return end
  if step == 1 then
    ns.ParseGoodsAhead()
    ns.After(1, function() Ahead(2) end)
  else
    ns.ParseNPCsAhead()
  end
end
ns.On("PLAYER_ENTERING_WORLD", function()
  if aheadQueued then return end
  aheadQueued = true
  ns.After(AHEAD_DELAY, function() Ahead(1) end)
end)
