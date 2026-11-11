local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- The way to a picked NPC: DonMap's arrow (a clicked target, DonMapAPI.PRIO.click) and a pin on the world map and
-- the minimap (source "finddon"). It ends with a right-click on the pin or the arrow, with /fd clear, when another
-- target takes the arrow, or a moment after arriving (option clearOnArrival).
---------------------------------------------------------------------------
local ARRIVED_YARDS, ARRIVED_WAIT, TICK = 10, 4, 0.5
local PIN = "Interface\\AddOns\\Finddon\\Media\\minimap"
local target -- { npc =, name =, mapID =, x =, y =, arrow = the table given to DonMap, arrived = time }
local src, ticking

function ns.Target() return target end

local function Source()
  if src then return src end
  local api = ns.Map()
  if not (api and api.Register) then return nil end
  src = api.Register("finddon", {
    title = "Finddon", layer = 3, world = true, minimap = true,
    size = { world = 22, minimap = 16 },
    onClick = function(_, button)
      if button == "RightButton" then ns.ClearTarget() end
    end,
    tooltip = function(pin)
      if not target then return end
      local lines = {}
      if target.npc.title ~= "" then lines[#lines + 1] = target.npc.title end
      local rt = ns.RoleText(target.npc)
      if rt ~= "" then lines[#lines + 1] = rt end
      ns.Style.Tooltip(pin, target.name, lines, L["Right-click: drop arrow and pin."])
    end,
  })
  return src
end

function ns.ClearTarget()
  local had = target ~= nil
  target = nil
  local api = ns.Map()
  if api then pcall(api.SetArrowTarget, "finddon", nil) end
  if src then src:Clear() end
  if had and ns.RefreshWindow then ns.RefreshWindow() end
end

-- the arrow still shows our target (or the way to the corpse, which comes first for a while)
local function StillOurs()
  local api = ns.Map()
  if not (api and target and api.ArrowTarget) then return false end
  local ok, t, source = pcall(api.ArrowTarget)
  if not ok then return false end
  if source == "corpse" then return true end
  return t == target.arrow
end

local function Tick()
  ticking = false
  if not target then return end
  local api = ns.Map()
  if not api then return end
  -- DonMap's arrow may be switched off: then the pin alone leads, and nothing can take the target away
  local runs = type(api.ArrowRuns) ~= "function" or api.ArrowRuns()
  if runs and not StillOurs() then ns.ClearTarget() return end
  if ns.db.clearOnArrival then
    local dist = api.DistanceTo(target.mapID, target.x, target.y)
    local now = GetTime()
    if dist and dist <= ARRIVED_YARDS then
      target.arrived = target.arrived or now
      if now - target.arrived >= ARRIVED_WAIT then ns.ClearTarget() return end
    else
      target.arrived = nil
    end
  end
  ticking = true
  ns.After(TICK, Tick)
end

-- result: a row of ns.Search. Returns true when the way is set.
function ns.SetTarget(result)
  local api = ns.Map()
  if not api then
    ns.Print(L["DonMap is missing: no arrow and no pin."])
    return false
  end
  local npc = result.npc
  local arrow = { mapID = result.mapID, x = result.x, y = result.y, label = npc.name, arrivedText = L["Arrived"] }
  target = { npc = npc, name = npc.name, mapID = result.mapID, x = result.x, y = result.y, arrow = arrow }
  pcall(api.SetArrowTarget, "finddon", arrow, api.PRIO and api.PRIO.click or 3)
  local s = Source()
  if s then
    local pts, p = {}, ns.Places(npc)
    for i = 1, #p, 3 do
      pts[#pts + 1] = { mapID = p[i], x = p[i + 1], y = p[i + 2], key = npc.id .. ":" .. i, icon = PIN }
    end
    s:SetPoints(pts)
    s:Update()
  end
  if not ticking then
    ticking = true
    ns.After(TICK, Tick)
  end
  if ns.RefreshWindow then ns.RefreshWindow() end
  return true
end

-- /fd go <text>: the nearest hit of a role or a text gets the arrow at once
function ns.GoNearest(text)
  local role = ns.RoleByText(text)
  local list = ns.Search(role and role.code or nil, role and "" or text)
  local r = list[1]
  if not r then
    ns.Print(L["Nothing found for \"%s\"."]:format(tostring(text)))
    return false
  end
  if ns.SetTarget(r) then
    local where = ns.ZoneName(r.mapID)
    local dist = ns.DistText(r.dist)
    ns.Print(L["Arrow to %s (%s)."]:format(r.npc.name, dist ~= "" and (where .. ", " .. dist) or where))
    return true
  end
  return false
end
