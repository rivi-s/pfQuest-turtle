local GRID_COLUMNS = 6
local ICON_SIZE = 26
local ICON_PADDING = 6
local PANEL_MARGIN = 8
local MAX_ICONS = 18
local MIN_CONTENT_WIDTH = 120
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local RANK_INFO = {
  ["1"] = { text = "Elite",      r = 1, g = 0.5,  b = 0 },
  ["2"] = { text = "Rare Elite", r = 1, g = 0.42, b = 0.71 },
  ["3"] = { text = "Boss",       r = 1, g = 0,    b = 0 },
  ["4"] = { text = "Rare",       r = 1, g = 1,    b = 0 },
}

local unitDropsCache = {}

-- fixed cutoff for the optional "hide world drops" setting: items/pools
-- shared by more units than this are treated as generic world-drops
local WORLD_DROP_THRESHOLD = 200

local function CountEntries(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function BuildDropsForUnit(unitid)
  local cached = unitDropsCache[unitid]
  if cached then return cached end

  local items = pfDB["items"]["data"]
  local refloot = pfDB["refloot"]["data"]
  local list = {}
  local seen = {}

  for itemid, item in pairs(items) do
    if not item["reference-token"] and item["U"] and item["U"][unitid] and not seen[itemid] then
      seen[itemid] = true
      local sourceCount = CountEntries(item["U"])
      table.insert(list, { item = itemid, chance = item["U"][unitid] or 0, isRef = false, sourceCount = sourceCount })
    elseif not item["reference-token"] and item["R"] and not seen[itemid] then
      for ref, chance in pairs(item["R"]) do
        local refdata = refloot[ref]
        if refdata and refdata["U"] and refdata["U"][unitid] then
          seen[itemid] = true
          local sourceCount = CountEntries(refdata["U"])
          table.insert(list, { item = itemid, chance = chance or 0, isRef = true, sourceCount = sourceCount })
          break
        end
      end
    end
  end

  table.sort(list, function(a, b) return a.chance > b.chance end)
  unitDropsCache[unitid] = list
  return list
end

local questStarterItems = {}
local questStarterIndexBuilt = false

local function BuildQuestStarterIndex()
  if questStarterIndexBuilt then return end
  questStarterIndexBuilt = true

  local quests = pfDB["quests"]["data"]
  if not quests then return end

  for _, quest in pairs(quests) do
    if quest["start"] and quest["start"]["I"] then
      for _, itemid in pairs(quest["start"]["I"]) do
        questStarterItems[itemid] = true
      end
    end
  end
end

local function PassesCategoryFilters(itemid)
  BuildQuestStarterIndex()

  local showEquip = not pfQuest_config or pfQuest_config["lootPanelShowEquip"] ~= "0"
  local showQuestItems = not pfQuest_config or pfQuest_config["lootPanelShowQuestItems"] ~= "0"
  local showQuestStarters = not pfQuest_config or pfQuest_config["lootPanelShowQuestStarters"] ~= "0"
  local showRecipes = not pfQuest_config or pfQuest_config["lootPanelShowRecipes"] ~= "0"
  local showGrey = not pfQuest_config or pfQuest_config["lootPanelShowGrey"] ~= "0"
  local showWhite = not pfQuest_config or pfQuest_config["lootPanelShowWhite"] ~= "0"

  local _, _, quality, _, _, itemType = GetItemInfo(itemid)
  local isEquip = itemType == "Armor" or itemType == "Weapon"

  if isEquip then return showEquip end
  if questStarterItems[itemid] then return showQuestStarters end
  if itemType == "Quest" then return showQuestItems end
  if itemType == "Recipe" then return showRecipes end
  if quality == 0 then return showGrey end
  if quality == 1 then return showWhite end

  return true
end

local function GetVisibleDrops(unitid)
  local drops = BuildDropsForUnit(unitid)
  if not drops or table.getn(drops) == 0 then return nil end

  local showReference = pfQuest_config and pfQuest_config["lootPanelShowReference"] == "1"
  local showUnknownChance = pfQuest_config and pfQuest_config["lootPanelShowUnknownChance"] == "1"
  local hideWorldDrops = pfQuest_config and pfQuest_config["lootPanelHideWorldDrops"] == "1"

  local visible = {}
  for _, drop in ipairs(drops) do
    local passesRef = showReference or not drop.isRef
    local passesChance = showUnknownChance or (drop.chance and drop.chance > 0)
    local passesWorldDrop = not hideWorldDrops or not drop.sourceCount or drop.sourceCount <= WORLD_DROP_THRESHOLD
    if passesRef and passesChance and passesWorldDrop and PassesCategoryFilters(drop.item) then
      table.insert(visible, drop)
    end
  end
  return visible
end

-- This panel is also opened from minimap pins, so it cannot be a child of
-- WorldMapFrame: that frame is hidden whenever the regular map is closed.
local panel = CreateFrame("Frame", "pfQuestLootPanel", UIParent)
-- one strata below TOOLTIP (but above DIALOG, which pfUI's map skin uses
-- heavily) so GameTooltip reliably renders above this panel
panel:SetFrameStrata("FULLSCREEN_DIALOG")
panel:SetFrameLevel(200)
panel:SetClampedToScreen(true)
panel:Hide()

panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

panel:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropColor(0, 0, 0, 0.9)
panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

local closeButton = CreateFrame("Button", nil, panel)
closeButton:SetWidth(14)
closeButton:SetHeight(14)
closeButton:SetPoint("TOPRIGHT", -3, -3)
closeButton:SetFrameLevel(panel:GetFrameLevel() + 10)
closeButton.text = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
closeButton.text:SetPoint("CENTER")
closeButton.text:SetText("x")
closeButton.text:SetTextColor(0.8, 0.3, 0.3)
closeButton:SetScript("OnEnter", function() closeButton.text:SetTextColor(1, 1, 1) end)
closeButton:SetScript("OnLeave", function() closeButton.text:SetTextColor(0.8, 0.3, 0.3) end)
closeButton:SetScript("OnClick", function() pfQuestLoot.Hide() end)

panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_MARGIN, -PANEL_MARGIN)
panel.header:SetJustifyH("LEFT")
panel.header:Hide()

