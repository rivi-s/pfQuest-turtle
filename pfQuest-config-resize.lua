-- Standalone resize/zoom support for the pfQuest configuration window.
-- Keep this module last in the TOC so it can be copied to another branch as-is.

local MIN_SCALE = 0.60
local MAX_SCALE = 1.00
local SCALE_KEY = "turtle_config_scale"

local function Clamp(value, minimum, maximum)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function GetDefaultScale()
  return math.min(MAX_SCALE, MIN_SCALE / UIParent:GetEffectiveScale())
end

local function GetMaximumScale()
  local horizontal = (UIParent:GetWidth() - 40) / pfQuestConfig.resizeBaseWidth
  local vertical = (UIParent:GetHeight() - 40) / pfQuestConfig.resizeBaseHeight
  return math.min(MAX_SCALE, horizontal, vertical)
end

local function InstallConfigResize()
  if not pfQuestConfig or pfQuestConfig.resizeInstalled then return false end
  -- Wait for pfQuest-config.lua to finish its multi-column layout rebuild.
  if not pfQuestConfig.GetWidth or pfQuestConfig:GetWidth() <= 400 then return false end

  pfQuestConfig.resizeInstalled = true
  pfQuestConfig.resizeBaseWidth = pfQuestConfig:GetWidth()
  pfQuestConfig.resizeBaseHeight = pfQuestConfig:GetHeight()
  pfQuestConfig.resizeDefaultScale = GetDefaultScale()
  local function ApplyScale(scale)
    local maximum = GetMaximumScale()
    local minimum = math.min(pfQuestConfig.resizeDefaultScale, maximum)
    scale = Clamp(scale, minimum, maximum)
    pfQuestConfig:SetScale(scale)
    pfQuest_config = pfQuest_config or {}
    pfQuest_config[SCALE_KEY] = tostring(scale)
  end

  pfQuestConfig.ApplyResizeScale = ApplyScale

  -- The feature config module can rebuild its column layout after this module
  -- loads. Re-capture that new layout before the resize handler restores size.
  local createEntries = pfQuestConfig.CreateConfigEntries
  if createEntries then
    pfQuestConfig.CreateConfigEntries = function(self, config)
      self.resizeApplying = true
      createEntries(self, config)
      self.resizeBaseWidth = self:GetWidth()
      self.resizeBaseHeight = self:GetHeight()
      self.resizeApplying = nil
    end
  end

  local function ApplySavedScale()
    ApplyScale(tonumber(pfQuest_config and pfQuest_config[SCALE_KEY]) or pfQuestConfig.resizeDefaultScale)
  end

  -- pfQuest-config.lua resets its scale while rebuilding. Applying on show also
  -- restores the user's saved size after any later rebuild.
  local previousOnShow = pfQuestConfig:GetScript("OnShow")
  pfQuestConfig:SetScript("OnShow", function()
    if previousOnShow then previousOnShow() end
    ApplySavedScale()
  end)

  ApplySavedScale()

  local grip = CreateFrame("Button", "pfQuestConfigResizeGrip", pfQuestConfig)
  grip:SetWidth(70)
  grip:SetHeight(28)
  -- Keep this beside Save & Close; its old corner texture is not visible on
  -- some Turtle clients and is easily covered by that button.
  grip:SetPoint("BOTTOMRIGHT", pfQuestConfig, "BOTTOMRIGHT", -180, 10)
  grip:SetFrameLevel(pfQuestConfig:GetFrameLevel() + 10)
  grip:EnableMouse(true)
  pfUI.api.SkinButton(grip)
  grip.label = grip:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  grip.label:SetAllPoints(grip)
  grip.label:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
  grip.label:SetText("Resize")

  grip:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText("Resize pfQuest Config")
    GameTooltip:AddLine("Drag left or right to change the window size. Double-click to reset.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  grip:SetScript("OnMouseDown", function()
    local cursorX = GetCursorPosition() / UIParent:GetEffectiveScale()
    grip.dragStartX = cursorX
    grip.dragStartScale = pfQuestConfig:GetScale()
    grip:SetScript("OnUpdate", function()
      local currentX = GetCursorPosition() / UIParent:GetEffectiveScale()
      -- 300 UI units equals a full 1.0 scale step; this keeps the drag precise.
      ApplyScale(grip.dragStartScale + (currentX - grip.dragStartX) / 300)
    end)
  end)
  grip:SetScript("OnMouseUp", function()
    grip:SetScript("OnUpdate", nil)
    grip.dragStartX = nil
    grip.dragStartScale = nil
  end)
  grip:SetScript("OnDoubleClick", function()
    ApplyScale(pfQuestConfig.resizeDefaultScale)
  end)

  return true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  local elapsed = 0
  loader:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 0.2 and not loader.configRebuilt and pfQuest and pfQuest.RebuildConfigUI then
      pfQuest.RebuildConfigUI()
      loader.configRebuilt = true
    end
    -- The feature config rebuild runs for a few frames after VARIABLES_LOADED.
    -- Wait for it before applying the persisted scale.
    if elapsed >= 1 and (InstallConfigResize() or elapsed > 5) then
      loader:SetScript("OnUpdate", nil)
      loader:UnregisterAllEvents()
    end
  end)
end)
