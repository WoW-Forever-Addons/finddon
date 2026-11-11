local _, ns = ...
local L = ns.L
local Core = LibStub("DonCore-1.0")
local Kit = Core:Get("Kit", 22) or Core:Get("Kit", 10) or Core:Get("Kit", 1)

---------------------------------------------------------------------------
-- The window, DonCore's kit only: Kit.Window "FinddonPanel" (place and size in FinddonDB.win), on the left the roles
-- (Kit.List with group headers), on the right a search box over the hits (Kit.List), nearest first.
-- Left click on a hit: arrow and pin (Guide.lua). Right click: drop them. The same role again: no role.
---------------------------------------------------------------------------
local W
local state = { role = nil, text = "", results = {}, note = nil, at = nil }
-- (11.11.2026, proposals 8 and 5) the role column 204 wide (was 190: long names and the favourite's star were tight)
local ROLE_W, ROLE_W_NARROW, NARROW, SEARCH_H, GAP = 204, 160, 540, 28, 6
local WIN_W, WIN_H = 660, 520
local MOVED = 15 -- yards the player must have moved before an open list is sorted anew
-- the row's map button: width, distance from the right edge (room for the distance or a continent's name)
local MAP_W, MAP_X = 46, 100
local PREVIEW_MIN_H, NAME_H, INFO_H = 430, 22, 28 -- the large picture under the roles needs this much height
local NEAR, MID = 100, 500 -- yards: the distance green below NEAR, yellow below MID, quiet beyond
local EXTRA, EXTRA_MAX = 14, 4 -- the small symbols of an NPC's other roles behind its name
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t" -- a favourite role
local SECTIONS = { "In this zone", "Neighbouring zones", "Further away" }

