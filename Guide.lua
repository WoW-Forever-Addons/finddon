local _, ns = ...
local L = ns.L
local Core = LibStub("DonCore-1.0")
local Kit = Core:Get("Kit", 22)

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
    -- (11.11.2026, Daniel with a picture of Stormwind: "sehr groß" at 30 px square) the round pin: 28 px with its ring on
    -- the world map (the symbol inside is 15 px), 16 px without a ring on the minimap
    size = { world = 28, minimap = 16 },
    -- (11.11.2026, Daniel on the world map: "leider kaum erkennbar") an own pin with the role's symbol and the NPC's
    -- name under it on the world map. (Same day, chosen from the proposals) round in the gold ring like the Don
    -- addons' minimap buttons (Kit.RoundIcon); on the minimap the symbol alone.
    newPin = function(parent, size, where) return ns.NewPin(parent, size, where) end,
    paint = function(pin, points, size, _, where, scale) ns.PaintPin(pin, points, size, where, scale) end,
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

function ns.NewPin(parent, size, where)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b.where = where
  b.round = Kit.RoundIcon(b, size, { ring = where == "world" })
  b.round:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.icon = b.round.icon
  b.textHolder = CreateFrame("Frame", nil, b)
  b.textHolder:SetSize(1, 1)
  b.textHolder:SetPoint("TOP", b, "BOTTOM", 0, -1)
  b.label = b.textHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.label:SetPoint("TOP", b.textHolder, "TOP", 0, -2)
  -- a dark plate behind the name: gold letters alone were lost in the map's own lettering
  b.plate = b.textHolder:CreateTexture(nil, "BACKGROUND")
  b.plate:SetColorTexture(0, 0, 0, 0.7)
  b.plate:SetPoint("TOPLEFT", b.label, "TOPLEFT", -4, 2)
  b.plate:SetPoint("BOTTOMRIGHT", b.label, "BOTTOMRIGHT", 4, -2)
  if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  b:SetScript("OnEnter", function(self)
    if src and src.opts.tooltip then ns.SafeCall("pin tooltip", src.opts.tooltip, self) end
  end)
  b:SetScript("OnLeave", function(self)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.SafeCall("pin click", ns.ClearTarget) end
  end)
  return b
end

function ns.PaintPin(b, points, size, where, scale)
  local one = points[1] or {}
  b:SetSize(size, size)
  b.round:SetRing((where or b.where) == "world")
  b.round:SetRoundSize(size)
  b.round:SetIcon(one.icon or PIN)
  -- the name only on the world map; its holder keeps the text one size at every zoom
  scale = tonumber(scale) or 1
  if scale > 0 and b.textHolder.SetScale then pcall(b.textHolder.SetScale, b.textHolder, 1 / scale) end
  local text = (where or b.where) == "world" and tostring(one.label or "") or ""
  b.label:SetText(text)
  b.plate:SetShown(text ~= "")
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
    local role = ns.Role(result.role or "") or ns.Role(npc.first) -- the symbol of the role that was searched
    local icon = role and role.icon or PIN
    for i = 1, #p, 3 do
      -- a place (cooking fires of a zone): only the one the arrow leads to
      if not npc.place or (p[i] == result.mapID and p[i + 1] == result.x and p[i + 2] == result.y) then
      pts[#pts + 1] = { mapID = p[i], x = p[i + 1], y = p[i + 2], key = npc.id .. ":" .. i, icon = icon, label = npc.name }
      end
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

-- Opens the world map on the zone of a hit (its pin is there already). The game's world map shows a zone as a whole,
-- so "centred" means: that zone's map. Not in combat (the map is one of the game's panels).
function ns.ShowOnMap(result)
  if InCombatLockdown and InCombatLockdown() then
    ns.Print(L["The map cannot be opened in combat."])
    return false
  end
  if type(OpenWorldMap) == "function" then
    OpenWorldMap(result.mapID)
  elseif WorldMapFrame and WorldMapFrame.SetMapID then
    if not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
    WorldMapFrame:SetMapID(result.mapID)
  else
    return false
  end
  return true
end

-- /fd go <text>: the nearest hit of a role or a text gets the arrow at once; /fd map <text> opens the map there as well (as the row's map button)
function ns.GoNearest(text, openMap)
  local role = ns.RoleByText(text)
  local list = ns.Search(role and role.code or nil, role and "" or text)
  -- the list is in parts (this zone first): the nearest of all may stand in a later part
  local r = list[1]
  for _, x in ipairs(list) do
    if x.dist and (not r.dist or x.dist < r.dist) then r = x end
  end
  if not r then
    ns.Print(L["Nothing found for \"%s\"."]:format(tostring(text)))
    return false
  end
  if ns.SetTarget(r) then
    if openMap then ns.ShowOnMap(r) end
    local where = ns.ZoneName(r.mapID)
    local dist = ns.DistText(r.dist)
    ns.Print(L["Arrow to %s (%s)."]:format(r.npc.name, dist ~= "" and (where .. ", " .. dist) or where))
    return true
  end
  return false
end
