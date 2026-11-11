local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- The NPC table. Data\NPCs.lua (tools/open/build_npcs.py) is one long string, a line per NPC:
--   id^name^title^side^roles^level^map:xxyy...[,map:xxyy...]
-- It is read on the first search (ns.NPCs()), not at login, and the string is dropped after that.
-- Role codes: v vendor, r repair, g reagents, f food and drink, a ammunition, s stable master, t flight master,
-- i innkeeper, b banker, h auctioneer, m riding trainer, e pet trainer, w weapon master, x rare,
-- C<class ID in base 36> class trainer, P<letter> profession trainer.
---------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"
local CLASSES = { -- class ID -> token (the trainers in the data), in the order of the list
  { 1, "WARRIOR", "ClassIcon_Warrior" }, { 2, "PALADIN", "ClassIcon_Paladin" }, { 3, "HUNTER", "ClassIcon_Hunter" },
  { 4, "ROGUE", "ClassIcon_Rogue" }, { 5, "PRIEST", "ClassIcon_Priest" }, { 7, "SHAMAN", "ClassIcon_Shaman" },
  { 8, "MAGE", "ClassIcon_Mage" }, { 9, "WARLOCK", "ClassIcon_Warlock" }, { 11, "DRUID", "ClassIcon_Druid" },
}
local PROFS = {
  { "a", "Alchemy", "Trade_Alchemy" }, { "b", "Blacksmithing", "Trade_BlackSmithing" }, { "c", "Cooking", "INV_Misc_Food_15" },
  { "e", "Enchanting", "Trade_Engraving" }, { "g", "Engineering", "Trade_Engineering" },
  { "f", "First Aid", "Spell_Holy_SealOfSacrifice" }, { "i", "Fishing", "Trade_Fishing" },
  { "h", "Herbalism", "Spell_Nature_NatureTouchGrow" }, { "l", "Leatherworking", "INV_Misc_ArmorKit_17" },
  { "m", "Mining", "Trade_Mining" }, { "s", "Skinning", "INV_Misc_Pelt_Wolf_01" }, { "t", "Tailoring", "Trade_Tailoring" },
}
local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"

local function ClassName(token)
  local t = LOCALIZED_CLASS_NAMES_MALE
  local n = type(t) == "table" and ns.Str(t[token])
  return n or (token:sub(1, 1) .. token:sub(2):lower())
end

