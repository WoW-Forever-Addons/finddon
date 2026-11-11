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
  local api = ns.Map()
  local pc, pn, pw
  if api then pc, pn, pw = api.PlayerWorld() end
  -- the player's map (a city has its own) and the zone around it, for the parts of the list
  local here, zone
  if pc and api.PlayerPosition then
    here = api.PlayerPosition()
    zone = here and api.ZoneMap and api.ZoneMap(here) or here
  end
  local secOf = {}
  local function Sec(mapID)
    if not here then return nil end
    local s = secOf[mapID]
    if not s then
      s = (mapID == here or mapID == zone) and 1 or (ns.Neighbours(api, zone or here, mapID) or ns.Neighbours(api, here, mapID)) and 2 or 3
      secOf[mapID] = s
    end
    return s
  end
  for _, npc in ipairs(ns.NPCs()) do
    if (other or not side or npc.side == "N" or npc.side == side)
        and (not role or ns.HasRole(npc, role))
        and (not inGroup or inGroup[npc.id])
        and (text == "" or npc.low:find(text, 1, true) or (byText and byText[npc.id])) then
      local sold = byText and byText[npc.id] or inGroup and inGroup[npc.id] or nil
      local p = ns.Places(npc)
      local best, bestD = 1, nil
      if npc.place then
        -- (11.11.2026, Daniel: "da gibt es ja viele möglichkeiten") a place line holds every cooking fire of a zone:
        -- each fire is a hit of its own, so the list shows the second and third nearest as well
        local w = pc and World(npc, api)
        for i = 1, #p, 3 do
          local d
          if w and w[i] == pc then
            local dn, dw = w[i + 1] - pn, w[i + 2] - pw
            d = math.sqrt(dn * dn + dw * dw)
          end
          out[#out + 1] = { npc = npc, role = asked, mapID = p[i], x = p[i + 1], y = p[i + 2], dist = d, spot = i,
            sec = d and Sec(p[i]) or (here and 3 or nil) }
        end
        best = nil
      elseif pc then
        local w = World(npc, api)
        for i = 1, #p, 3 do
          if w[i] == pc then
            local dn, dw = w[i + 1] - pn, w[i + 2] - pw
            local d = math.sqrt(dn * dn + dw * dw)
            if not bestD or d < bestD then best, bestD = i, d end
          end
        end
      end
      if best and p[best] then
        out[#out + 1] = { npc = npc, role = asked, goods = sold, mapID = p[best], x = p[best + 1], y = p[best + 2], dist = bestD,
          sec = bestD and Sec(p[best]) or (here and 3 or nil) }
      end
    end
  end
  table.sort(out, Before)
  return out, (not pc) and "nopos" or nil
end

function ns.DistText(dist)
  if not dist then return "" end
  return L["%d yd"]:format(math.floor(dist + 0.5))
end