panel.noItems = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
panel.noItems:SetJustifyH("LEFT")
panel.noItems:SetText("No items linked to this NPC")
panel.noItems:Hide()

local function FormatChance(chance)
  if chance <= 0 or chance >= 1 then
    return string.format("%.0f%%", chance)
  end

  local oneDecimal = string.format("%.1f%%", chance)
  if oneDecimal == "0.0%" then
    return string.format("%.2f%%", chance)
  end

  return oneDecimal
end

local buttonPool = {}

local function GetButton(index)
  local button = buttonPool[index]
  if button then return button end

  button = CreateFrame("Button", nil, panel)
  button:SetWidth(ICON_SIZE)
  button:SetHeight(ICON_SIZE)

  button.border = button:CreateTexture(nil, "BACKGROUND")
  button.border:SetPoint("TOPLEFT", -1, 1)
  button.border:SetPoint("BOTTOMRIGHT", 1, -1)
  button.border:SetTexture(1, 1, 1, 1)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints(button)

  button.chanceText = button:CreateFontString(nil, "OVERLAY")
  button.chanceText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  button.chanceText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
  button.chanceText:SetTextColor(1, 1, 0)

  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  button:SetScript("OnEnter", function()
    if not button.itemid then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    local name = GetItemInfo(button.itemid)
    local linkOk = name and pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. button.itemid .. (pfQuestCompat.itemsuffix or ""))

    if not linkOk then
      local localName = pfDB["items"]["enUS"] and pfDB["items"]["enUS"][button.itemid]
      GameTooltip:SetText(name or ((localName and localName ~= "") and localName or ("Item #" .. button.itemid)), 1, 1, 1)
      if not name then
        GameTooltip:AddLine("Item data unavailable", 0.6, 0.6, 0.6)
      end
    end

    if button.chance and button.chance > 0 then
      GameTooltip:AddLine("Drop chance: " .. FormatChance(button.chance), 0.6, 0.9, 1)
    end

    GameTooltip:SetFrameLevel(panel:GetFrameLevel() + 10)
    GameTooltip:Show()
    GameTooltip:SetFrameLevel(panel:GetFrameLevel() + 10)
  end)

  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  buttonPool[index] = button
  return button
end

local function LayoutButton(button, index, topOffset)
  local col = (index - 1) - floor((index - 1) / GRID_COLUMNS) * GRID_COLUMNS
  local row = floor((index - 1) / GRID_COLUMNS)
  button:ClearAllPoints()
  button:SetPoint("TOPLEFT", panel, "TOPLEFT",
    PANEL_MARGIN + col * (ICON_SIZE + ICON_PADDING),
    -topOffset - row * (ICON_SIZE + ICON_PADDING))
  button:SetFrameLevel(panel:GetFrameLevel() + 1)
end

local function RankText(unitData)
  local info = unitData and unitData["rnk"] and RANK_INFO[tostring(unitData["rnk"])]
  if not info then return nil end
  return string.format("Rank: |cff%02x%02x%02x%s|r", info.r * 255, info.g * 255, info.b * 255, info.text)
end

pfQuestLoot = {}