-- ns.ROLES: every role in the order of the list, { code, label, group, icon, words }. Built once the player's class
-- is known (own class trainer first). words: extra English names /fd understands besides the label.
local roles, byCode
local function BuildRoles()
  roles, byCode = {}, {}
  local function Add(code, label, group, icon, words)
    local r = { code = code, label = label, group = group, icon = ICON .. icon, words = words }
    roles[#roles + 1] = r
    byCode[code] = r
  end
  local _, mine = UnitClass("player")
  mine = ns.Str(mine)
  local order = {}
  for _, c in ipairs(CLASSES) do if c[2] == mine then order[#order + 1] = c end end
  for _, c in ipairs(CLASSES) do if c[2] ~= mine then order[#order + 1] = c end end
  for _, c in ipairs(order) do
    Add("C" .. B36:sub(c[1] + 1, c[1] + 1), L["%s trainer"]:format(ClassName(c[2])), "Trainers", c[3],
      { c[2]:lower() .. " trainer", c[2]:lower() })
  end
  Add("w", L["Weapon master"], "Trainers", "INV_Sword_27", { "weapon master", "weapons" })
  Add("m", L["Riding trainer"], "Trainers", "Ability_Mount_RidingHorse", { "riding trainer", "riding", "mount" })
  Add("e", L["Pet trainer"], "Trainers", "Ability_Hunter_BeastTaming", { "pet trainer" })
  for _, p in ipairs(PROFS) do Add("P" .. p[1], L[p[2]], "Profession trainers", p[3], { p[2]:lower(), p[2]:lower() .. " trainer" }) end
  Add("v", L["All vendors"], "Vendors", "INV_Misc_Bag_10", { "vendor", "vendors", "merchant" })
  Add("r", L["Repair"], "Vendors", "Trade_BlackSmithing", { "repair", "repairs" })
  Add("g", L["Reagents"], "Vendors", "INV_Misc_Rune_06", { "reagents", "reagent" })
  Add("f", L["Food and drink"], "Vendors", "INV_Misc_Food_15", { "food", "drink", "water", "food and drink" })
  Add("a", L["Ammunition"], "Vendors", "INV_Ammo_Arrow_02", { "ammunition", "ammo", "arrows", "bullets" })
  Add("i", L["Innkeeper"], "Services", "INV_Misc_Rune_01", { "innkeeper", "inn" })
  Add("b", L["Bank"], "Services", "INV_Misc_Coin_02", { "bank", "banker" })
  Add("h", L["Auction house"], "Services", "INV_Misc_Coin_01", { "auction house", "auction", "auctioneer", "ah" })
  Add("t", L["Flight master"], "Services", "Ability_Mount_Gryphon_01", { "flight master", "flight", "taxi" })
  Add("s", L["Stable master"], "Services", "Ability_Hunter_BeastCall", { "stable master", "stable" })
  Add("x", L["Rares"], "Rares", "INV_Misc_Head_Dragon_01", { "rare", "rares" })
end

function ns.Roles()
  if not roles then BuildRoles() end
  return roles
end
function ns.Role(code)
  if not roles then BuildRoles() end
  return byCode[code]
end
function ns.ResetRoles() roles, byCode = nil, nil end -- (tests: another class)

-- The role a typed text names: its label in the game's language or one of its English words; nil otherwise.
function ns.RoleByText(text)
  text = tostring(text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  for _, r in ipairs(ns.Roles()) do
    if r.label:lower() == text then return r end
  end
  for _, r in ipairs(ns.Roles()) do
    for _, w in ipairs(r.words) do if w == text then return r end end
  end
  return nil
end

---------------------------------------------------------------------------
-- Reading the data
---------------------------------------------------------------------------
local npcs

local function Parse()
  npcs = {}
  local data = ns.NPC_DATA
  if type(data) ~= "string" then return end
  for line in data:gmatch("[^\n]+") do
    local id, name, title, side, rl, level, spots = line:match("^(%d+)%^([^%^]*)%^([^%^]*)%^(%a)%^([^%^]*)%^([^%^]*)%^(.+)$")
    if id then
      -- roles as " v r C1 Pa ": a plain find of " a " cannot hit the a of Pa
      local padded = " " .. rl:gsub("([CP]?[%l%d])", "%1 ")
      npcs[#npcs + 1] = { id = tonumber(id), name = name, title = title, side = side, roles = padded, first = rl:match("[CP]?[%l%d]"),
        level = level ~= "" and level or nil, spots = spots, low = (name .. "\n" .. title):lower() }
    end
  end
  ns.NPC_DATA = nil -- the table replaces the string
end

function ns.NPCs()
  if not npcs then Parse() end
  return npcs
end

-- (tests) another data string: read at the next search
function ns.SetNPCData(data) ns.NPC_DATA, npcs = data, nil end

function ns.HasRole(npc, code) return npc.roles:find(" " .. code .. " ", 1, true) ~= nil end

-- The places of an NPC as a flat list { mapID, x, y, mapID, x, y, ... } with x and y from 0 to 1; decoded once.
function ns.Places(npc)
  local p = npc.places
  if p then return p end
  p = {}
  for map, list in npc.spots:gmatch("(%d+):(%w+)") do
    map = tonumber(map)
    for i = 1, #list - 3, 4 do
      local x, y = tonumber(list:sub(i, i + 1), 36), tonumber(list:sub(i + 2, i + 3), 36)
      if x and y then
        p[#p + 1] = map
        p[#p + 1] = x / 1000
        p[#p + 1] = y / 1000
      end
    end
  end
  npc.places = p
  return p
end

-- What a row and the tooltip say an NPC is: its roles as words ("Vendor, Repair")
function ns.RoleText(npc)
  local out = {}
  for code in npc.roles:gmatch("%S+") do
    local r = ns.Role(code)
    if r and code ~= "v" then out[#out + 1] = r.label end
  end
  if #out == 0 and ns.HasRole(npc, "v") then out[1] = L["Vendor"] end
  return table.concat(out, ", ")
end
