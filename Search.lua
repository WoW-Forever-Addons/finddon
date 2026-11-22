local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Search: NPCs of a role and / or with a text in name or title, own faction and neutral (the other faction with the
-- option), sorted by the distance from here. An NPC with several places (rares) counts with its nearest one;
-- cooking fires are one hit each.
--   ns.Search(role, text) -> results { { npc =, role = the role asked for, mapID =, x =, y =, dist = yards or nil,
--     sec = 1 this zone / 2 neighbouring zone / 3 further away (nil without a position) }, ... }, state
--     goods = the items the hit sells of what was asked for (a group of goods or a text that names goods), or nil
-- The list is sorted by part first, by distance inside a part.
-- (11.11.2026, Daniel: "nach Waren suchen ... dass dann der entsprechende Händler in der Nähe angezeigt wird") role may
-- be a group of goods ("Gd" drinks): the vendors that sell something of it. The text also finds goods by name: a vendor
-- is a hit when its name or title has the text or it sells an item named so.
-- dist is nil on another continent and wherever the player has no position (instances); those come last, by zone
-- and name. state: "nopos" when the player has no position.
---------------------------------------------------------------------------
local zoneNames = {}
function ns.ZoneName(mapID)
  local n = zoneNames[mapID]
  if n ~= nil then return n or "" end
  local info = C_Map and C_Map.GetMapInfo and ns.Call(C_Map.GetMapInfo, mapID)
  n = type(info) == "table" and ns.Str(info.name) or false
  zoneNames[mapID] = n
  return n or ""
end

function ns.PlayerSide()
  local f = ns.Str(ns.Call(UnitFactionGroup, "player"))
  if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
  return nil
end

-- world positions of an NPC's places, worked out once per place: { continent, north, west, ... } (false = unknown)
local function World(npc, api)
  local w = npc.world
  if w then return w end
  local p = ns.Places(npc)
  w = {}
  local all = true
  for i = 1, #p, 3 do
    local c, n, wst = api.WorldPos(p[i], p[i + 1], p[i + 2])
    w[i], w[i + 1], w[i + 2] = c or false, n or 0, wst or 0
    if not c then all = false end
  end
  -- kept only when every place could be worked out (a map the client does not know yet is asked again)
  if all then npc.world = w end
  return w
end

-- The continent a map lies on, by its name ("Kalimdor"); "" when the client does not say.
local continentNames = {}
function ns.ContinentName(mapID)
  local n = continentNames[mapID]
  if n then return n end
  n = false
  local types = Enum and Enum.UIMapType
  local continent = types and ns.Num(types.Continent) or 2
  local id, guard = mapID, 0
  while id and guard < 8 do
    guard = guard + 1
    local info = C_Map and C_Map.GetMapInfo and ns.Call(C_Map.GetMapInfo, id)
    if type(info) ~= "table" then break end
    if ns.Num(info.mapType) == continent then n = ns.Str(info.name) or false break end
    id = ns.Num(info.parentMapID)
    if id == 0 then break end
  end
  if n then continentNames[mapID] = n end -- kept only when known
  return n or ""
end

-- (11.11.2026, chosen from the proposals: "In dieser Zone", "Nachbarzonen", "Weiter weg") The part of the list a hit
-- belongs to: 1 the player's zone, 2 a neighbouring zone, 3 further away. The game has no list of neighbours: two zones
-- count as neighbours when their maps overlap in the world (each map drawn in by a tenth on every side, since a zone's
-- map shows a broad strip of the zones around it).
local SHRINK = 0.1
local rects = {}
local function Rect(api, mapID)
  local r = rects[mapID]
  if r ~= nil then return r end
  r = false
  local c, n0, w0 = api.WorldPos(mapID, SHRINK, SHRINK)
  local c2, n1, w1 = api.WorldPos(mapID, 1 - SHRINK, 1 - SHRINK)
  if c and c == c2 and n0 and n1 then
    r = { c = c, nLo = math.min(n0, n1), nHi = math.max(n0, n1), wLo = math.min(w0, w1), wHi = math.max(w0, w1) }
    rects[mapID] = r -- kept only when known (a map the client does not know yet is asked again)
  end
  return r
end
function ns.Neighbours(api, a, b)
  local ra, rb = Rect(api, a), Rect(api, b)
  if not (ra and rb) or ra.c ~= rb.c then return false end
  return ra.nLo < rb.nHi and rb.nLo < ra.nHi and ra.wLo < rb.wHi and rb.wLo < ra.wHi
end

local function Before(a, b)
  if (a.sec or 0) ~= (b.sec or 0) then return (a.sec or 0) < (b.sec or 0) end
  if a.dist and b.dist then
    if a.dist ~= b.dist then return a.dist < b.dist end
  elseif a.dist or b.dist then
    return a.dist ~= nil
  else
    local za, zb = ns.ZoneName(a.mapID), ns.ZoneName(b.mapID)
    if za ~= zb then return za < zb end
  end
  if a.npc.name ~= b.npc.name then return a.npc.name < b.npc.name end
  if a.npc.id ~= b.npc.id then return a.npc.id < b.npc.id end
  return (a.spot or 0) < (b.spot or 0)
end

-- (22.11.2026, Ruckler, DonMonitor report: timer Window.lua:458 avg 58.6 ms every 2 s) where the player stands, the
-- parts of the list and the distance of a hit, shared by the search and by ns.Resort (the open list following the player)
local function Here()
  local api = ns.Map()
  local h = { api = api, secOf = {} }
  if api then h.c, h.n, h.w = api.PlayerWorld() end
  -- the player's map (a city has its own) and the zone around it, for the parts of the list
  if h.c and api.PlayerPosition then
    h.here = api.PlayerPosition()
    h.zone = h.here and api.ZoneMap and api.ZoneMap(h.here) or h.here
  end
  return h
