local _, ns = ...

---------------------------------------------------------------------------
-- NPC pictures (Daniel 11.11.2026: "Kriegen wir für die NPCs noch Bilder hin?", chosen: small picture per row and a
-- large preview). The game draws the NPC's 3D model: by its model number from the data (npc.display, CMaNGOS
-- ModelId), else by the creature ID (Forever's new NPCs: only when the client knows the creature already).
-- A model frame covers what lies under it only once its model is loaded (OnModelLoaded), so a row keeps its role
-- symbol while the game has no model. Option "pictures" switches all of it off.
---------------------------------------------------------------------------
local START, TURN = 0.35, 0.6 -- the preview's first facing and its turn in radians a second (a round in about 10 s)
local function Loaded(self)
  self.bg:Show()
  if self.portrait then
    pcall(self.SetPortraitZoom, self, 1) -- the head fills the small square
  else
    pcall(self.SetPortraitZoom, self, 0)
    self._face = START
    pcall(self.SetFacing, self, START)
  end
end

-- (11.11.2026, chosen from the proposals: "Langsam drehen") the preview's model turns while it is shown
local function Spin(self, elapsed)
  if not (self._want and self._face) then return end
  self._face = (self._face + (tonumber(elapsed) or 0) * TURN) % (2 * math.pi)
  pcall(self.SetFacing, self, self._face)
end

-- portrait = true: the head only (rows); false: the whole NPC (preview). spin = true: the model turns slowly.
function ns.NewModel(parent, portrait, spin)
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, parent)
  if not ok or not m then return nil end
  m.portrait = portrait and true or false
  m.bg = m:CreateTexture(nil, "BACKGROUND")
  m.bg:SetAllPoints()
  m.bg:SetColorTexture(0.05, 0.06, 0.09, 1)
  m.bg:Hide()
  m:SetScript("OnModelLoaded", Loaded)
  if spin then m:SetScript("OnUpdate", Spin) end
  if m.EnableMouse then m:EnableMouse(false) end -- clicks and tooltips stay with the row
  m:Hide()
  return m
end

-- Shows npc's model in m (nil npc or pictures off: hides it). Returns whether a model was asked for.
function ns.ShowModel(m, npc)
  if not m then return false end
  local want = npc and ns.db and ns.db.pictures and (npc.display or -npc.id) or nil
  if want == m._want then return want ~= nil end
  m._want = want
  m._face = nil
  m.bg:Hide()
  pcall(m.ClearModel, m)
  if not want then
    m:Hide()
    return false
  end
  m:Show()
  if npc.display then pcall(m.SetDisplayInfo, m, npc.display) else pcall(m.SetCreature, m, npc.id) end
  return true
end
