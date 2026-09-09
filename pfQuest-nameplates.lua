local questObjectives = {}
local nameplateFrames = {}
local iconFrames = {}
local unusedIconFrames = {}
local frameCount = 0

local ICON_SIZE = 16
local SWORD_ICON = "Interface\\AddOns\\pfQuest-turtle\\img\\slay"
local BAG_ICON = "Interface\\AddOns\\pfQuest-turtle\\img\\loot"
local NAMEPLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border"
local NAME_REGION_INDEX = 3

local function ScanQuestObjectives()
    questObjectives = {}

    if not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"] then
        return
    end

    if not pfDB["quests"]["enUS"] or not pfDatabase then
        return
    end

    local activeQuests = {}
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle, _, _, isHeader, _, complete = pfQuestCompat.GetQuestLogTitle(qid)
        if questTitle and not isHeader and complete ~= 1 then
            local questIds = pfDatabase:GetQuestIDs(qid)
            local questId = questIds and tonumber(questIds[1])
            if questId then
                activeQuests[questId] = {}
            end
            local numObjectives = GetNumQuestLeaderBoards(qid)

            for i = 1, numObjectives do
                local text, objType, finished = GetQuestLogLeaderBoard(i, qid)
                if text and finished ~= true and finished ~= 1 then
                    local _, _, objName, current, total = string.find(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                    if objName and questId then
                        objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")
                        table.insert(activeQuests[questId], {
                            objective = objName,
                            current = tonumber(current),
                            total = tonumber(total)
                        })
                    end
                end
            end
        end
    end

    -- Only inspect active quest IDs. The former title-based full database scan
    -- ran thousands of records for every QUEST_LOG_UPDATE and also mixed up
    -- unrelated stages that share a title.
    for questId, activeObjectives in pairs(activeQuests) do
            local questData = pfDB["quests"]["data"][questId]
            if questData and questData["obj"] then
                if questData["obj"]["U"] then
                    for _, unitId in pairs(questData["obj"]["U"]) do
                        if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                            local targetName = pfDB["units"]["enUS"][unitId]

                            for _, activeObj in ipairs(activeObjectives) do
                                if type(activeObj) == "table" and type(activeObj.objective) == "string" then
                                    local objNameBase = string.gsub(activeObj.objective, " slain$", "")
                                    objNameBase = string.gsub(objNameBase, " killed$", "")
                                    if (objNameBase == targetName or string.find(activeObj.objective, targetName, 1, true)) and
                                       (activeObj.current or 0) < (activeObj.total or 0) then
                                        questObjectives[targetName] = SWORD_ICON
                                    end
                                end
                            end
                        end
                    end
                end

                if questData["obj"]["I"] then
                    for _, itemId in pairs(questData["obj"]["I"]) do
                        local itemName = nil
                        if pfDB["items"] and pfDB["items"]["enUS"] and pfDB["items"]["enUS"][itemId] then
                            itemName = pfDB["items"]["enUS"][itemId]
                        end

                        if pfDB["items"] and pfDB["items"]["data"] and pfDB["items"]["data"][itemId] then
                            local itemData = pfDB["items"]["data"][itemId]

                            if itemData["U"] then
                                for unitId, dropRate in pairs(itemData["U"]) do
                                    if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                                        local npcName = pfDB["units"]["enUS"][unitId]

                                        for _, activeObj in ipairs(activeObjectives) do
                                            if type(activeObj) == "table" and type(activeObj.objective) == "string" and
                                               itemName and string.find(activeObj.objective, itemName, 1, true) then
                                                if (activeObj.current or 0) < (activeObj.total or 0) then
                                                    questObjectives[npcName] = BAG_ICON
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
	            end
end
end

local function IsNameplate(frame)
    if not frame then return false end

    if frame.nameplate or frame.UnitFrame or frame.extended or frame.aloftData or frame.kui then
        return true
    end

    if frame:GetObjectType() ~= "Button" then return false end

    local borderRegion = frame:GetRegions()
    if borderRegion and borderRegion.GetObjectType and borderRegion:GetObjectType() == "Texture" then
        local texture = borderRegion:GetTexture()
        if texture == NAMEPLATE_BORDER then
            return true
        end

        if texture == "" or texture == nil then
            local nameRegion = ({ frame:GetRegions() })[NAME_REGION_INDEX]
            if nameRegion and nameRegion.GetObjectType and nameRegion:GetObjectType() == "FontString" then
                return true
            end
        end
    end

    return false
end

local cachedScale, cachedX, cachedY = 1, -20, -8

local function UpdateCachedSettings()
    cachedScale = (pfQuest_config and tonumber(pfQuest_config["nameplateScale"])) or 1
    cachedX = (pfQuest_config and tonumber(pfQuest_config["nameplateX"])) or -25
    cachedY = (pfQuest_config and tonumber(pfQuest_config["nameplateY"])) or -5
end

local function GetIconFrame(nameplateFrame)
    if iconFrames[nameplateFrame] then
        return iconFrames[nameplateFrame]
    end

    if frameCount >= 300 then
        return nil
    end

    local frame = tremove(unusedIconFrames)

    if not frame then
        frame = CreateFrame("Frame")
        frame.Icon = frame:CreateTexture(nil, "ARTWORK")
        frame.Icon:SetAllPoints(frame)
        frameCount = frameCount + 1
    end

    frame:SetParent(nameplateFrame)
    -- Quest decorations belong below ordinary windows and dropdown menus.
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(nameplateFrame:GetFrameLevel() + 5)
    frame:SetWidth(ICON_SIZE * cachedScale)
    frame:SetHeight(ICON_SIZE * cachedScale)
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", cachedX, cachedY)
    frame:EnableMouse(false)

    iconFrames[nameplateFrame] = frame
    return frame
end

local function RemoveIconFrame(nameplateFrame)
    local frame = iconFrames[nameplateFrame]
    if not frame then
        return
    end

    frame.Icon:SetTexture(nil)
    frame:Hide()
    frame.lastIcon = nil
    tinsert(unusedIconFrames, frame)
    iconFrames[nameplateFrame] = nil
end

local function OnNameplateShow(nameplateFrame)
    if not pfQuest_config or pfQuest_config["nameplatesEnabled"] ~= "1" then
        return
    end

    if WorldMapFrame and WorldMapFrame:IsShown() then
        local iconFrame = iconFrames[nameplateFrame]
        if iconFrame then iconFrame:Hide() end
        return
    end

    local nameText = nameplateFrames[nameplateFrame]
    if not nameText then return end

    local unitName = nameText:GetText()
    if not unitName then return end

    local icon = questObjectives[unitName]

    if icon then
        local frame = GetIconFrame(nameplateFrame)
        if frame then
            if frame.lastIcon ~= icon then
                frame.Icon:SetTexture(icon)
                frame.lastIcon = icon
            end
            frame:Show()
        end
    else
        RemoveIconFrame(nameplateFrame)
    end
end

local function OnNameplateHide(nameplateFrame)
    RemoveIconFrame(nameplateFrame)
end

local function ScanWorldFrameChildren(frames)
    local numFrames = table.getn(frames)

    for i = 1, numFrames do
        local frame = frames[i]

        if frame and not nameplateFrames[frame] and IsNameplate(frame) then
            -- ClassicAPI exposes a modern nameplate wrapper. Prefer its
            -- UnitFrame name region, then keep the vanilla region lookup for
            -- the stock client and older nameplate addons.
            local unitFrame = frame.UnitFrame
            local nameText = unitFrame and (unitFrame.name or unitFrame.Name)
            if not nameText then
                nameText = ({ frame:GetRegions() })[NAME_REGION_INDEX]
            end
            if nameText and nameText:GetObjectType() == "FontString" then
                nameplateFrames[frame] = nameText

                if frame:IsShown() then
                    OnNameplateShow(frame)
                end
            end
        end
    end
end

local function UpdateAllNameplates()
    for frame, nameText in pairs(nameplateFrames) do
        if frame:IsShown() then
            OnNameplateShow(frame)
        else
            OnNameplateHide(frame)
        end
    end
end

-- World-space nameplates can render over a windowed world map even when
-- their icons use a lower frame level. Suppress our icons while it is open.
if WorldMapFrame then
    local previousOnShow = WorldMapFrame:GetScript("OnShow")
    WorldMapFrame:SetScript("OnShow", function()
        if previousOnShow then previousOnShow() end
        for _, iconFrame in pairs(iconFrames) do iconFrame:Hide() end
    end)
    local previousOnHide = WorldMapFrame:GetScript("OnHide")
    WorldMapFrame:SetScript("OnHide", function()
        if previousOnHide then previousOnHide() end
        UpdateAllNameplates()
    end)
end

local function RedrawAllIcons()
    UpdateCachedSettings()

    for _, iconFrame in pairs(iconFrames) do
        iconFrame:SetWidth(ICON_SIZE * cachedScale)
        iconFrame:SetHeight(ICON_SIZE * cachedScale)
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("LEFT", cachedX, cachedY)
    end
end

local ticker
local StartNameplateWatcher
local StopNameplateWatcher

local configMonitor = CreateFrame("Frame")
local lastEnabled = "1"

local function StartConfigMonitor()
    configMonitor.elapsed = 0
    configMonitor:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed >= 0.5 then
            if pfQuest_config then
                local currentEnabled = pfQuest_config["nameplatesEnabled"] or "1"

                if currentEnabled ~= lastEnabled then
                    lastEnabled = currentEnabled

                    if currentEnabled == "1" then
                        StartNameplateWatcher()
                        UpdateAllNameplates()
                    else
                        StopNameplateWatcher()
                        for frame in pairs(iconFrames) do
                            RemoveIconFrame(frame)
                        end
                    end
                end
            end
            this.elapsed = 0
        end
    end)
