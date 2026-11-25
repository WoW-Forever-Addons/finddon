local _, ns = ...

---------------------------------------------------------------------------
-- Learning a vendor's goods in the game (11.11.2026, Daniel: "bitte nicht wie bei Profitdon, dass wir die
-- Classic-Werte haben", then "ja soll er mitlernen"). The shipped goods come from CMaNGOS (Classic) and ForeverDB; for
-- some vendors Forever sells something else. Whenever a vendor's window opens, Finddon reads what it really sells and
-- keeps it in FinddonDB.goods:
--   [npc id] = { t = time, loc = client language, items = { item id, ... }, limited = { [item id] = true } or nil,
--                names = { [item id] = name } or nil (items the shipped data does not know),
--                prices = { [item id] = copper for one purchase } (23.11.2026; none for goods paid in another
--                currency), stacks = { [item id] = pieces per purchase } or nil (only above 1),
--                npc = { name, mapID, x, y, side } or nil (a vendor the shipped data does not know),
--                partial = true or nil (read with the window's class filter on: a part of the list) }
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

-- item id, name, how many are left (-1 or nil = no limit), price in copper and pieces per purchase of the vendor's slot i
local function Slot(i)
  local id = ns.Num(ns.Call(GetMerchantItemID, i))
  if not id then
    local link = ns.Str(ns.Call(GetMerchantItemLink, i))
    id = link and tonumber(link:match("item:(%d+)"))
  end
  local name, left, price, stack
  local info = C_MerchantFrame and ns.Call(C_MerchantFrame.GetItemInfo, i)
  if type(info) == "table" then
    name, left, price, stack = ns.Str(info.name), ns.Num(info.numAvailable), ns.Num(info.price), ns.Num(info.stackCount)
  elseif type(GetMerchantItemInfo) == "function" then
    local ok, n, _, p, q, a = pcall(GetMerchantItemInfo, i)
    if ok then name, left, price, stack = ns.Str(n), ns.Num(a), ns.Num(p), ns.Num(q) end
  end
  return id, name, left, price, stack
end

-- (21.11.2026, Ruckler) MERCHANT_UPDATE comes often while the window is open: the list is read into tables kept
-- here, and a new record is made only when it differs from the one kept (else only its time and place are new)
local seenS, itemsS, limitedS, namesS, pricesS, stacksS = {}, {}, {}, {}, {}, {}
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
  -- (23.11.2026, Daniel: "finddon zeigt in riverglades nur teilweise die waren der händler"; FinddonDB.goods was empty
  -- on all four saves) Forever loads the modern vendor window, which sets the class filter whenever it opens
  -- (MerchantFrame_OnShow: ResetSetMerchantFilter), and the learning stopped at any filter but "All": it never wrote.
  -- Now a filtered window is read too, as a part of the list (partial): it adds to the shipped list and to what was
  -- read before, never replaces them; a window on "All" gives the whole list.
  local filter = ns.Num(ns.Call(GetMerchantFilter))
  local partial = filter ~= nil and filter ~= (ns.Num(LE_LOOT_FILTER_ALL) or ALL_FILTER) or nil
  Wipe(seenS) Wipe(limitedS) Wipe(namesS) Wipe(pricesS) Wipe(stacksS)
  local count = 0
  for i = 1, n do
    local id, name, left, price, stack = Slot(i)
    if not id then return end -- the list is not loaded yet: MERCHANT_UPDATE comes
    if not seenS[id] then
      seenS[id] = true
      count = count + 1
      itemsS[count] = id
      if left and left >= 0 then limitedS[id] = true end
      if name and not ns.KnownGood(id) then namesS[id] = name end
      if price and price > 0 then pricesS[id] = price end
      if stack and stack > 1 then stacksS[id] = stack end
    end
  end
  local old = ns.db.goods[npc]
  if partial and type(old) == "table" and type(old.items) == "table" then
    if not old.partial then
      -- the whole list is known: a filtered window only brings new prices
      for id, p in pairs(pricesS) do old.prices = old.prices or {} old.prices[id] = p end
      for id, q in pairs(stacksS) do old.stacks = old.stacks or {} old.stacks[id] = q end
      old.t = time()
      if ns.GoodsChanged then ns.GoodsChanged(npc) end
      return
    end
    -- parts read before stay (another filter, another visit)
    for _, id in ipairs(old.items) do
      if not seenS[id] then
        seenS[id] = true
        count = count + 1
        itemsS[count] = id
        if type(old.limited) == "table" and old.limited[id] then limitedS[id] = true end
        if type(old.names) == "table" and old.names[id] then namesS[id] = old.names[id] end
        if type(old.prices) == "table" and old.prices[id] then pricesS[id] = old.prices[id] end
        if type(old.stacks) == "table" and old.stacks[id] then stacksS[id] = old.stacks[id] end
      end
    end
  end
  for i = #itemsS, count + 1, -1 do itemsS[i] = nil end
  table.sort(itemsS)
  local known = ns.NPCByID(npc) ~= nil
  local sameItems = type(old) == "table" and type(old.items) == "table" and #old.items == count
  if sameItems then
    for i = 1, count do if old.items[i] ~= itemsS[i] then sameItems = false break end end
  end
  local rec
  if sameItems and SameSet(limitedS, old.limited) and SameSet(namesS, old.names) and old.partial == partial
    and (known and old.npc == nil or not known and type(old.npc) == "table") then
    rec = old
    rec.t, rec.loc = time(), ns.Str(ns.Call(GetLocale))
  else
    local items = {}
    for i = 1, count do items[i] = itemsS[i] end
    rec = { t = time(), loc = ns.Str(ns.Call(GetLocale)), items = items, limited = Copy(limitedS), names = Copy(namesS),
      partial = partial }
  end
  -- (23.11.2026) the prices as seen, for the goods window; they do not make a new record
  if not SameSet(pricesS, rec.prices) then rec.prices = Copy(pricesS) end
  if not SameSet(stacksS, rec.stacks) then rec.stacks = Copy(stacksS) end
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
  if ns.GoodsChanged then ns.GoodsChanged(npc) end
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
-- (24.11.2026, Ruckler, `timer Learn.lua:170` 42 ms, `timer Learn.lua:178` 30.3 ms) each in steps of a few ms, one a
-- frame (ns.STEP_MS), until it is read
local AHEAD_DELAY, AHEAD_RETRY, AHEAD_NEXT = 5, 3, 0.05
local aheadQueued
local function Ahead(step)
  if InCombatLockdown and InCombatLockdown() then ns.After(AHEAD_RETRY, function() Ahead(step) end) return end
  if step == 1 then
    if ns.ParseGoodsAhead() then ns.After(1, function() Ahead(2) end)
    else ns.After(AHEAD_NEXT, function() Ahead(1) end) end
  elseif not ns.ParseNPCsAhead() then
    ns.After(AHEAD_NEXT, function() Ahead(2) end)
  end
end
ns.On("PLAYER_ENTERING_WORLD", function()
  if aheadQueued then return end
  aheadQueued = true
  ns.After(AHEAD_DELAY, function() Ahead(1) end)
end)