local pinned = false
local pinnedUnitId = nil

function pfQuestLoot.Hide()
  pinned = false
  pinnedUnitId = nil
  panel.openedFromWorldMap = nil
  panel:Hide()
end

local function ApplyItemVisuals(button, itemid)
  local _, _, quality = GetItemInfo(itemid)
  button.icon:SetTexture(GetItemIcon(itemid) or FALLBACK_ICON)

  if quality and ITEM_QUALITY_COLORS[quality] then
    local c = ITEM_QUALITY_COLORS[quality]
    button.border:SetVertexColor(c.r, c.g, c.b, 1)
    return true
  end

  button.border:SetVertexColor(0.4, 0.4, 0.4, 1)
  return false
end

local function PopulateGrid(unitid, topOffset)
  local drops = GetVisibleDrops(unitid)
  local count = drops and min(table.getn(drops), MAX_ICONS) or 0

  for i = 1, count do
    local drop = drops[i]
    local button = GetButton(i)

    button.itemid = drop.item
    button.chance = drop.chance

    if drop.chance and drop.chance > 0 then
      local text = FormatChance(drop.chance)
      button.chanceText:SetText(text)
      button.chanceText:SetFont("Fonts\\FRIZQT__.TTF", string.len(text) >= 5 and 7 or 9, "OUTLINE")
      button.chanceText:Show()
    else
      button.chanceText:Hide()
    end

    if ApplyItemVisuals(button, drop.item) then
      button.pendingQualityItem = nil
    else
      button.pendingQualityItem = drop.item
    end

    LayoutButton(button, i, topOffset)
    button:Show()
  end

  for i = count + 1, table.getn(buttonPool) do
    buttonPool[i]:Hide()
  end

  if count == 0 then
    return false, 0, 0
  end

  local columns = min(count, GRID_COLUMNS)
  local rows = ceil(count / GRID_COLUMNS)
  local width = PANEL_MARGIN * 2 + columns * ICON_SIZE + (columns - 1) * ICON_PADDING
  local gridHeight = rows * ICON_SIZE + (rows - 1) * ICON_PADDING
  return true, width, gridHeight
end

function pfQuestLoot.HasDrops(unitid)
  local drops = unitid and GetVisibleDrops(unitid)
  return drops ~= nil and table.getn(drops) > 0
end

function pfQuestLoot.ShowPinned(nodeFrame)
  local unitid = nodeFrame and nodeFrame.spawnid
  if not unitid then return end

  if pinned and pinnedUnitId == unitid then
    pfQuestLoot.Hide()
    return
  end

  local unitData = pfDB["units"]["data"][unitid]
  if not unitData then return end

  local headerLines = {
    "|cff4dffcc" .. (nodeFrame.spawn or UNKNOWN) .. "|r",
    (pfQuest_Loc["Level"] or "Level") .. ": " .. (nodeFrame.level or UNKNOWN),
    (pfQuest_Loc["Type"] or "Type") .. ": " .. (nodeFrame.spawntype or UNKNOWN),
  }

  local rankText = RankText(unitData)
  if rankText then table.insert(headerLines, rankText) end

  table.insert(headerLines, (pfQuest_Loc["Respawn"] or "Respawn") .. ": " .. (nodeFrame.respawn or UNKNOWN))

  local drops = GetVisibleDrops(unitid)
  local dropCount = drops and min(table.getn(drops), MAX_ICONS) or 0
  local columns = min(dropCount, GRID_COLUMNS)
  local gridContentWidth = columns > 0 and (columns * ICON_SIZE + (columns - 1) * ICON_PADDING) or 0
  local contentWidth = max(gridContentWidth, MIN_CONTENT_WIDTH)

  panel.header:SetWidth(contentWidth)
  panel.header:SetText(table.concat(headerLines, "\n"))
  panel.header:Show()

  local headerHeight = panel.header:GetHeight() + 10
  local ok, _, gridHeight = PopulateGrid(unitid, headerHeight)

  local noItemsHeight = 0
  if ok then
    panel.noItems:Hide()
  else
    panel.noItems:ClearAllPoints()
    panel.noItems:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_MARGIN, -headerHeight)
    panel.noItems:SetWidth(contentWidth)
    panel.noItems:Show()
    noItemsHeight = panel.noItems:GetHeight()
  end

  pinned = true
  pinnedUnitId = unitid
  panel.openedFromWorldMap = nodeFrame:GetParent() == WorldMapButton

  panel:SetWidth(contentWidth + PANEL_MARGIN * 2)
  panel:SetHeight(headerHeight + PANEL_MARGIN + (ok and gridHeight or noItemsHeight))

  panel:ClearAllPoints()
  if panel.openedFromWorldMap then
    panel:SetPoint("TOPLEFT", nodeFrame, "BOTTOMLEFT", 0, -6)
  else
    -- A minimap pin is repositioned as the player moves. Capture its screen
    -- position once so the loot panel does not visibly chase it around.
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", nodeFrame:GetLeft(), nodeFrame:GetBottom() - 6)
  end

  panel:Show()
