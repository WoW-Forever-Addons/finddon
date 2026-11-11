local _, ns = ...
local L = ns.L
local Core = LibStub("DonCore-1.0")
local Kit = Core:Get("Kit", 10) or Core:Get("Kit", 1)

---------------------------------------------------------------------------
-- The window, DonCore's kit only: Kit.Window "FinddonPanel" (place and size in FinddonDB.win), on the left the roles
-- (Kit.List with group headers), on the right a search box over the hits (Kit.List), nearest first.
-- Left click on a hit: arrow and pin (Guide.lua). Right click: drop them. The same role again: no role.
---------------------------------------------------------------------------
local W
local state = { role = nil, text = "", results = {}, note = nil, at = nil }
local ROLE_W, ROLE_W_NARROW, NARROW, SEARCH_H, GAP = 190, 150, 520, 28, 6
local MOVED = 15 -- yards the player must have moved before an open list is sorted anew

local function RoleItems()
  local items, group = {}, nil
  for _, r in ipairs(ns.Roles()) do
    if r.group ~= group then
      group = r.group
      items[#items + 1] = { kind = "group", static = true, text = L[group] }
    end
    items[#items + 1] = { key = r.code, title = r.label, icon = r.icon, compact = true, h = 28, active = state.role == r.code }
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
  if n > 1 then lines[#lines + 1] = L["%d known places, the nearest is shown."]:format(n) end
  if npc.side ~= "N" and npc.side ~= ns.PlayerSide() then lines[#lines + 1] = L["Other faction"] end
  return npc.name, lines, L["Left click: arrow and pin. Right click: drop them."]
end

local function ResultItems()
  local items, target = {}, ns.Target()
  for _, r in ipairs(state.results) do
    local npc = r.npc
    local role = ns.Role(state.role or "") or ns.Role(npc.first)
    local it = { key = npc.id, result = r, icon = role and role.icon or nil,
      title = npc.level and ("%s  |cff9ea3ad%s|r"):format(npc.name, npc.level) or npc.name,
      sub = Sub(npc, r.mapID), right = ns.DistText(r.dist), active = target ~= nil and target.npc == npc }
    it.tooltipFn = function() return Tip(r) end
    items[#items + 1] = it
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
  local t = ns.Target()
  if t then text = text .. " · " .. L["Arrow: %s"]:format(t.name) end
  W:SetStatus(text)
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
  win.line:ClearAllPoints()
  win.line:SetPoint("TOPLEFT", win.body, "TOPLEFT", rw, 0)
  win.line:SetSize(1, h)
  win.search:ClearAllPoints()
  win.search:SetPoint("TOPLEFT", win.body, "TOPLEFT", rw + 1 + GAP, -GAP)
  win.search:SetWidth(math.max(60, w - rw - 1 - 2 * GAP))
  win.list:ClearAllPoints()
  win.list:SetPoint("TOPLEFT", win.body, "TOPLEFT", rw + 1, -(SEARCH_H + 2 * GAP))
  win.list:Resize(math.max(60, w - rw - 1), math.max(20, h - SEARCH_H - 2 * GAP))
end

local function Build()
  W = Kit.Window("FinddonPanel", { title = "Finddon", logo = "Interface\\AddOns\\Finddon\\Media\\minimap",
    options = "Finddon", hint = "/fd options", footer = true, store = ns.db.win, width = 620, height = 520,
    min = { 420, 300 }, max = { 1000, 900 },
    onLayout = function(win, w, h) Place(win, w, h) end })
  W:Hide()
  W.roles = Kit.List(W.body, { onClick = function(it)
    if not it.key then return end
    state.role = state.role ~= it.key and it.key or nil
    ns.db.role = state.role or ""
    Run(true)
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
  W.list = Kit.List(W.body, { onClick = function(it, button)
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
    W:SetSize(620, 520)
    W:Layout()
  end
end

-- (tests, diag) what the window shows
function ns.WindowState() return state, W end
