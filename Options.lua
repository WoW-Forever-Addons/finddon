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
      onClick = function() ns.ToggleWindow() end, state = function() return ns.WindowShown and ns.WindowShown() or false end },
    { key = "clearOnArrival", name = "Drop arrow and pin on arrival", tip = "A few seconds after you reach the NPC the arrow and the pin go away by themselves." },
    { key = "closeOnPick", name = "Close the window after a click", tip = "Clicking a hit sets the arrow and closes the search window." },
    { key = "pictures", name = "NPC pictures", tip = "Shows the NPC's 3D model in each row. New WoW Forever NPCs may have none.",
      onChange = function() if ns.ApplyPictures then ns.ApplyPictures() end end },
    { key = "preview", name = "Large NPC preview", tip = "Shows the NPC's 3D model large under the roles while the mouse is on a hit. Needs the NPC pictures.",
      onChange = function() if ns.ApplyPictures then ns.ApplyPictures() end end },
    -- (16.11.2026, Daniel: Blizzard look for all Don addons, on by default) the search window from the game's own
    -- templates (DonCore Blizz); a change builds the window again, the options follow after a /reload
    -- (20.11.2026, Daniel: the same option in every Don addon) the choice "Window style" with "Don look" and
    -- "Blizzard look" from DonCore (Settings minor 6, ns.LookOption: name, entries and tooltip in the game's language)
    ns.LookOption({ addon = "Finddon", onChange = function() if ns.WindowReset then ns.WindowReset() end end }),
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
    state = function() return ns.WindowShown and ns.WindowShown() or false end },
  { "Commands", "Show", function() ns.PrintHelp() end, "Lists the chat commands. /fd help" },
}
for _, t in ipairs(TOOLS) do t[3] = ns.Guard("tool", t[3]) end

local function Help()
  local lines = {}
  for _, c in ipairs(ns.COMMANDS or {}) do lines[#lines + 1] = c[1] .. "  " .. L[c[2]] end
  return table.concat(lines, "\n")
end

local fullPages = false
local function Build()
  local spec = { name = "Finddon", status = Status, tools = TOOLS, pages = PAGES, help = Help,
    -- (16.11.2026, DonCore Options 6) with the Blizzard look (option blizzLook, "Window style") every cog and /fd options ends in the game's settings
    redirect = function() return ns.OpenGameOptions and ns.OpenGameOptions() or false end }
  -- (16.11.2026, DonCore Settings 3) the game's look: the full pages in the game's settings although DonCore's window
  -- is there (only where the client has the templates: without them the window is Don's and so is the options window)
  if ns.db and ns.db.blizzLook and select(2, ns.LookKit()) then spec.fullPages, fullPages = true, true end
  category = ns.BuildSettings(spec)
end

-- true when the game's settings were opened at Finddon (option blizzLook, pages built in full at login, not in combat)
function ns.OpenGameOptions()
  if not (ns.db and ns.db.blizzLook and fullPages and category and Settings and Settings.OpenToCategory) then return false end
  if InCombatLockdown and InCombatLockdown() then ns.Print(L["Options cannot be opened in combat."]) return true end
  Settings.OpenToCategory(category:GetID())
  return true
end
function ns.OptionsLook() return fullPages and "game settings" or "don window" end

function ns.OpenOptions()
  if ns.OpenGameOptions() then return end -- (16.11.2026) the game's look: the game's settings
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