end

local lastNumChildren = 0
local classicNameplates = pfQuestCompat.optional and pfQuestCompat.optional.nameplates
local classicWatcherActive = false
-- The stock client has no plate events and must retain its scan. ClassicAPI
-- reports every plate lifecycle directly, so it needs no recurring scan.
local SCAN_INTERVAL = 0.2

local function ScanClassicNameplates()
    if not classicNameplates then return end
    local ok, frames = pcall(C_NamePlate.GetNamePlates)
    if ok and type(frames) == "table" then
        ScanWorldFrameChildren(frames)
    end
end

StartNameplateWatcher = function()
    if classicNameplates then
        if classicWatcherActive then return end
        classicWatcherActive = true
        UpdateCachedSettings()
        ScanClassicNameplates()
        StartConfigMonitor()
        return
    end

    if ticker then return end

    UpdateCachedSettings()
    lastNumChildren = -1
    ScanClassicNameplates()

    ticker = CreateFrame("Frame")
    ticker.elapsed = 0
    ticker:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1

        if this.elapsed >= SCAN_INTERVAL then
            local numChildren = WorldFrame:GetNumChildren()
            if numChildren ~= lastNumChildren then
                lastNumChildren = numChildren
                ScanWorldFrameChildren({ WorldFrame:GetChildren() })
            end
            UpdateAllNameplates()
            this.elapsed = 0
        end
    end)

    StartConfigMonitor()
