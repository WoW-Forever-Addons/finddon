local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Options, built with ns.BuildSettings (DonCore Settings.lua): a tab in the options window of all Don addons, and a
-- page in Blizzard's settings with the status and a button to that window.
---------------------------------------------------------------------------
local category

local function Rerun() if ns.RunSearch then ns.RunSearch() end end

local PAGES = {
  { title = "General", tip = "Search window, arrow and pin, minimap button.", items = {
    { header = "Finddon" },
    { kind = "button", name = "Search window", button = "Show / hide", tip = "The window with the roles and the hits. /fd",
      onClick = function() ns.ToggleWindow() end, state = function() local p = _G.FinddonPanel return p ~= nil and p:IsShown() and true or false end },
    { key = "clearOnArrival", name = "Drop arrow and pin on arrival", tip = "A few seconds after you reach the NPC the arrow and the pin go away by themselves." },
    { key = "closeOnPick", name = "Close the window after a click", tip = "Clicking a hit sets the arrow and closes the search window." },
    { key = "otherSide", name = "Show the other faction", tip = "Also lists NPCs that only serve the other faction.", onChange = Rerun },
    ns.MinimapOption(),
    { kind = "button", name = "Drop arrow and pin", button = "Drop", tip = "Takes Finddon's target off the arrow and the maps. /fd clear",
      onClick = function() ns.ClearTarget() end },
    { kind = "button", name = "Reset position", button = "Reset", tip = "Puts the search window back to its default place and size.",
      onClick = function() ns.ResetWindow() end },
  } },
}

local function Status()
  local lines = {}
  local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)
  version = version and ns.Call(version, "Finddon", "Version")
  if type(version) == "string" and version ~= "" then lines[#lines + 1] = L["Version %s"]:format(version) end
  lines[#lines + 1] = L["%d NPCs in the data"]:format(tonumber(ns.NPC_COUNT) or 0)
  if not ns.Map() then lines[#lines + 1] = L["DonMap is missing: no arrow and no pin."] end
  return lines
end

local TOOLS = {
  { "Search window", "Show / hide", function() ns.ToggleWindow() end, "The window with the roles and the hits. /fd",
    state = function() local p = _G.FinddonPanel return p ~= nil and p:IsShown() and true or false end },
  { "Commands", "Show", function() ns.PrintHelp() end, "Lists the chat commands. /fd help" },
}
for _, t in ipairs(TOOLS) do t[3] = ns.Guard("tool", t[3]) end

local function Help()
  local lines = {}
  for _, c in ipairs(ns.COMMANDS or {}) do lines[#lines + 1] = c[1] .. "  " .. L[c[2]] end
  return table.concat(lines, "\n")
end

local function Build()
  category = ns.BuildSettings({ name = "Finddon", status = Status, tools = TOOLS, pages = PAGES, help = Help })
end

function ns.OpenOptions()
  if ns.OpenDonOptions and ns.OpenDonOptions() then return end
  if InCombatLockdown and InCombatLockdown() then
    ns.Print(L["Options cannot be opened in combat."])
    return
  end
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
  else
    ns.PrintHelp()
  end
end

ns.OnInit(Build)