end

local pendingQualityElapsed = 0
panel:SetScript("OnUpdate", function()
  pendingQualityElapsed = pendingQualityElapsed + (arg1 or 0)
  if pendingQualityElapsed < 0.5 then return end
  pendingQualityElapsed = 0

  for i = 1, table.getn(buttonPool) do
    local button = buttonPool[i]
    if button and button:IsShown() and button.pendingQualityItem then
      if ApplyItemVisuals(button, button.pendingQualityItem) then
        button.pendingQualityItem = nil
      end
    end
  end
end)

local mapWatcher = CreateFrame("Frame")
mapWatcher:RegisterEvent("WORLD_MAP_UPDATE")
mapWatcher:SetScript("OnEvent", function()
  if panel.openedFromWorldMap then pfQuestLoot.Hide() end
end)

if WorldMapFrame then
  WorldMapFrame:HookScript("OnHide", function()
    if panel.openedFromWorldMap then pfQuestLoot.Hide() end
  end)
  WorldMapFrame:HookScript("OnHide", function() unitDropsCache = {} end)
end

local function ExtendPfQuestConfig()
  for _, entry in pairs(pfQuest_defconfig) do
    if entry.config == "lootPanelShowReference" then
      return true
    end
  end

  table.insert(pfQuest_defconfig, {
    text = "|cff33ffccRare Loot Panel|r",
    type = "header"
  })

  table.insert(pfQuest_defconfig, {
    text = "Include pooled loot",
    default = "1",
    type = "checkbox",
    config = "lootPanelShowReference"
  })

  table.insert(pfQuest_defconfig, {
    text = "Include unknown loot",
    default = "0",
    type = "checkbox",
    config = "lootPanelShowUnknownChance"
  })

  table.insert(pfQuest_defconfig, {
    text = "Hide World-Drop Items (200+ sources)",
    default = "0",
    type = "checkbox",
    config = "lootPanelHideWorldDrops"
  })

  table.insert(pfQuest_defconfig, {
    text = "Show Armor/Weapons",
    default = "1",
    type = "checkbox",
    config = "lootPanelShowEquip"
  })

  table.insert(pfQuest_defconfig, {
    text = "Show Quest Items",
    default = "1",
    type = "checkbox",
    config = "lootPanelShowQuestItems"
  })

  table.insert(pfQuest_defconfig, {
    text = "Show Quest Starters",
    default = "1",
    type = "checkbox",
    config = "lootPanelShowQuestStarters"
  })

  table.insert(pfQuest_defconfig, {
    text = "Show Recipes",
    default = "1",
    type = "checkbox",
    config = "lootPanelShowRecipes"
  })

  table.insert(pfQuest_defconfig, {
    text = "Show Grey Items",
    default = "1",
    type = "checkbox",
    config = "lootPanelShowGrey"
  })

  table.insert(pfQuest_defconfig, {
    text = "Show White Items",
    default = "1",
    type = "checkbox",
    config = "lootPanelShowWhite"
  })

  if not pfQuest_config["lootPanelShowReference"] then
    pfQuest_config["lootPanelShowReference"] = "1"
  end

  if not pfQuest_config["lootPanelShowUnknownChance"] then
    pfQuest_config["lootPanelShowUnknownChance"] = "0"
  end

  if not pfQuest_config["lootPanelHideWorldDrops"] then
    pfQuest_config["lootPanelHideWorldDrops"] = "0"
  end

  if not pfQuest_config["lootPanelShowEquip"] then
    pfQuest_config["lootPanelShowEquip"] = "1"
  end

  if not pfQuest_config["lootPanelShowQuestItems"] then
    pfQuest_config["lootPanelShowQuestItems"] = "1"
  end

  if not pfQuest_config["lootPanelShowQuestStarters"] then
    pfQuest_config["lootPanelShowQuestStarters"] = "1"
  end

  if not pfQuest_config["lootPanelShowRecipes"] then
    pfQuest_config["lootPanelShowRecipes"] = "1"
  end

  if not pfQuest_config["lootPanelShowGrey"] then
    pfQuest_config["lootPanelShowGrey"] = "1"
  end

  if not pfQuest_config["lootPanelShowWhite"] then
    pfQuest_config["lootPanelShowWhite"] = "1"
  end

  return true
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", ExtendPfQuestConfig)