end

StopNameplateWatcher = function()
    if classicNameplates then
        classicWatcherActive = false
    end

    if ticker then
        ticker:SetScript("OnUpdate", nil)
        ticker = nil
    end

    -- Keep the config monitor alive so the checkbox can enable us again.
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
local objectiveScan = CreateFrame("Frame")
local function QueueObjectiveScan()
    if objectiveScan:GetScript("OnUpdate") then return end
    objectiveScan.elapsed = 0
    objectiveScan:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 0.5 then
            this:SetScript("OnUpdate", nil)
            ScanQuestObjectives()
            UpdateAllNameplates()
        end
    end)
end

eventFrame:SetScript("OnEvent", QueueObjectiveScan)

if classicNameplates then
    local classicNameplateEvents = CreateFrame("Frame")
    local classicFramesByUnit = {}
    classicNameplateEvents:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    classicNameplateEvents:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    classicNameplateEvents:SetScript("OnEvent", function()
        local unit = arg1
        if event == "NAME_PLATE_UNIT_ADDED" and unit then
            local ok, frame = pcall(C_NamePlate.GetNamePlateForUnit, unit)
            if ok and frame then
                classicFramesByUnit[unit] = frame
                ScanWorldFrameChildren({ frame })
                OnNameplateShow(frame)
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" and unit then
            local frame = classicFramesByUnit[unit]
            classicFramesByUnit[unit] = nil
            if frame then OnNameplateHide(frame) end
        end
    end)