end

local function Sec(h, mapID)
  local here, zone = h.here, h.zone
  if not here then return nil end
  local s = h.secOf[mapID]
  if not s then
    s = (mapID == here or mapID == zone) and 1 or (ns.Neighbours(h.api, zone or here, mapID) or ns.Neighbours(h.api, here, mapID)) and 2 or 3
    h.secOf[mapID] = s
  end
  return s
end

-- the distance to the place at index i of an NPC's places; nil on another continent or without a position
local function SpotDist(h, npc, i)
  local w = h.c and World(npc, h.api)
  if w and w[i] == h.c then
    local dn, dw = w[i + 1] - h.n, w[i + 2] - h.w
    return math.sqrt(dn * dn + dw * dw)
  end
  return nil
end

-- the nearest place of an NPC: its index in the places and the distance (the first place and nil when none is in reach)
local function Nearest(h, npc, p)
  local best, bestD = 1, nil
  if h.c then
    local w, pc, pn, pw = World(npc, h.api), h.c, h.n, h.w
    for i = 1, #p, 3 do
      if w[i] == pc then
        local dn, dw = w[i + 1] - pn, w[i + 2] - pw
        local d = math.sqrt(dn * dn + dw * dw)
        if not bestD or d < bestD then best, bestD = i, d end
      end
    end
  end
  return best, bestD
end

function ns.Search(role, text)
  role = ns.Str(role)
  local raw = ns.Str(text) and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
  text = raw:lower()
  local out = {}
  if not role and text == "" then return out end
  -- goods: the vendors of the group, and the vendors of what the text names (inside the group when one is chosen)
  local r = role and ns.Role(role)
  local group = r and r.goods or nil
  local asked = role
  if group then role = nil end
  local inGroup = group and ns.Sellers(group, "") or nil
  local byText = text ~= "" and ns.Sellers(group, text, raw) or nil
  local side, other = ns.PlayerSide(), ns.db and ns.db.otherSide
  local h = Here()
  local here = h.here
  -- (22.11.2026) the role as it stands in npc.roles, made once (was a new string per NPC in ns.HasRole)
  local roleKey = role and (" " .. role .. " ") or nil
  for _, npc in ipairs(ns.NPCs()) do
    if (other or not side or npc.side == "N" or npc.side == side)
        and (not roleKey or npc.roles:find(roleKey, 1, true))
        and (not inGroup or inGroup[npc.id])
        and (text == "" or npc.low:find(text, 1, true) or (byText and byText[npc.id])) then
      local sold = byText and byText[npc.id] or inGroup and inGroup[npc.id] or nil
      local p = ns.Places(npc)
      if npc.place then
        -- (11.11.2026, Daniel: "da gibt es ja viele möglichkeiten") a place line holds every cooking fire of a zone:
        -- each fire is a hit of its own, so the list shows the second and third nearest as well
        for i = 1, #p, 3 do
          local d = SpotDist(h, npc, i)
          out[#out + 1] = { npc = npc, role = asked, mapID = p[i], x = p[i + 1], y = p[i + 2], dist = d, spot = i,
            sec = d and Sec(h, p[i]) or (here and 3 or nil) }
        end
      else
        local best, bestD = Nearest(h, npc, p)
        if p[best] then
          out[#out + 1] = { npc = npc, role = asked, goods = sold, mapID = p[best], x = p[best + 1], y = p[best + 2], dist = bestD,
            sec = bestD and Sec(h, p[best]) or (here and 3 or nil) }
        end
      end
    end
  end
  table.sort(out, Before)
  return out, (not h.c) and "nopos" or nil
end

-- (22.11.2026, Ruckler, DonMonitor report: timer Window.lua:458 avg 58.6 ms every 2 s: the whole search ran again
-- whenever the player had moved) The hits of a search measured from where the player stands now and put in order
-- again: no walk over all NPCs and goods, no new tables. The hits of a search do not depend on the position, only
-- their distance, their part and, for an NPC with several places, which place is the nearest.
--   list: results of ns.Search (changed in place). flat: no parts (the window's "other roles"). before: the order
--   (default: the search's own).
--   -> state ("nopos" or nil), changed: true when the order, a part, a hit's place or whether it has a distance
--      changed (false: the rows only show other yards). A hit whose place changed loses .item (the window's row).
function ns.Resort(list, flat, before)
  before = before or Before
  local h = Here()
  local here = h.here
  local changed = false
  for n = 1, #list do
    local r = list[n]
    local npc = r.npc
    local p = ns.Places(npc)
    local i, d = r.spot, nil
    if i then
      d = SpotDist(h, npc, i)
    else
      i, d = Nearest(h, npc, p)
      if p[i] ~= r.mapID or p[i + 1] ~= r.x or p[i + 2] ~= r.y then
        r.mapID, r.x, r.y, r.item, changed = p[i], p[i + 1], p[i + 2], nil, true
      end
    end
    local sec = nil
    if not flat then sec = d and Sec(h, p[i]) or (here and 3 or nil) end
    if sec ~= r.sec or (d == nil) ~= (r.dist == nil) then changed = true end
    r.dist, r.sec = d, sec
  end
  -- mostly the order holds: sorted only when two neighbours stand the wrong way round
  for n = 2, #list do
    if before(list[n], list[n - 1]) then
      table.sort(list, before)
      changed = true
      break
    end
  end
  return (not h.c) and "nopos" or nil, changed
end

function ns.DistText(dist)
  if not dist then return "" end
  return L["%d yd"]:format(math.floor(dist + 0.5))
end
