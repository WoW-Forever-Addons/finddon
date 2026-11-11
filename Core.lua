local addonName, ns = ...
local L = ns.L
ns.Style = LibStub("DonCore-1.0"):Get("Style", 3) -- shared kit from DonCore (Libs\DonCore\Style.lua)
LibStub("DonCore-1.0"):Get("Settings", 1):Attach(addonName, ns) -- options from DonCore (Libs\DonCore\Settings.lua)

---------------------------------------------------------------------------
-- Finddon: NPC search for WoW Forever (11.11.2026, docs/AUFTRAG_FINDDON_2026-11-11.md). Find the nearest trainer,
-- vendor, repair, flight master ... by role, name or title; a click sets DonMap's arrow and a pin on both maps.
-- Own frames only: no hooksecurefunc, no HookScript, no Blizzard frame scripts. The arrow and the pins are DonMap's.
---------------------------------------------------------------------------
ns.defaults = {
  win = {},            -- window place and size (Kit.Window store)
  closed = {},         -- folded groups of the role list ([group] = true)
  closedHits = {},     -- folded parts of the hit list ([1 this zone / 2 neighbouring zones / 3 further away] = true)
  favs = {},           -- favourite roles ([role code] = true), a group of their own at the top of the list
  role = "",           -- the role chosen last ("" = none: search by text only)
  minimapButton = true,
  minimapAngle = 255,  -- between the other Don buttons (Dropdon 225)
  otherSide = false,   -- also list NPCs of the other faction
  clearOnArrival = true, -- drop arrow and pin a moment after you arrive
  closeOnPick = false, -- close the window when a result is clicked
  pictures = true,     -- the NPC's 3D model in the rows and as a large preview (Picture.lua)
}
ns.SCHEMA = 1
ns.WORDMARK = "|cff3fa9f5Find|rdon"

---------------------------------------------------------------------------
-- Error guard: handlers, timers and UI callbacks run protected.
---------------------------------------------------------------------------
local MAX_ERRORS, MAX_MSG = 10, 160
local errors, warned = {}, false

local function Shorten(msg)
  msg = tostring(msg or "?"):gsub("\\", "/")
  msg = msg:gsub("[^%s:]*/([%w_]+%.[lx][um][al])", "%1")
  if #msg > MAX_MSG then msg = msg:sub(1, MAX_MSG) .. "..." end
  return msg
end

local function Record(context, err)
  if type(err) ~= "string" then err = "(unreadable error)" end
  local ok, msg = pcall(Shorten, err)
  if not ok then msg = "(unreadable error)" end
  for _, e in ipairs(errors) do
    if e.msg == msg and e.context == context then e.count = e.count + 1 return end
  end
  if #errors < MAX_ERRORS then errors[#errors + 1] = { context = context, msg = msg, count = 1 } end
  if not warned then
    warned = true
    print(ns.WORDMARK .. ": " .. L["an error occurred, /fd diag for details"])
  end
end

function ns.Errors() return errors end

function ns.SafeCall(context, fn, ...)
  local args, n = { ... }, select("#", ...)
  local ok, a, b, c = xpcall(function() return fn(unpack(args, 1, n)) end, function(err)
    pcall(Record, context, err)
    return err
  end)
  if ok then return a, b, c end
end

function ns.Guard(context, fn)
  return function(...) return ns.SafeCall(context, fn, ...) end
end

function ns.After(delay, fn)
  if C_Timer and C_Timer.After then C_Timer.After(delay, ns.Guard("timer", fn)) end
end

---------------------------------------------------------------------------
-- Events on our own frame. Several modules may listen to one event.
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local listeners, initCallbacks = {}, {}

function ns.On(event, fn)
  if not listeners[event] then
    listeners[event] = {}
    local ok = pcall(frame.RegisterEvent, frame, event) -- unknown events throw
    if not ok then listeners[event] = nil return false end
  end
  table.insert(listeners[event], fn)
  return true
end

function ns.OnInit(fn) table.insert(initCallbacks, fn) end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name ~= addonName then return end
    FinddonDB = type(FinddonDB) == "table" and FinddonDB or {}
    for k, v in pairs(ns.defaults) do
      if type(FinddonDB[k]) ~= type(v) then FinddonDB[k] = type(v) == "table" and {} or v end
    end
    FinddonDB.schema = ns.SCHEMA
    ns.db = FinddonDB
    for _, fn in ipairs(initCallbacks) do ns.SafeCall("init", fn) end
    return
  end
  if not ns.db then return end
  local list = listeners[event]
  if list then
    for i = 1, #list do ns.SafeCall(event, list[i], event, ...) end
  end
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function ns.Print(msg) print(ns.WORDMARK .. ": " .. tostring(msg)) end