-- The large picture of the hit under the mouse. (11.11.2026, Daniel: "die 3d vorschau nur wenn ich noch mit der maus
-- in der trefferleiste bin", "die stört wenn ich links was anderes suchen will") It lies over the lower part of the
-- role list only while the mouse is on the hits; the roles keep their whole height. npc = nil hides it.
local hideToken = 0
-- (11.11.2026, proposal 7) under the model: what the NPC is (title, else its roles), then its zone and, for a rare,
-- its level; the model turns slowly (Picture.lua).
function ns.Preview(npc, result)
  if not (W and W.preview) then return end
  hideToken = hideToken + 1
  if npc and npc.place then npc = nil end
  W.previewNpc = npc
  local on = npc ~= nil and W.previewRoom == true and ns.db.pictures and true or false
  W.preview:SetShown(on)
  ns.ShowModel(W.preview.model, on and npc or nil)
  W.preview.name:SetText(on and npc.name or "")
  local what, where = "", ""
  if on then
    what = npc.title ~= "" and npc.title or ns.RoleText(npc)
    where = result and ns.ZoneName(result.mapID) or ""
    if npc.level and ns.HasRole(npc, "x") then
      local lv = L["Level"] .. " " .. (npc.level:gsub("%+", " " .. L["Elite"]))
      where = where ~= "" and (where .. " · " .. lv) or lv
    end
  end
  W.preview.what:SetText(what)
  W.preview.where:SetText(where)
  if on then
    local w = (W.preview._w or 150) - 8
    Kit.Fit(W.preview.name, w)
    Kit.Fit(W.preview.what, w)
    Kit.Fit(W.preview.where, w)
  end
end

-- the mouse left a hit: the picture goes unless it is on another hit a moment later (row to row, the map button)
local function PreviewLeave()
  hideToken = hideToken + 1
  local mine = hideToken
  ns.After(0.2, function()
    if mine ~= hideToken or not W then return end
    if W.list.IsMouseOver and W.list:IsMouseOver() then return end
    ns.Preview(nil)
  end)
end

-- a hit row with the NPC's picture over its role symbol (list kind "npc")
local function MakeRow(parent)
  local r = Kit.ListRow(parent)
  r.model = ns.NewModel(r, true)
  -- (11.11.2026, Daniel: "direkt zur map springen", then "anstatt mit shift irgendwas zu klicken einfach ein button vor
  -- den yards mit show on map") a button left of the distance: arrow, pin and the world map on that zone
  r.map = Kit.Button(r, L["Map"], { small = true, onClick = function()
    local res = r.item and r.item.result
    if not res then return end
    if ns.SetTarget(res) then ns.ShowOnMap(res) end
  end })
  r.map:SetWidth(MAP_W)
  r.map:SetPoint("RIGHT", r, "RIGHT", -MAP_X, 0)
  if r.map.SetTooltip then r.map:SetTooltip(L["Show on map"], { L["Sets arrow and pin and opens the world map on this zone."] }) end
  if r.model and r.iconBox then r.model:SetAllPoints(r.iconBox) end
  -- (11.11.2026, Daniel: "die yards anzeige dürfte auch mittig in der zeile sein") the distance in the middle of the
  -- row's height (the kit puts it on the first line), after every layout of the row
  -- (11.11.2026, proposal 3) the NPC's other roles as small symbols behind its name (a vendor who also repairs)
  r.extra = {}
  for i = 1, EXTRA_MAX do
    local t = r:CreateTexture(nil, "ARTWORK")
    t:SetSize(EXTRA, EXTRA)
    t:Hide()
    r.extra[i] = t
  end
  local layout = r.Layout
  r.Layout = function(self, w)
    layout(self, w)
    if self.right then
      self.right:ClearAllPoints()
      self.right:SetPoint("RIGHT", self, "RIGHT", -12, 0)
      Kit.Fit(self.right, MAP_X - 18) -- a continent's name ends before the map button
    end
    -- the symbols follow the name; one that would reach the map button stays away
    local roles = self.item and self.item.extra
    local tw = Kit.TextWidth and Kit.TextWidth(self.title) or 0
    local room = (tonumber(w) or 0) - (MAP_X + MAP_W) - 6
    for i, t in ipairs(self.extra) do
      local role = roles and roles[i]
      local x = tw + 6 + (i - 1) * (EXTRA + 2)
      t:ClearAllPoints()
      t:SetPoint("LEFT", self.title, "LEFT", x, 0)
      local left = self.title.GetLeft and self.GetLeft and self.title:GetLeft() and self:GetLeft() and (self.title:GetLeft() - self:GetLeft()) or 60
      if role and left + x + EXTRA <= room then
        t:SetTexture(role.icon)
        if role.icon:lower():find("^interface\\icons\\") then t:SetTexCoord(0.08, 0.92, 0.08, 0.92) else t:SetTexCoord(0, 1, 0, 1) end
        t:Show()
      else
        t:Hide()
      end
    end
  end
  local set = r.SetItem
  r.SetItem = function(self, it, ...)
    set(self, it, ...)
    local npc = it and it.result and it.result.npc
    ns.ShowModel(self.model, npc and not npc.place and npc or nil)
  end
  return r
end

local function RoleItem(r, fav)
  -- rightWidth = 0: no right column, the name gets the whole row (Daniel 11.11.: the names were cut after four letters);
  -- a favourite keeps room for its star
  return { key = r.code, title = r.label, icon = r.icon, compact = true, h = 28, rightWidth = fav and 14 or 0,
    right = fav and STAR or nil, active = state.role == r.code,
    -- (11.11.2026, proposal 5) the own class in its colour
    titleColor = r.class and Kit.ClassColor and Kit.ClassColor(r.class) or nil,
    tooltip = { r.label, { fav and L["Right-click: no longer a favourite."] or L["Right-click: make it a favourite."] } } }
end

local function RoleItems()
  local items, group = {}, nil
  -- (11.11.2026, proposal 5, "weil man meist dieselben drei Rollen sucht") favourites: a right-click on a role puts it
  -- into a group of its own at the top (FinddonDB.favs); it stays in its group as well, with a star
  local favs = ns.db.favs
  if next(favs) then
    items[#items + 1] = { kind = "group", group = "Favourites", text = L["Favourites"], collapsed = ns.db.closed.Favourites and true or false }
    if not ns.db.closed.Favourites then
      for _, r in ipairs(ns.Roles()) do
        if favs[r.code] then items[#items + 1] = RoleItem(r, true) end
      end
    end
  end
  for _, r in ipairs(ns.Roles()) do
    if r.group ~= group then
      group = r.group
      -- (11.11.2026, Daniel: "die einzelnen reiter noch zusammenklappbar machen") a click folds the group, kept in
      -- FinddonDB.closed; the group of the chosen role says so while it is folded
      items[#items + 1] = { kind = "group", group = group, text = L[group], collapsed = ns.db.closed[group] and true or false }
    end
    if not ns.db.closed[group] then items[#items + 1] = RoleItem(r, favs[r.code] and true or false) end
  end
  return items
end

local function Sub(npc, mapID)
  local what = npc.title ~= "" and npc.title or ns.RoleText(npc)
  local zone = ns.ZoneName(mapID)
  if what ~= "" and zone ~= "" then return what .. " · " .. zone end
  return what ~= "" and what or zone
end

local function Tip(r)
  local npc = r.npc
  local lines = {}
  if npc.title ~= "" then lines[#lines + 1] = npc.title end
  local rt = ns.RoleText(npc)
  if rt ~= "" then lines[#lines + 1] = { L["Role"], rt } end
  if npc.level then lines[#lines + 1] = { L["Level"], (npc.level:gsub("%+", " " .. L["Elite"])) } end
  local zone = ns.ZoneName(r.mapID)
  lines[#lines + 1] = { L["Zone"], ("%s %.1f, %.1f"):format(zone, r.x * 100, r.y * 100) }
  if r.dist then lines[#lines + 1] = { L["Distance"], ns.DistText(r.dist) } end
  local n = #ns.Places(npc) / 3
  if n > 1 and not npc.place then lines[#lines + 1] = L["%d known places, the nearest is shown."]:format(n) end
  if npc.side ~= "N" and npc.side ~= ns.PlayerSide() then lines[#lines + 1] = L["Other faction"] end
  return npc.name, lines, L["Click: arrow and pin. Right click: drop them."]
end

local function ResultItems()
  local items, target = {}, ns.Target()
  -- (11.11.2026, proposal 4) the list in parts: this zone, neighbouring zones, further away; a click on a head folds
  -- its part (FinddonDB.closedHits). Without a position the hits have no part and the list has no heads.
  local counts, sec = {}, nil
  for _, r in ipairs(state.results) do if r.sec then counts[r.sec] = (counts[r.sec] or 0) + 1 end end
  for _, r in ipairs(state.results) do
    if r.sec and r.sec ~= sec then
      sec = r.sec
      items[#items + 1] = { kind = "group", sec = sec, text = L[SECTIONS[sec]], count = counts[sec],
        collapsed = ns.db.closedHits[sec] and true or false }
    end
    if not (r.sec and ns.db.closedHits[r.sec]) then
      local npc = r.npc
      local role = ns.Role(state.role or "") or ns.Role(npc.first)
      -- (proposal 3) the distance in a colour by nearness; on another continent that continent's name in its place
      local right, color = ns.DistText(r.dist), nil
      if r.dist then
        color = r.dist < NEAR and Kit.C.green or r.dist < MID and Kit.C.yellow or nil
      elseif state.note ~= "nopos" then
        right, color = ns.ContinentName(r.mapID), Kit.C.quiet
      end
      local it = { kind = "npc", key = r.spot and (npc.id .. ":" .. r.spot) or npc.id, result = r, icon = role and role.icon or nil,
        title = npc.level and ("%s  |cff9ea3ad%s|r"):format(npc.name, npc.level) or npc.name,
        extra = not npc.place and ns.OtherRoles(npc, role and role.code) or nil,
        sub = Sub(npc, r.mapID), right = right, rightColor = color, rightWidth = MAP_X + MAP_W - 12,
        active = target ~= nil and target.npc == npc and (not r.spot or (target.x == r.x and target.y == r.y)) }
      it.tooltipFn = function() return Tip(r) end
      it.onHover = function(_, on) if on then ns.Preview(npc, r) else PreviewLeave() end end
      items[#items + 1] = it
    end
  end
  return items
end

local function Status()
  if not W then return end
  local n = #state.results
  local text
  if not state.role and state.text == "" then
    text = L["Choose a role or type a name."]
  elseif n == 0 then
    text = L["Nothing found."]
  else
    text = (n == 1 and L["%d hit"] or L["%d hits"]):format(n)
    if state.note == "nopos" then text = text .. " · " .. L["No position here: sorted by zone."] end
  end
  -- (11.11.2026, proposal 8) with an arrow set the footer takes a click: it drops arrow and pin
  local t = ns.Target()
  if t then
    text = text .. " · " .. L["Arrow: %s"]:format(t.name)
    W:SetStatus(text, function() ns.ClearTarget() end, { L["Arrow: %s"]:format(t.name), nil, L["Click: drop arrow and pin."] })
  else
    W:SetStatus(text)
  end
end

local function Draw(reset)
  if not (W and W.built) then return end
  W.roles:SetItems(RoleItems())
  W.list:SetEmpty((state.role or state.text ~= "") and L["Nothing found."] or L["Choose a role or type a name."])
  W.list:SetItems(ResultItems(), reset)
  local role = ns.Role(state.role or "")
  W:SetSubtitle(role and role.label or "")
  Status()
end

local function Run(reset)
  state.results, state.note = ns.Search(state.role, state.text)
  local api = ns.Map()
  if api then
    local c, n, w = api.PlayerWorld()
    state.at = c and { c, n, w } or nil
  end
  Draw(reset)
end
ns.RunSearch = function() Run(true) end

function ns.RefreshWindow()
  if W and W:IsShown() then Draw() end
end

-- the option "pictures" changed: rows and the preview again
function ns.ApplyPictures()
  if not (W and W.built) then return end
  W:Layout()
  if not ns.db.pictures then ns.Preview(nil) end
  if W:IsShown() then Draw() end
end

-- while the window is open the list follows the player: sorted anew once he moved MOVED yards
local watching
local function Watch()
  watching = false
  if not (W and W:IsShown()) then return end
  local api = ns.Map()
  if api and (state.role or state.text ~= "") then
    local c, n, w = api.PlayerWorld()
    local at = state.at
    if c and (not at or at[1] ~= c or math.abs(at[2] - n) + math.abs(at[3] - w) > MOVED) then Run() end
  end
  watching = true
  ns.After(2, Watch)
end

local function Place(win, w, h)
  if not win.built then return end
  local rw = w < NARROW and ROLE_W_NARROW or ROLE_W
  win.roles:ClearAllPoints()
  win.roles:SetPoint("TOPLEFT", win.body, "TOPLEFT", 0, 0)
  win.roles:Resize(rw, h)
  local ph = rw + NAME_H + INFO_H
  win.previewRoom = h >= PREVIEW_MIN_H
  if not win.previewRoom then win.preview:Hide() end
  do
    win.preview:ClearAllPoints()
    win.preview:SetPoint("BOTTOMLEFT", win.body, "BOTTOMLEFT", 0, 0)
    win.preview:SetSize(rw, ph)
    win.preview._w = rw
    if win.preview.model then
      win.preview.model:ClearAllPoints()
      win.preview.model:SetPoint("TOPLEFT", win.preview, "TOPLEFT", GAP, -GAP)
      win.preview.model:SetSize(rw - 2 * GAP, rw - 2 * GAP)
    end
  end
  win.line:ClearAllPoints()
  win.line:SetPoint("TOPLEFT", win.body, "TOPLEFT", rw, 0)
  win.line:SetSize(1, h)
  win.search:ClearAllPoints()
  win.search:SetPoint("TOPLEFT", win.body, "TOPLEFT", rw + 1 + GAP, -GAP)
  win.search:Layout(math.max(60, w - rw - 1 - 2 * GAP))
  win.list:ClearAllPoints()
  win.list:SetPoint("TOPLEFT", win.body, "TOPLEFT", rw + 1, -(SEARCH_H + 2 * GAP))
  win.list:Resize(math.max(60, w - rw - 1), math.max(20, h - SEARCH_H - 2 * GAP))
end

local function Build()
  W = Kit.Window("FinddonPanel", { title = "Finddon", logo = "Interface\\AddOns\\Finddon\\Media\\minimap",
    options = "Finddon", hint = "/fd options", footer = true, store = ns.db.win, width = WIN_W, height = WIN_H,
    min = { 420, 300 }, max = { 1000, 900 },
    onLayout = function(win, w, h) Place(win, w, h) end })
  W:Hide()
  W.roles = Kit.List(W.body, { onClick = function(it, button)
    if not it.key then return end
    if button == "RightButton" then
      ns.db.favs[it.key] = not ns.db.favs[it.key] or nil
      Draw()
      return
    end
    state.role = state.role ~= it.key and it.key or nil
    ns.db.role = state.role or ""
    Run(true)
  end, onToggle = function(it)
    ns.db.closed[it.group] = it.collapsed and true or nil
    Draw()
  end })
  W.line = CreateFrame("Frame", nil, W.body)
  W.line.tex = W.line:CreateTexture(nil, "ARTWORK")
  W.line.tex:SetAllPoints()
  local d = Kit.C.divider
  W.line.tex:SetColorTexture(d[1], d[2], d[3], 1)
  W.search = Kit.SearchBox(W.body, { placeholder = L["Name or title"], onChange = function(t)
    local text = tostring(t or "")
    if text == state.text then return end
    state.text = text
    Run(true)
  end })
  W.preview = CreateFrame("Frame", nil, W.body)
  if W.preview.SetFrameLevel and W.roles.GetFrameLevel then W.preview:SetFrameLevel((W.roles:GetFrameLevel() or 1) + 20) end
  W.preview.bg = W.preview:CreateTexture(nil, "BACKGROUND")
  W.preview.bg:SetAllPoints()
  W.preview.bg:SetColorTexture(Kit.C.window[1], Kit.C.window[2], Kit.C.window[3], 1)
  W.preview.line = W.preview:CreateTexture(nil, "ARTWORK")
  W.preview.line:SetPoint("TOPLEFT") W.preview.line:SetPoint("TOPRIGHT") W.preview.line:SetHeight(1)
  W.preview.line:SetColorTexture(d[1], d[2], d[3], 1)

  W.preview.model = ns.NewModel(W.preview, false, true)
  W.preview.name = Kit.Text(W.preview, "sub", Kit.C.title, "CENTER")
  W.preview.name:SetPoint("BOTTOM", W.preview, "BOTTOM", 0, 5 + INFO_H)
  W.preview.what = Kit.Text(W.preview, "sub", Kit.C.muted, "CENTER")
  W.preview.what:SetPoint("BOTTOM", W.preview, "BOTTOM", 0, 5 + INFO_H / 2)
  W.preview.where = Kit.Text(W.preview, "sub", Kit.C.muted, "CENTER")
  W.preview.where:SetPoint("BOTTOM", W.preview, "BOTTOM", 0, 5)
  W.preview:Hide()
  W.list = Kit.List(W.body, { kinds = { npc = { h = 36, make = MakeRow } }, onToggle = function(it)
    ns.db.closedHits[it.sec] = it.collapsed and true or nil
    Draw()
  end, onClick = function(it, button)
    if not it.result then return end
    if button == "RightButton" then
      ns.ClearTarget()
    else
      ns.SetTarget(it.result)
      if ns.db.closeOnPick then W:Hide() end
    end
  end })
  W:SetScript("OnShow", function()
    Run()
    if not watching then watching = true ns.After(2, Watch) end
  end)
  W.built = true
  W:Layout()
end

local function Ensure()
  if W then return true end
  if not Kit then ns.Print("DonCore Kit?") return false end
  local saved = ns.db.role
  state.role = saved ~= "" and ns.Role(saved) and saved or nil
  Build()
  return true
end

function ns.ToggleWindow()
  if not Ensure() then return end
  if W:IsShown() then W:Hide() else W:Show() end
end

-- /fd <text>: a role's name picks the role, anything else is searched in names and titles
function ns.ShowSearch(text)
  if not Ensure() then return end
  local role = ns.RoleByText(text)
  if role then
    state.role, state.text = role.code, ""
    ns.db.role = role.code
  else
    state.role, state.text = nil, tostring(text or "")
  end
  if W.search.SetText then W.search:SetText(state.text) end
  if W:IsShown() then Run(true) else W:Show() end
end

function ns.ResetWindow()
  local st = ns.db.win
  st.point, st.relPoint, st.x, st.y, st.w, st.h = nil, nil, nil, nil, nil, nil
  if W then
    W:ClearAllPoints()
    W:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    W:SetSize(WIN_W, WIN_H)
    W:Layout()
  end
end

-- (tests, diag) what the window shows
function ns.WindowState() return state, W end
