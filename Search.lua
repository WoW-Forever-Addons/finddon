local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Search: NPCs of a role and / or with a text in name or title, own faction and neutral (the other faction with the
-- option), sorted by the distance from here. An NPC with several places (rares) counts with its nearest one.
--   ns.Search(role, text) -> results { { npc =, mapID =, x =, y =, dist = yards or nil }, ... }, state
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

local function Before(a, b)
  if a.dist and b.dist then
    if a.dist ~= b.dist then return a.dist < b.dist end
  elseif a.dist or b.dist then
    return a.dist ~= nil
  else
    local za, zb = ns.ZoneName(a.mapID), ns.ZoneName(b.mapID)
    if za ~= zb then return za < zb end
  end
  if a.npc.name ~= b.npc.name then return a.npc.name < b.npc.name end
  return a.npc.id < b.npc.id
end

function ns.Search(role, text)
  role = ns.Str(role)
  text = ns.Str(text) and text:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
  local out = {}
  if not role and text == "" then return out end
  local side, other = ns.PlayerSide(), ns.db and ns.db.otherSide
  local api = ns.Map()
  local pc, pn, pw
  if api then pc, pn, pw = api.PlayerWorld() end
  for _, npc in ipairs(ns.NPCs()) do
    if (other or not side or npc.side == "N" or npc.side == side)
        and (not role or ns.HasRole(npc, role))
        and (text == "" or npc.low:find(text, 1, true)) then
      local p = ns.Places(npc)
      local best, bestD = 1, nil
      if pc then
        local w = World(npc, api)
        for i = 1, #p, 3 do
          if w[i] == pc then
            local dn, dw = w[i + 1] - pn, w[i + 2] - pw
            local d = math.sqrt(dn * dn + dw * dw)
            if not bestD or d < bestD then best, bestD = i, d end
          end
        end
      end
      if p[best] then
        out[#out + 1] = { npc = npc, mapID = p[best], x = p[best + 1], y = p[best + 2], dist = bestD }
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