-- Secret values (Midnight rules) never reach comparisons or table keys in our code.
function ns.Usable(v)
  if type(v) == "nil" then return false end
  if canaccessvalue then
    local ok, r = pcall(canaccessvalue, v)
    if ok then return r and true or false end
    return false
  end
  if issecretvalue then
    local ok, r = pcall(issecretvalue, v)
    if ok then return not r end
    return false
  end
  return true
end

function ns.Num(v)
  if type(v) == "number" and ns.Usable(v) then return v end
  return nil
end

function ns.Str(v)
  if type(v) == "string" and ns.Usable(v) and v ~= "" then return v end
  return nil
end

function ns.Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok then return v end
  return nil
end

-- DonMap's API when it is new enough for the arrow (version 2) and the pins (version 1)
function ns.Map()
  local api = DonMapAPI
  if type(api) == "table" and (tonumber(api.version) or 0) >= 2 and type(api.SetArrowTarget) == "function" then return api end
  return nil
end

function Finddon_OnAddonCompartmentClick()
  if ns.ToggleWindow then ns.ToggleWindow() end
end

---------------------------------------------------------------------------
-- Slash commands: /fd opens the window, /fd <text> searches (a role's name picks the role), /fd go <text> sets the
-- arrow to the nearest hit at once, /fd clear drops arrow and pin.
---------------------------------------------------------------------------
SLASH_FINDDON1 = "/fd"
SLASH_FINDDON2 = "/finddon"
ns.COMMANDS = {
  { "/fd", "show or hide the window" },
  { "/fd <text>", "search by role, name or title, e.g. /fd repair" },
  { "/fd go <text>", "arrow to the nearest hit, e.g. /fd go innkeeper" },
  { "/fd map <text>", "arrow to the nearest hit and the world map opened there" },
  { "/fd clear", "drop the arrow and the pin" },
  { "/fd options", "open the options" },
  { "/fd button", "show or hide the minimap button" },
  { "/fd help", "this list" },
}

function ns.PrintHelp()
  ns.Print(L["Commands:"])
  for _, c in ipairs(ns.COMMANDS) do print("  |cffebebeb" .. c[1] .. "|r  |cff9ea3ad" .. L[c[2]] .. "|r") end
end

-- /fd icons: every role with its symbol in the chat, to check the symbols' paths in the client (a path the client
-- does not know shows an empty or green square)
local function Icons()
  ns.Print("icons")
  for _, r in ipairs(ns.Roles()) do
    print(("  |T%s:18:18|t  %s  |cff9ea3ad%s|r"):format(r.icon, r.label, r.icon:gsub("|", "||")))
  end
end

local function Diag()
  ns.Print(("NPCs %s, DonMap %s, target %s"):format(tostring(ns.NPC_COUNT or "?"),
    tostring(type(DonMapAPI) == "table" and DonMapAPI.version or "no"), tostring(ns.Target and ns.Target() and ns.Target().name or "none")))
  for _, e in ipairs(errors) do print(("  %dx [%s] %s"):format(e.count, e.context, e.msg)) end
  if #errors == 0 then print("  " .. L["No errors."]) end
end

function ns.Slash(msg)
  local raw = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local low = raw:lower()
  if low == "" or low == "show" or low == "toggle" then
    if ns.ToggleWindow then ns.ToggleWindow() end
  elseif low == "options" or low == "optionen" or low == "config" then
    if ns.OpenOptions then ns.OpenOptions() end
  elseif low == "button" or low == "minimap" then
    ns.db.minimapButton = not ns.db.minimapButton
    if ns.RefreshMinimapButton then ns.RefreshMinimapButton() end
  elseif low == "clear" or low == "stop" then
    ns.ClearTarget()
    ns.Print(L["Arrow and pin dropped."])
  elseif low == "diag" then
    Diag()
  elseif low == "icons" then
    Icons()
  elseif low == "help" or low == "?" or low == "hilfe" then
    ns.PrintHelp()
  elseif low:match("^go%s+%S") then
    ns.GoNearest(raw:gsub("^%S+%s+", ""))
  elseif low:match("^map%s+%S") then
    ns.GoNearest(raw:gsub("^%S+%s+", ""), true)
  else
    ns.ShowSearch(raw)
  end
end

SlashCmdList["FINDDON"] = function(msg) ns.SafeCall("slash", ns.Slash, msg) end
