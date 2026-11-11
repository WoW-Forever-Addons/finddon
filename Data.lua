local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- The NPC table. Data\NPCs.lua (tools/open/build_npcs.py) is one long string, a line per NPC:
--   id^name^title^side^roles^level^map:xxyy...[,map:xxyy...]^display   (display: the model for the NPC's picture, may be empty)
-- It is read on the first search (ns.NPCs()), not at login, and the string is dropped after that.
-- Role codes: v vendor, r repair, g reagents, f food and drink, a ammunition, s stable master, t flight master,
-- k cooking fire, l mailbox, n anvil, j forge (places: one line per zone and kind with all its spots), i innkeeper, b banker, h auctioneer, m riding trainer, e pet trainer, w weapon master, x rare,
-- C<class ID in base 36> class trainer, P<letter> profession trainer, q quest NPC, o other NPC (to talk to, no service).
-- G<letter> is no role in the data: a group of goods (Data\Goods.lua), the vendors that sell something of it.
---------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"
-- (11.11.2026, Daniel: "Könnte man an den Zeichen was ändern?", chosen: the game's own symbols) the symbols of the
-- minimap search for the services, every player knows them; /fd icons shows all of them in a row
local TRACK = "Interface\\Minimap\\Tracking\\"
-- places: the name in the data -> the text key (the kind of a cooking fire, Daniel 11.11.2026: "Art des Feuers")
local PLACE_NAMES = { ["Cooking Fire"] = "Cooking fire", Campfire = "Campfire", Fireplace = "Fireplace", Brazier = "Brazier",
  Stove = "Stove", Cauldron = "Cauldron", Mailbox = "Mailbox", Anvil = "Anvil", Forge = "Forge" }
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
-- (11.11.2026, Daniel: "nach Waren suchen ... Getränke, Obst, Fleisch, Handwerkswaren", chosen: search box and groups)
-- the groups of goods: letter in Data\Goods.lua, label, symbol, words /fd understands. Food by what a hunter's pet eats.
local GOODS = {
  { "d", "Drinks", "INV_Drink_07", { "drinks", "beverages" } },
  { "m", "Meat", "INV_Misc_Food_16", { "meat" } },
  { "s", "Fish", "INV_Misc_Fish_02", { "fish" } },
  { "u", "Fruit", "INV_Misc_Food_19", { "fruit", "fruits" } },
  { "b", "Bread", "INV_Misc_Food_11", { "bread" } },
  { "c", "Cheese", "INV_Misc_Food_37", { "cheese" } },
  { "p", "Mushrooms", "INV_Mushroom_11", { "mushrooms", "mushroom", "fungus" } },
  { "t", "Trade goods", "INV_Fabric_Linen_03", { "trade goods", "trade supplies", "crafting" } },
  { "z", "Recipes", "INV_Scroll_03", { "recipes", "recipe", "patterns", "plans" } },
  { "y", "Bags", "INV_Misc_Bag_08", { "bags", "bag", "quiver" } },
}
local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
ns.OBJECT_BASE = 9000000

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
    local r = { code = code, label = label, group = group, icon = icon:find("\\", 1, true) and icon or ICON .. icon, words = words }
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
    if c[2] == mine then roles[#roles].class = c[2] end -- the own class: its colour in the list
  end
  Add("w", L["Weapon master"], "Trainers", "INV_Sword_27", { "weapon master", "weapons" })
  Add("m", L["Riding trainer"], "Trainers", "Ability_Mount_RidingHorse", { "riding trainer", "riding", "mount" })
  Add("e", L["Pet trainer"], "Trainers", "Ability_Hunter_BeastTaming", { "pet trainer" })
  for _, p in ipairs(PROFS) do Add("P" .. p[1], L[p[2]], "Profession trainers", p[3], { p[2]:lower(), p[2]:lower() .. " trainer" }) end
  Add("v", L["All vendors"], "Vendors", "INV_Misc_Bag_10", { "vendor", "vendors", "merchant" })
  Add("r", L["Repair"], "Vendors", TRACK .. "Repair", { "repair", "repairs" })
  Add("g", L["Reagents"], "Vendors", TRACK .. "Reagents", { "reagents", "reagent" })
  Add("f", L["Food and drink"], "Vendors", TRACK .. "Food", { "food", "drink", "water", "food and drink" })
  Add("a", L["Ammunition"], "Vendors", TRACK .. "Ammunition", { "ammunition", "ammo", "arrows", "bullets" })
  for _, g in ipairs(GOODS) do
    Add("G" .. g[1], L[g[2]], "Goods", g[3], g[4])
    roles[#roles].goods = g[1]
  end
  Add("i", L["Innkeeper"], "Services", TRACK .. "Innkeeper", { "innkeeper", "inn" })
  Add("b", L["Bank"], "Services", TRACK .. "Banker", { "bank", "banker" })
  Add("h", L["Auction house"], "Services", TRACK .. "Auctioneer", { "auction house", "auction", "auctioneer", "ah" })
  Add("t", L["Flight master"], "Services", TRACK .. "FlightMaster", { "flight master", "flight", "taxi" })
  Add("s", L["Stable master"], "Services", TRACK .. "StableMaster", { "stable master", "stable" })
  -- (11.11.2026, Daniel: "plätze, an denen man kochen kann. da suche ich immer nach") places, not NPCs; the same day,
  -- chosen from the proposals: mailbox, anvil and forge on the same way, a group of their own
  Add("l", L["Mailbox"], "Places", TRACK .. "Mailbox", { "mailbox", "mail", "post" })
  Add("k", L["Cooking fire"], "Places", "Spell_Fire_Fire", { "cooking fire", "fire", "campfire", "cook", "stove" })
  Add("n", L["Anvil"], "Places", "INV_Hammer_20", { "anvil" })
  Add("j", L["Forge"], "Places", "Spell_Fire_FlameBlades", { "forge", "smelting", "smelt" })
  -- (11.11.2026, Daniel: "Wieso nehmen wir da nicht alle npcs auf? ... Manchmal sucht man ja auch quest npcs") every NPC
  -- with a function is in the data: quest NPCs and the rest one can talk to, found by name or listed here
  Add("q", L["Quest NPCs"], "NPCs", "Interface\\GossipFrame\\AvailableQuestIcon", { "quest", "quests", "quest npc", "quest npcs", "quest giver" })
  Add("o", L["Other NPCs"], "NPCs", "Interface\\GossipFrame\\GossipGossipIcon", { "other", "other npcs", "npc", "npcs" })
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
local npcs, npcById

local function Parse()
  npcs, npcById = {}, nil
  local data = ns.NPC_DATA
  if type(data) ~= "string" then return end
  for line in data:gmatch("[^\n]+") do
    local id, name, title, side, rl, level, spots, display = line:match("^(%d+)%^([^%^]*)%^([^%^]*)%^(%a)%^([^%^]*)%^([^%^]*)%^([^%^]+)%^?(%d*)$")
    if id then
      -- roles as " v r C1 Pa ": a plain find of " a " cannot hit the a of Pa
      local padded = " " .. rl:gsub("([CP]?[%l%d])", "%1 ")
      id = tonumber(id)
      -- ids from OBJECT_BASE on are places (the cooking fires, mailboxes, anvils or forges of one zone): the name in the
      -- game's language (a fire by its kind: campfire, stove ...), one pin
      local place = id >= ns.OBJECT_BASE
      if place then name = L[PLACE_NAMES[name] or (rl == "k" and "Cooking fire") or name] end
      npcs[#npcs + 1] = { id = id, place = place or nil, name = name, title = title, side = side, roles = padded, first = rl:match("[CP]?[%l%d]"),
        level = level ~= "" and level or nil, spots = spots, display = tonumber(display), low = (name .. "\n" .. title):lower() }
    end
  end
  ns.NPC_DATA = nil -- the table replaces the string
end

function ns.NPCs()
  if not npcs then Parse() end
  return npcs
end

-- the NPC with this id, nil when the data does not know it
function ns.NPCByID(id)
  if not npcById then
    npcById = {}
    for _, n in ipairs(ns.NPCs()) do npcById[n.id] = n end
  end
  return npcById[id]
end

-- (tests) another data string: read at the next search
function ns.SetNPCData(data) ns.NPC_DATA, npcs, npcById = data, nil, nil end

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

---------------------------------------------------------------------------
-- Goods (11.11.2026): what the vendors sell. Data\Goods.lua is one long string, a line per item:
--   item^name^group^vendors^vendors with limited supply   (vendors: NPC ids, four base 36 digits each)
-- Read at the first search that asks for goods; the vendor lists stay strings and are walked when an item matches.
-- The names in the data are English. In another language the game's own names are asked for bit by bit once the goods
-- are in use (GetItemInfo; a name the game does not give yet stays English) and searched as well.
---------------------------------------------------------------------------
local goods, goodById
local NAMES_BATCH, NAMES_STEP, NAMES_AGAIN = 25, 0.4, 5
local MIN_GOODS_TEXT = 2 -- letters before the search box looks into the goods

local function LocalName(it)
  if it.loc then return it.loc end
  local n = ns.Str(ns.Call(C_Item and C_Item.GetItemInfo or GetItemInfo, it.id))
  if n and n ~= it.name then it.loc, it.locLow = n, n:lower() end
  return n
end

local namesRunning
local function LoadNames()
  if namesRunning then return end
  local locale = ns.Str(ns.Call(GetLocale)) or "enUS"
  if locale == "enUS" or locale == "enGB" then return end
  namesRunning = true
  local i, round, got = 0, 1, false
  local function Step()
    if not goods then namesRunning = false return end
    for _ = 1, NAMES_BATCH do
      i = i + 1
      local it = goods[i]
      if not it then break end
      if not it.loc and LocalName(it) then got = true end
    end
    if i < #goods then
      ns.After(NAMES_STEP, Step)
    elseif round == 1 then -- the first round asked the server, the second collects the answers
      round, i = 2, 0
      ns.After(NAMES_AGAIN, Step)
    else
      namesRunning = false
      if got and ns.RefreshWindow then ns.RefreshWindow() end
    end
  end
  Step()
end

local function ParseGoods()
  goods, goodById = {}, {}
  local data = ns.GOODS_DATA
  if type(data) == "string" then
    for line in data:gmatch("[^\n]+") do
      local id, name, group, free, limited = line:match("^(%d+)%^([^%^]+)%^(%l?)%^(%w*)%^(%w*)$")
      if id then
        goods[#goods + 1] = { id = tonumber(id), name = name, low = name:lower(), group = group ~= "" and group or nil,
          free = free, limited = limited }
        goodById[goods[#goods].id] = goods[#goods]
      end
    end
    ns.GOODS_DATA = nil
  end
  table.sort(goods, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.id < b.id end)
  LoadNames()
end

function ns.Goods()
  if not goods then ParseGoods() end
  return goods
end

-- (tests) another goods string: read at the next search
function ns.SetGoodsData(data) ns.GOODS_DATA, goods, goodById = data, nil, nil end

-- whether the shipped data knows the item
function ns.KnownGood(id)
  ns.Goods()
  local it = goodById[id]
  return it ~= nil and not it.learned
end

-- an item of a vendor's list read in the game (Learn.lua): the shipped one, else one made from the name seen there
local function LearnedGood(id, rec)
  local it = goodById[id]
  if it then return it end
  local name = type(rec.names) == "table" and ns.Str(rec.names[id]) or ns.Str(ns.Call(C_Item and C_Item.GetItemInfo or GetItemInfo, id))
  if not name then return nil end
  it = { id = id, name = name, low = name:lower(), free = "", limited = "", learned = true }
  goodById[id] = it
  return it
end

-- an item's name in the game's language when the game has it, else the English one
function ns.GoodName(it) return it.loc or LocalName(it) or it.name end

-- The vendors of the goods asked for: group (a letter, nil = any) and text (lower case, "" = any; raw = as typed, for
-- names in a language string.lower does not know). -> { [npc id] = { item, item, ... } } in the order of the names,
-- a limited item also in [item] = true of the list's .limited. nil when nothing is asked.
-- A vendor whose window the player has seen (FinddonDB.goods, Learn.lua) counts with that list, not the shipped one.
function ns.Sellers(group, text, raw)
  text = text or ""
  if not group and #text < MIN_GOODS_TEXT then return nil end
  local out = {}
  local learned = ns.db and type(ns.db.goods) == "table" and ns.db.goods or nil
  local function Match(it)
    return (not group or it.group == group)
      and (text == "" or it.low:find(text, 1, true) or (it.locLow and it.locLow:find(text, 1, true))
        or (raw and it.loc and it.loc:find(raw, 1, true))) and true or false
  end
  local function Take(it, list, limited)
    for i = 1, #list - 3, 4 do
      local id = tonumber(list:sub(i, i + 3), 36)
      if id and not (learned and learned[id]) then
        local t = out[id]
        if not t then t = {} out[id] = t end
        t[#t + 1] = it
        if limited then
          t.limited = t.limited or {}
          t.limited[it] = true
        end
      end
    end
  end
  for _, it in ipairs(ns.Goods()) do
    if Match(it) then
      Take(it, it.free, false)
      Take(it, it.limited, true)
    end
  end
  if learned then
    for npc, rec in pairs(learned) do
      if type(rec) == "table" and type(rec.items) == "table" then
        local list
        for _, id in ipairs(rec.items) do
          local it = LearnedGood(id, rec)
          if it and Match(it) then
            list = list or {}
            list[#list + 1] = it
            if type(rec.limited) == "table" and rec.limited[id] then
              list.limited = list.limited or {}
              list.limited[it] = true
            end
          end
        end
        if list then
          table.sort(list, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.id < b.id end)
          out[npc] = list
        end
      end
    end
  end
  return out
end

-- What a hit's row says it sells: the first item and how many more ("Coarse Thread +3")
function ns.GoodsText(list)
  if not (list and list[1]) then return "" end
  local s = ns.GoodName(list[1])
  if list.limited and list.limited[list[1]] then s = s .. " (" .. L["limited supply"] .. ")" end
  if #list > 1 then s = s .. " " .. L["+%d more"]:format(#list - 1) end
  return s
end

-- The other roles of an NPC as symbols for its row (a vendor who also repairs): every role but the one shown as the
-- row's symbol; "all vendors" only when it is the NPC's only other role. At most four.
function ns.OtherRoles(npc, shown)
  local out, vendor = {}, nil
  for code in npc.roles:gmatch("%S+") do
    local r = ns.Role(code)
    if r and code ~= shown then
      if code == "v" then vendor = r elseif #out < 4 then out[#out + 1] = r end
    end
  end
  if vendor and #out == 0 and shown and not ("rgfa"):find(shown, 1, true) then out[1] = vendor end
  return out
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