end

local function ExtendPfQuestConfig()
    local found = false
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "nameplatesEnabled" then
            found = true
            break
        end
    end

    if not found then
        table.insert(pfQuest_defconfig, { text = "|cff33ffccNameplates|r", type = "header" })
        table.insert(pfQuest_defconfig, { text = "Show Quest Icons on Nameplates", default = "1", type = "checkbox", config = "nameplatesEnabled" })
        table.insert(pfQuest_defconfig, { text = "Icon Scale", default = "1", type = "text", config = "nameplateScale" })
        table.insert(pfQuest_defconfig, { text = "Icon X Position", default = "-20", type = "text", config = "nameplateX" })
        table.insert(pfQuest_defconfig, { text = "Icon Y Position", default = "-8", type = "text", config = "nameplateY" })
    end

    pfQuest_config["nameplatesEnabled"] = pfQuest_config["nameplatesEnabled"] or "1"
    pfQuest_config["nameplateScale"] = pfQuest_config["nameplateScale"] or "1"
    pfQuest_config["nameplateX"] = pfQuest_config["nameplateX"] or "-20"
    pfQuest_config["nameplateY"] = pfQuest_config["nameplateY"] or "-8"
end

local function HookConfigWindow()
    if pfQuestConfig then
        local originalOnHide = pfQuestConfig:GetScript("OnHide")
        pfQuestConfig:SetScript("OnHide", function()
            if originalOnHide then
                originalOnHide()
            end
            RedrawAllIcons()
        end)
    end
end

local initialized = false
local function InitializeNameplates()
    if initialized or not pfQuest_defconfig or not pfQuest_config then return end
    initialized = true
    ExtendPfQuestConfig()
    HookConfigWindow()
    lastEnabled = pfQuest_config["nameplatesEnabled"]
    StartConfigMonitor()
    if lastEnabled == "1" then StartNameplateWatcher() end
    QueueObjectiveScan()
end
local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
configExtenderFrame:SetScript("OnEvent", InitializeNameplates)
InitializeNameplates()

