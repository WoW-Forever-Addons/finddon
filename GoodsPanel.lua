local _, ns = ...
local L = ns.L
local Core = LibStub("DonCore-1.0")
local Kit = Core:Get("Kit", 22) or Core:Get("Kit", 10) or Core:Get("Kit", 1)

---------------------------------------------------------------------------
-- A vendor's goods beside the search window (23.11.2026, Daniel: "bei den npcs die waren anbieten nach einem linksklick
-- rechts daneben ein fenster aufgehen lassen, welche waren sie zu welchem preis anbieten. beschränkte waren
-- dementsprechend kennzeichnen", "alles mit blizzard bild, tooltip von blizzard, ob man ein rezept schon kennt etc",
-- "am besten als einzelnes schmales fenster daneben, klickt man auf einen anderen npc, zeigt er dessen waren, hat der
-- npc keine, schließt das fenster. das fenster selber soll trotzdem ein schließen knopf haben").
-- One narrow window of its own (the Kit's, or Blizzard's blocks with the option blizzLook, as the search window), right
-- of the search window (left when there is no room). Per item: the game's symbol and name in the quality's colour, the
-- price of one purchase, under the name "limited supply", the pieces per purchase and "Already known"; a recipe the
-- character knows and anything it cannot use has a red symbol, as at the vendor. The tooltip is the game's own.
-- Shift-click links the item, Ctrl-click tries it on. Data: ns.GoodsOf, ns.GoodPrice (Data.lua).
---------------------------------------------------------------------------
local PANEL_W, PANEL_GAP, PRICE_W = 330, 2, 92
local LIMITED, KNOWN = "|cffff9a3c", "|cffff3030"
local panels = {} -- [true] Blizzard's look, [false] the Kit's
local P, shown    -- the window in use; { npc, list, marks }

-- What the game's tooltip says about the item for this character: "known" (a recipe already learned), "unusable" (a
-- red line: class, level, skill, profession), false; nil while the game has no tooltip for it yet. Kept until the
-- window shows another vendor (a recipe learned meanwhile shows at the next click).
local scanTip
local state = {}
local function Scan(id)
  local v = state[id]
  if v ~= nil then return v end
  if type(CreateFrame) ~= "function" then return nil end
  if scanTip == nil then
    local ok, t = pcall(CreateFrame, "GameTooltip", "FinddonScanTip", nil, "GameTooltipTemplate")
    scanTip = ok and type(t) == "table" and t or false
  end
  if not scanTip or not scanTip.SetItemByID then return nil end
  if not pcall(scanTip.SetOwner, scanTip, WorldFrame or UIParent, "ANCHOR_NONE") then return nil end
  pcall(scanTip.ClearLines, scanTip)
  if not pcall(scanTip.SetItemByID, scanTip, id) then return nil end
  local n = ns.Num(ns.Call(scanTip.NumLines, scanTip)) or 0
  if n == 0 then return nil end
  local known = ns.Str(rawget(_G, "ITEM_SPELL_KNOWN"))
  local res = false
  for i = 2, n do
    for _, side in ipairs({ "Left", "Right" }) do
      local fs = rawget(_G, "FinddonScanTipText" .. side .. i)
      local text = fs and fs.GetText and ns.Str(ns.Call(fs.GetText, fs))
      if text and text ~= "" and not (fs.IsShown and ns.Call(fs.IsShown, fs) == false) then
        if known and text == known then res = "known" break end
        local ok, r, g, b = pcall(fs.GetTextColor, fs)
        r, g, b = ok and ns.Num(r), ok and ns.Num(g), ok and ns.Num(b)
        if r and g and b and r > 0.9 and g < 0.2 and b < 0.2 then res = "unusable" end
      end
    end
    if res == "known" then break end
  end
  pcall(scanTip.Hide, scanTip)
  state[id] = res
  return res
end
ns.GoodState = Scan -- (tests)

local function Quality(id)
  local ok, _, _, q = pcall(C_Item and C_Item.GetItemInfo or GetItemInfo, id)
  return ok and ns.Num(q) or nil
end

