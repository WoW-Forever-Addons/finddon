local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Minimap button from DonCore (Libs\DonCore\MinimapButton.lua): left click opens the window, right click the menu of
-- the Don addons (window, drop the arrow, the switches, all options, hide the button), drag moves it.
---------------------------------------------------------------------------
local function StateLine()
  local t = ns.Target and ns.Target()
  if t then return { L["Arrow: %s"]:format(t.name) } end
  return { L["No arrow set"] }
end

local SWITCHES = {
  { label = "Drop arrow and pin on arrival", key = "clearOnArrival" },
  { label = "Close the window after a click", key = "closeOnPick" },
  { label = "Show the other faction", key = "otherSide", apply = function() if ns.RefreshWindow then ns.RunSearch() end end },
  { label = "NPC pictures", key = "pictures", apply = function() if ns.ApplyPictures then ns.ApplyPictures() end end },
  { label = "Large NPC preview", key = "preview", apply = function() if ns.ApplyPictures then ns.ApplyPictures() end end },
}

local function IsOn(sw) return ns.db and ns.db[sw.key] and true or false end

local function Toggle(sw)
  if type(ns.db) ~= "table" then return end
  ns.db[sw.key] = not IsOn(sw)
  if sw.apply then ns.SafeCall("minimap menu", sw.apply) end
  if ns.RefreshSettingsUI then ns.SafeCall("minimap menu", ns.RefreshSettingsUI) end
end
ns.MinimapMenuToggle = function(i) local sw = SWITCHES[i] if sw then Toggle(sw) end end -- (tests)

local function MenuItems()
  local items = {
    { text = L["Search window"], onClick = function() if ns.ToggleWindow then ns.ToggleWindow() end end },
    { text = L["Drop arrow and pin"], onClick = function() ns.ClearTarget() end },
    { line = true },
  }
  for _, sw in ipairs(SWITCHES) do
    items[#items + 1] = { text = L[sw.label], onClick = function() Toggle(sw) end, isOn = function() return IsOn(sw) end }
  end
  items[#items + 1] = { line = true }
  items[#items + 1] = { text = L["All options"], onClick = function() if ns.OpenOptions then ns.OpenOptions() end end }
  return items
end

LibStub("DonCore-1.0"):Get("MinimapButton", 4):Attach(ns, {
  name = "FinddonMinimapButton", addon = "Finddon",
  icon = "Interface\\AddOns\\Finddon\\Media\\minimap",
  angleKey = "minimapAngle", defaultAngle = 255,
  title = ns.WORDMARK,
  lines = function() local ok, t = pcall(StateLine) return ok and t or nil end,
  hint = function() return L["Left click: window. Right click: menu. Drag: move."] end,
  onLeft = function() if ns.ToggleWindow then ns.ToggleWindow() end end,
  menu = { name = "FinddonMinimapMenu", title = ns.WORDMARK, width = 260, items = MenuItems },
})

ns.OnInit(function() ns.SafeCall("minimap button", ns.RefreshMinimapButton) end)