SLASH_PFQUESTNP1 = "/pfqnp"
SlashCmdList["PFQUESTNP"] = function(msg)
    if msg == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle Nameplates Debug:|r")
        DEFAULT_CHAT_FRAME:AddMessage("Enabled: " .. tostring(pfQuest_config and pfQuest_config["nameplatesEnabled"] == "1"))
        DEFAULT_CHAT_FRAME:AddMessage("Watcher running: " .. tostring(ticker ~= nil))
        DEFAULT_CHAT_FRAME:AddMessage("pfDB exists: " .. tostring(pfDB ~= nil))

        local count = 0
        for npcName, icon in pairs(questObjectives) do
            count = count + 1
            local iconType = (icon == SWORD_ICON) and "KILL" or "LOOT"
            DEFAULT_CHAT_FRAME:AddMessage("  " .. npcName .. " - " .. iconType)
        end
        DEFAULT_CHAT_FRAME:AddMessage("Total objectives tracked: " .. count)

        local npCount = 0
        for _ in pairs(nameplateFrames) do npCount = npCount + 1 end
        DEFAULT_CHAT_FRAME:AddMessage("Total nameplates tracked: " .. npCount)

        local iconCount = 0
        for _ in pairs(iconFrames) do iconCount = iconCount + 1 end
        DEFAULT_CHAT_FRAME:AddMessage("Active nameplate icons: " .. iconCount .. ", total icon frames created: " .. frameCount)

        if count == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000No quest objectives found!|r")
        end
    elseif msg == "scan" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Manually scanning quest objectives...")
        ScanQuestObjectives()
        UpdateAllNameplates()
        DEFAULT_CHAT_FRAME:AddMessage("Done! Run |cffffcc00/pfqnp debug|r to see results")
    elseif msg == "inspect" then
        local focus = GetMouseFocus and GetMouseFocus()
        if not focus or focus == WorldFrame then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000No frame under your mouse.|r Hover directly over a nameplate's health bar, then run /pfqnp inspect")
        else
            local frame = focus
            local depth = 0
            while frame and frame:GetParent() ~= WorldFrame and depth < 10 do
                frame = frame:GetParent()
                depth = depth + 1
            end

            if not frame then return end
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Inspecting frame under mouse (walked up " .. depth .. " parent(s))")
            DEFAULT_CHAT_FRAME:AddMessage("  Name: " .. tostring(frame:GetName()))
            DEFAULT_CHAT_FRAME:AddMessage("  ObjectType: " .. tostring(frame:GetObjectType()))
            DEFAULT_CHAT_FRAME:AddMessage("  Parent is WorldFrame: " .. tostring(frame:GetParent() == WorldFrame))
            DEFAULT_CHAT_FRAME:AddMessage("  Region count: " .. table.getn({ frame:GetRegions() }))
            DEFAULT_CHAT_FRAME:AddMessage("  Child count: " .. frame:GetNumChildren())

            local r1 = frame:GetRegions()
            if r1 and r1.GetObjectType then
                DEFAULT_CHAT_FRAME:AddMessage("  Region 1 type: " .. tostring(r1:GetObjectType()))
                if r1:GetObjectType() == "Texture" then
                    DEFAULT_CHAT_FRAME:AddMessage("  Region 1 texture: '" .. tostring(r1:GetTexture()) .. "'")
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage("  Region 1: none")
            end

            local r3 = ({ frame:GetRegions() })[3]
            if r3 and r3.GetObjectType then
                DEFAULT_CHAT_FRAME:AddMessage("  Region 3 type: " .. tostring(r3:GetObjectType()))
                if r3:GetObjectType() == "FontString" then
                    DEFAULT_CHAT_FRAME:AddMessage("  Region 3 text: '" .. tostring(r3:GetText()) .. "'")
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage("  Region 3: none")
            end

            DEFAULT_CHAT_FRAME:AddMessage("  IsNameplate() result: " .. tostring(IsNameplate(frame)))
            DEFAULT_CHAT_FRAME:AddMessage("  Already registered by us: " .. tostring(nameplateFrames[frame] ~= nil))
        end
    elseif msg == "on" then
        if not pfQuest_config then pfQuest_config = {} end
        pfQuest_config["nameplatesEnabled"] = "1"
        StartNameplateWatcher()
        UpdateAllNameplates()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Nameplate icons enabled")
    elseif msg == "off" then
        if not pfQuest_config then pfQuest_config = {} end
        pfQuest_config["nameplatesEnabled"] = "0"
        StopNameplateWatcher()
        for frame in pairs(iconFrames) do
            RemoveIconFrame(frame)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Nameplate icons disabled")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle Nameplates:|r")
        DEFAULT_CHAT_FRAME:AddMessage("Commands: |cffffcc00/pfqnp debug|r, |cffffcc00/pfqnp scan|r, |cffffcc00/pfqnp inspect|r (hover a nameplate first), |cffffcc00/pfqnp on|r, |cffffcc00/pfqnp off|r")
        DEFAULT_CHAT_FRAME:AddMessage("Adjust icon size/position under pfQuest config -> Nameplates")
    end
end