-- Only the rows on screen ask for the parts that need the game (quality, tooltip scan), as the hits do (Window.lua LAZY)
local LAZY = { __index = function(it, k)
  if k ~= "sub" and k ~= "unusable" and k ~= "quality" then return nil end
  local good, list = rawget(it, "good"), rawget(it, "list")
  if not good then return nil end
  if k == "quality" then
    local q = Quality(good.id)
    if q then rawset(it, k, q) end
    return q
  end
  local st = Scan(good.id)
  if k == "unusable" then
    if st == nil then return nil end
    rawset(it, k, st and true or false)
    return st and true or false
  end
  local parts = {}
  if list.limited and list.limited[good] then parts[#parts + 1] = LIMITED .. L["limited supply"] .. "|r" end
  local _, stack = ns.GoodPrice(good, list)
  if stack and stack > 1 then parts[#parts + 1] = "x" .. stack end
  if st == "known" then parts[#parts + 1] = KNOWN .. (ns.Str(rawget(_G, "ITEM_SPELL_KNOWN")) or "Already known") .. "|r" end
  local sub = table.concat(parts, " \194\183 ")
  if st ~= nil then rawset(it, k, sub) end
  return sub
end }

local function Items()
  local items, list, marks = {}, shown.list, shown.marks
  -- (23.11.2026, Daniel with a picture: "unten abgeschnitten") where the price comes from stands in the item's tooltip,
  -- not in the footer
  local note = { list.seen and L["Prices as seen at the vendor."] or L["Prices without reputation discount."], color = Kit.C.quiet }
  for _, good in ipairs(list) do
    local price = ns.GoodPrice(good, list)
    local limited = list.limited and list.limited[good]
    items[#items + 1] = setmetatable({ kind = "trow", key = good.id, itemID = good.id, good = good, list = list,
      title = ns.GoodName(good), cells = { price = price and Kit.Money(price) or "" },
      -- the goods the search asked for stand out
      active = marks and marks[good] or nil,
      tipLines = limited and { { L["limited supply"], color = Kit.C.yellow }, price and note or nil } or price and { note } or nil,
      tipHint = L["Shift-click: link in chat. Ctrl-click: try on."] }, LAZY)
  end
  return items
end

local function Fill(reset)
  if not (P and shown) then return end
  local list = shown.list
  P.tbl:SetItems(Items(), reset)
  local limited = 0
  for _ in pairs(list.limited or {}) do limited = limited + 1 end
  local text = L["%d goods"]:format(#list)
  if limited > 0 then text = text .. " \194\183 " .. L["%d limited"]:format(limited) end
  P:SetStatus(text)
end

local function Click(it, button)
  if not (it and it.itemID) or button == "RightButton" then return end
  if Kit.LinkItem and Kit.LinkItem(it.itemID) then return end
  if type(IsControlKeyDown) == "function" and IsControlKeyDown() and type(DressUpItemLink) == "function" then
    local ok, _, link = pcall(C_Item and C_Item.GetItemInfo or GetItemInfo, it.itemID)
    if ok and type(link) == "string" then pcall(DressUpItemLink, link) end
  end
end

local function Build(ui, blizz)
  local win
  win = ui.Window(blizz and "FinddonGoodsBlizz" or "FinddonGoods", { title = L["Goods"],
    logo = "Interface\\AddOns\\Finddon\\Media\\minimap", footer = true, store = { scaleReset = 1 },
    width = PANEL_W, height = 520, min = { 260, 220 }, max = { 700, 900 },
    onLayout = function(w, bw, bh)
      if not w.tbl then return end
      w.tbl:ClearAllPoints()
      w.tbl:SetPoint("TOPLEFT", w.body, "TOPLEFT", 0, 0)
      w.tbl:Layout(bw, bh)
    end })
  win:Hide()
  win.tbl = ui.Table(win.body, { columns = { { key = "title", title = L["Item"] }, { key = "price", title = L["Price"], width = PRICE_W } },
    onClick = Click, empty = L["This vendor has no goods here."] })
  win:Layout()
  return win
end

local function Panel(ui)
  local blizz = ui ~= Kit
  if panels[blizz] then return panels[blizz] end
  local ok, win = pcall(Build, ui, blizz)
  if not ok then
    -- Blizzard's blocks failed: the Kit builds it (as the search window does)
    if type(win) == "table" and win.Hide then pcall(win.Hide, win) end
    if not blizz then error(win, 0) end
    return Panel(Kit)
  end
  panels[blizz] = win
  return win
end

-- right of the search window, left of it when the screen ends there; as high as the search window
local function Place(W)
  local function N(f, m) return f and f[m] and ns.Num(ns.Call(f[m], f)) or nil end
  local h = N(W, "GetHeight")
  if h and h > 0 then P:SetHeight(h) end
  local right, scale, pw, ps = N(W, "GetRight"), N(W, "GetEffectiveScale"), N(P, "GetWidth"), N(P, "GetEffectiveScale")
  local sw, us = N(UIParent, "GetWidth"), N(UIParent, "GetEffectiveScale")
  local room = not (right and scale and pw and ps and sw and us) or right * scale + (pw + PANEL_GAP) * ps <= sw * us
  P:ClearAllPoints()
  if room then P:SetPoint("TOPLEFT", W, "TOPRIGHT", PANEL_GAP, 0) else P:SetPoint("TOPRIGHT", W, "TOPLEFT", -PANEL_GAP, 0) end
  P.side = room and "right" or "left"
  P:Layout()
end

function ns.HideGoods()
  shown = nil
  if P and P:IsShown() then P:Hide() end
end

-- the goods of the hit's NPC beside the search window W (built with the blocks ui); false and no window when the NPC
-- sells nothing we know
function ns.ShowGoods(result, W, ui)
  local npc = result and result.npc
  local list = npc and not npc.place and ns.GoodsOf(npc.id) or nil
  if not (list and W) then ns.HideGoods() return false end
  local win = Panel(ui or Kit)
  if P and P ~= win then P:Hide() end
  P = win
  local marks
  if result.goods then
    marks = {}
    for _, good in ipairs(result.goods) do marks[good] = true end
  end
  local same = shown and shown.npc == npc
  shown = { npc = npc, list = list, marks = marks }
  if not same then for k in pairs(state) do state[k] = nil end end
  P:SetSubtitle(npc.name)
  Fill(not same)
  Place(W)
  P:Show()
  return true
end

-- the vendor's list was read anew at its window (Learn.lua): the open goods follow
function ns.GoodsChanged(npcID)
  if not (P and shown and P:IsShown() and shown.npc.id == npcID) then return end
  local list = ns.GoodsOf(npcID)
  if not list then ns.HideGoods() return end
  shown.list = list
  Fill()
end

-- the look option changed: the next click builds the goods in the other look
function ns.ResetGoods() ns.HideGoods() end

-- the game sent an item's data (name, quality, tooltip): the open rows once more, not more often than twice a second
local again
ns.On("GET_ITEM_INFO_RECEIVED", function()
  if again or not (P and shown and P:IsShown()) then return end
  again = true
  ns.After(0.5, function()
    again = false
    if P and shown and P:IsShown() then Fill() end
  end)
end)

-- (tests, diag) the window, what it shows, and the two looks' windows
function ns.GoodsPanel() return P, shown, panels end
