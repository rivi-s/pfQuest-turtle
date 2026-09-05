local PARTYPROGRESS_DEBUG = false
local function DebugPrint(msg)
    if PARTYPROGRESS_DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[PartyProgress]|r " .. msg)
    end
end

local origErrorHandler = geterrorhandler and geterrorhandler()
seterrorhandler(function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[pfQT ERROR]|r " .. tostring(msg))
    if debug and debug.traceback then
        local tb = debug.traceback("", 2)
        if tb and tb ~= "" then
            for line in string.gfind(tb, "[^\n]+") do
                DEFAULT_CHAT_FRAME:AddMessage("|cffff8800  " .. line .. "|r")
            end
        end
    end
    if origErrorHandler then
        return origErrorHandler(msg)
    end
end)

local partyQuestData = {}
local myQuestMappings = {}
local lastBroadcastState = {}
local previousQuestList = {}

local function CleanupPartyData()
    local validPlayers = {}
    validPlayers[UnitName("player")] = true

    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if name then
            validPlayers[name] = true
        end
    end

    for playerName in pairs(partyQuestData) do
        if not validPlayers[playerName] then
            partyQuestData[playerName] = nil
        end
    end
end

local function RebuildQuestMappings()
    if not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"] then
        return
    end

    if not pfDB["quests"]["enUS"] then
        return
    end

    local activeQuests = {}
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle(qid)
        if questTitle and complete ~= 1 then
            activeQuests[questTitle] = {}
            local numObjectives = GetNumQuestLeaderBoards(qid)

            for i = 1, numObjectives do
                local text, objType, finished = GetQuestLogLeaderBoard(i, qid)
                if text then
                    local objName, current, total = string.match(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                    if objName then
                        objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")
                        table.insert(activeQuests[questTitle], {
                            objective = objName,
                            current = tonumber(current),
                            total = tonumber(total)
                        })
                    end
                end
            end
        end
    end

    for questId, localizedData in pairs(pfDB["quests"]["enUS"]) do
        local questTitle = localizedData["T"]

        if questTitle and activeQuests[questTitle] then
            local questData = pfDB["quests"]["data"][questId]
            if questData and questData["obj"] then
                if questData["obj"]["U"] then
                    for _, unitId in pairs(questData["obj"]["U"]) do
                        if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                            local targetName = pfDB["units"]["enUS"][unitId]

                            for _, activeObj in ipairs(activeQuests[questTitle]) do
                                local objNameBase = activeObj.objective:gsub(" slain$", ""):gsub(" killed$", "")
                                if objNameBase == targetName or activeObj.objective:find(targetName, 1, true) then
                                    if not myQuestMappings[targetName] then
                                        myQuestMappings[targetName] = {}
                                    end

                                    local found = false
                                    for _, data in ipairs(myQuestMappings[targetName]) do
                                        if data.quest == questTitle and data.objective == activeObj.objective then
                                            data.current = activeObj.current
                                            data.total = activeObj.total
                                            data.questId = questId
                                            data.targetId = unitId
                                            data.targetType = "U"
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(myQuestMappings[targetName], {
                                            quest = questTitle,
                                            questId = questId,
                                            objective = activeObj.objective,
                                            current = activeObj.current,
                                            total = activeObj.total,
                                            targetId = unitId,
                                            targetType = "U"
                                        })
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

                                        for _, activeObj in ipairs(activeQuests[questTitle]) do
                                            if itemName and activeObj.objective:find(itemName, 1, true) then
                                                if not myQuestMappings[npcName] then
                                                    myQuestMappings[npcName] = {}
                                                end

                                                local found = false
                                                for _, data in ipairs(myQuestMappings[npcName]) do
                                                    if data.quest == questTitle and data.objective == activeObj.objective then
                                                        data.current = activeObj.current
                                                        data.total = activeObj.total
                                                        data.questId = questId
                                                        data.targetId = unitId
                                                        data.itemId = itemId
                                                        data.targetType = "I"
                                                        found = true
                                                        break
                                                    end
                                                end

                                                if not found then
                                                    table.insert(myQuestMappings[npcName], {
                                                        quest = questTitle,
                                                        questId = questId,
                                                        objective = activeObj.objective,
                                                        current = activeObj.current,
                                                        total = activeObj.total,
                                                        targetId = unitId,
                                                        itemId = itemId,
                                                        targetType = "I"
                                                    })
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            if itemData["O"] then
                                for objectId, dropRate in pairs(itemData["O"]) do
                                    if pfDB["objects"] and pfDB["objects"]["enUS"] and pfDB["objects"]["enUS"][objectId] then
                                        local objName = pfDB["objects"]["enUS"][objectId]

                                        for _, activeObj in ipairs(activeQuests[questTitle]) do
                                            if itemName and activeObj.objective:find(itemName, 1, true) then
                                                if not myQuestMappings[objName] then
                                                    myQuestMappings[objName] = {}
                                                end

                                                local found = false
                                                for _, data in ipairs(myQuestMappings[objName]) do
                                                    if data.quest == questTitle and data.objective == activeObj.objective then
                                                        data.current = activeObj.current
                                                        data.total = activeObj.total
                                                        data.questId = questId
                                                        data.targetId = objectId
                                                        data.itemId = itemId
                                                        data.targetType = "O"
                                                        found = true
                                                        break
                                                    end
                                                end

                                                if not found then
                                                    table.insert(myQuestMappings[objName], {
                                                        quest = questTitle,
                                                        questId = questId,
                                                        objective = activeObj.objective,
                                                        current = activeObj.current,
                                                        total = activeObj.total,
                                                        targetId = objectId,
                                                        itemId = itemId,
                                                        targetType = "O"
                                                    })
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
end

local function CaptureMyQuestData(targetKey, questTitle, objectiveText, current, total)
    if not myQuestMappings[targetKey] then
        myQuestMappings[targetKey] = {}
    end

    local found = false
    for _, data in ipairs(myQuestMappings[targetKey]) do
        if data.quest == questTitle and data.objective == objectiveText then
            data.current = current
            data.total = total
            found = true
            break
        end
    end

    if not found then
        table.insert(myQuestMappings[targetKey], {
            quest = questTitle,
            objective = objectiveText,
            current = current,
            total = total
        })
    end
end

local function BuildStateString(targetKey, questData)
    return string.format("%s:%s:%d:%d", targetKey, questData.quest, questData.current, questData.total)
end

local function ShareQuestData(forceFullSync)
    if GetNumPartyMembers() == 0 then
        return
    end

    local channel = "PARTY"

    local activeQuests = {}
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle = pfQuestCompat.GetQuestLogTitle(qid)
        if questTitle then
            activeQuests[questTitle] = true
        end
    end

    for questTitle in pairs(previousQuestList) do
        if not activeQuests[questTitle] then
            local questId = nil

            for targetKey, quests in pairs(myQuestMappings) do
                for _, questData in ipairs(quests) do
                    if questData.quest == questTitle and questData.questId then
                        questId = questData.questId
                        break
                    end
                end
                if questId then break end
            end

            if questId then
                local msg = string.format("REMOVEQ:%d:%s", questId, questTitle)
                SendAddonMessage("pfqt", msg, channel)
                DebugPrint("REMOVE broadcast - Quest: " .. questTitle .. " (ID: " .. questId .. ")")
            end
        end
    end

    previousQuestList = activeQuests

    for targetKey, quests in pairs(myQuestMappings) do
        local i = 1
        while i <= table.getn(quests) do
            if not activeQuests[quests[i].quest] then
                table.remove(quests, i)
            else
                i = i + 1
            end
        end

        if table.getn(quests) == 0 then
            myQuestMappings[targetKey] = nil
        end
    end

    for targetKey, quests in pairs(myQuestMappings) do
        for _, questData in ipairs(quests) do
            for qid = 1, GetNumQuestLogEntries() do
                local questTitle = pfQuestCompat.GetQuestLogTitle(qid)

                if questTitle == questData.quest then
                    local numObjectives = GetNumQuestLeaderBoards(qid)

                    for i = 1, numObjectives do
                        local text = GetQuestLogLeaderBoard(i, qid)

                        if text then
                            local objName, current, total = string.match(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                            if objName then
                                objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")

                                if objName == questData.objective then
                                    questData.current = tonumber(current)
                                    questData.total = tonumber(total)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local changedEntries = {}
    local currentState = {}
    local consolidatedObjectives = {}

    for targetKey, quests in pairs(myQuestMappings) do
        for _, data in ipairs(quests) do
            local stateKey = BuildStateString(targetKey, data)
            currentState[stateKey] = true

            if forceFullSync or not lastBroadcastState[stateKey] then
                if data.questId and data.targetId and data.targetType then

                    if data.targetType == "I" then
                        local objKey = data.questId .. ":" .. data.objective

                        if not consolidatedObjectives[objKey] then
                            consolidatedObjectives[objKey] = {
                                questId = data.questId,
                                objective = data.objective,
                                quest = data.quest,
                                current = data.current,
                                total = data.total,
                                targetType = "I",
                                targetId = data.itemId or data.targetId
                            }
                        else
                            if data.current > consolidatedObjectives[objKey].current then
                                consolidatedObjectives[objKey].current = data.current
                            end
                        end
                    else
                        table.insert(changedEntries, {
                            targetKey = targetKey,
                            targetType = data.targetType,
                            targetId = data.targetId,
                            questId = data.questId,
                            current = data.current,
                            total = data.total,
                            quest = data.quest,
                            objective = data.objective
                        })
                    end
                end
            end
        end
    end

    for _, entry in pairs(consolidatedObjectives) do
        table.insert(changedEntries, entry)
    end

    lastBroadcastState = currentState

    if table.getn(changedEntries) == 0 then
        DebugPrint("no changes to broadcast")
        return
    end

    local messages = {}
    local currentBatch = "V1"

    for _, entry in ipairs(changedEntries) do
        local safeObjective = string.gsub(entry.objective or "", "[:;]", "")
        local entryStr = string.format("%s%dQ%d:%d:%d:%s;", entry.targetType, entry.targetId, entry.questId, entry.current, entry.total, safeObjective)

        if string.len(currentBatch) + string.len(entryStr) > 250 then
            table.insert(messages, currentBatch)
            currentBatch = "V1" .. entryStr
        else
            currentBatch = currentBatch .. entryStr
        end
    end

    if string.len(currentBatch) > 2 then
        table.insert(messages, currentBatch)
    end

    for i, msg in ipairs(messages) do
        SendAddonMessage("pfqt", msg, channel)
    end
end

local function ProcessQuestData(sender, message)
    -- Some Turtle clients also fire CHAT_MSG_ADDON for messages we send to the
    -- party. Local progress is already rendered by the normal quest tooltip;
    -- retaining it here produces a duplicate line labelled with our own name.
    if sender == UnitName("player") then
        return
    end

    local removeQuestId, removeQuestTitle = string.match(message, "^REMOVEQ:(%d+):(.+)$")
    if removeQuestId and removeQuestTitle then
        if partyQuestData[sender] then
            for targetKey, quests in pairs(partyQuestData[sender]) do
                local i = 1
                while i <= table.getn(quests) do
                    if quests[i].quest == removeQuestTitle then
                        table.remove(quests, i)
                    else
                        i = i + 1
                    end
                end

                if table.getn(quests) == 0 then
                    partyQuestData[sender][targetKey] = nil
                end
            end
        end
        return
    end

    if string.sub(message, 1, 2) == "V1" then
        local batch = string.sub(message, 3)

        local entries = {}
        for entry in string.gfind(batch, "([^;]+)") do
            table.insert(entries, entry)
        end

        for _, entry in ipairs(entries) do
            local targetType, targetId, questId, current, total, objectiveText =
                string.match(entry, "^([UIO])(%d+)Q(%d+):(%d+):(%d+):(.*)$")

            if targetType and targetId and questId and current and total then
                targetId = tonumber(targetId)
                questId = tonumber(questId)
                current = tonumber(current)
                total = tonumber(total)

                if not objectiveText or objectiveText == "" then
                    objectiveText = "Quest Objective"
                end

                local questTitle = nil
                if pfDB and pfDB["quests"] and pfDB["quests"]["enUS"] and pfDB["quests"]["enUS"][questId] then
                    questTitle = pfDB["quests"]["enUS"][questId]["T"]
                end

                if not questTitle then
                elseif targetType == "I" then
                    if pfDB and pfDB["items"] and pfDB["items"]["data"] and pfDB["items"]["data"][targetId] then
                        local itemData = pfDB["items"]["data"][targetId]

                        if itemData["U"] then
                            for unitId in pairs(itemData["U"]) do
                                if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                                    local npcName = pfDB["units"]["enUS"][unitId]

                                    partyQuestData[sender] = partyQuestData[sender] or {}
                                    partyQuestData[sender][npcName] = partyQuestData[sender][npcName] or {}

                                    local found = false
                                    for _, data in ipairs(partyQuestData[sender][npcName]) do
                                        if data.quest == questTitle then
                                            data.objective = objectiveText
                                            data.current = current
                                            data.total = total
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(partyQuestData[sender][npcName], {
                                            quest = questTitle,
                                            objective = objectiveText,
                                            current = current,
                                            total = total
                                        })
                                    end
                                end
                            end
                        end

                        if itemData["O"] then
                            for objectId in pairs(itemData["O"]) do
                                if pfDB["objects"] and pfDB["objects"]["enUS"] and pfDB["objects"]["enUS"][objectId] then
                                    local objName = pfDB["objects"]["enUS"][objectId]

                                    partyQuestData[sender] = partyQuestData[sender] or {}
                                    partyQuestData[sender][objName] = partyQuestData[sender][objName] or {}

                                    local found = false
                                    for _, data in ipairs(partyQuestData[sender][objName]) do
                                        if data.quest == questTitle then
                                            data.objective = objectiveText
                                            data.current = current
                                            data.total = total
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(partyQuestData[sender][objName], {
                                            quest = questTitle,
                                            objective = objectiveText,
                                            current = current,
                                            total = total
                                        })
                                    end
                                end
                            end
                        end
                    end
                else
                    local targetName = nil
                    if targetType == "U" and pfDB["units"] and pfDB["units"]["enUS"] then
                        targetName = pfDB["units"]["enUS"][targetId]
                    elseif targetType == "O" and pfDB["objects"] and pfDB["objects"]["enUS"] then
                        targetName = pfDB["objects"]["enUS"][targetId]
                    end

                    if targetName then
                        partyQuestData[sender] = partyQuestData[sender] or {}
                        partyQuestData[sender][targetName] = partyQuestData[sender][targetName] or {}

                        local found = false
                        for _, data in ipairs(partyQuestData[sender][targetName]) do
                            if data.quest == questTitle then
                                data.objective = objectiveText
                                data.current = current
                                data.total = total
                                found = true
                                break
                            end
                        end

                        if not found then
                            table.insert(partyQuestData[sender][targetName], {
                                quest = questTitle,
                                objective = objectiveText,
                                current = current,
                                total = total
                            })
                        end
                    end
                end
            end
        end
    end
end

local function GetClassColor(playerName)
    if playerName == UnitName("player") then
        local _, class = UnitClass("player")
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local classColor = RAID_CLASS_COLORS[class]
            return {classColor.r, classColor.g, classColor.b}
        end
    end

    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if name == playerName then
            local _, class = UnitClass("party" .. i)
            if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
                local classColor = RAID_CLASS_COLORS[class]
                return {classColor.r, classColor.g, classColor.b}
            end
            break
        end
    end

    return {1.0, 1.0, 1.0}
end

local function BuildQuestGroups(matchedKey)
    local questGroups = {}

    local localPlayerName = UnitName("player")
    for playerName, targets in pairs(partyQuestData) do
        if playerName ~= localPlayerName and targets[matchedKey] then
            for _, data in ipairs(targets[matchedKey]) do
                questGroups[data.quest] = questGroups[data.quest] or {}

                local isDuplicate = false
                for _, existing in ipairs(questGroups[data.quest]) do
                    if existing.player == playerName and existing.objective == data.objective then
                        existing.current = data.current
                        existing.total = data.total
                        isDuplicate = true
                        break
                    end
                end

                if not isDuplicate then
                    table.insert(questGroups[data.quest], {
                        player = playerName,
                        objective = data.objective,
                        current = data.current,
                        total = data.total
                    })
                end
            end
        end
    end

    return questGroups
end

local function AddQuestGroupLines(tooltip, questGroups, shouldSkipHeader)
    tooltip:AddLine(" ")

    for questName, lines in pairs(questGroups) do
        if not (shouldSkipHeader and shouldSkipHeader(questName)) then
            local symbol = "|cff555555[|cffffcc00!|cff555555]|r "
            tooltip:AddLine(symbol .. questName, 1, 1, 0)
        end

        for _, line in ipairs(lines) do
            local classColor = GetClassColor(line.player)
            local perc = line.current / line.total
            local r, g, b

            if perc <= 0.5 then
                perc = perc * 2
                r, g, b = 1, perc, 0
            else
                perc = perc * 2 - 1
                r, g, b = 1 - perc, 1, 0
            end

            local cr, cg, cb = classColor[1] * 255, classColor[2] * 255, classColor[3] * 255
            local coloredName = string.format("|cFF%02x%02x%02x%s|r", cr, cg, cb, line.player)
            local displayText = string.format("|cffaaaaaa- |r%s: %s (%d/%d)", coloredName, line.objective, line.current, line.total)
            tooltip:AddLine(displayText, r, g, b)
        end
    end

    tooltip:AddLine(" ")
end

local function HookGameTooltip()
    local watcher = CreateFrame("Frame", nil, GameTooltip)
    watcher:SetScript("OnShow", function()
        local unitName = UnitName("mouseover")
        if not unitName then return end
        if UnitIsPlayer("mouseover") then DebugPrint("HookGameTooltip: skipped, mouseover is a player") return end

        local featureEnabled = pfQuest_config and pfQuest_config["showPartyProgress"] == "1"
        if not featureEnabled then DebugPrint("HookGameTooltip: skipped, showPartyProgress disabled") return end

        local hasData = false
        for _, targets in pairs(partyQuestData) do
            if targets[unitName] then
                hasData = true
                break
            end
        end
        DebugPrint("HookGameTooltip: unit=" .. unitName .. " hasData=" .. tostring(hasData))
        if not hasData then return end

        AddQuestGroupLines(GameTooltip, BuildQuestGroups(unitName), function(questName)
            for qid = 1, GetNumQuestLogEntries() do
                if pfQuestCompat.GetQuestLogTitle(qid) == questName then
                    return true
                end
            end
            return false
        end)
        GameTooltip:Show()
    end)
end

local function HookPfQuestTooltip()
    if not pfMap or not pfMap.ShowTooltip or not pfQuestCompat then
        return false
    end

    local orig_ShowTooltip = pfMap.ShowTooltip

    pfMap.ShowTooltip = function(self, meta, tooltip)
        tooltip = tooltip or GameTooltip

        local targetKey = meta.spawn or meta.title
        local tooltipName = nil
        local tooltipText = getglobal("GameTooltipTextLeft1")
        if tooltipText and tooltipText:GetText() then
            tooltipName = tooltipText:GetText()
        end

        local inParty = GetNumPartyMembers() > 0
        local featureEnabled = pfQuest_config and pfQuest_config["showPartyProgress"] == "1"

        DebugPrint("ShowTooltip: targetKey=" .. tostring(targetKey) .. " tooltipName=" .. tostring(tooltipName) .. " metaQuest=" .. tostring(meta["quest"]))

        if meta["quest"] and inParty and featureEnabled and targetKey then
            for qid = 1, GetNumQuestLogEntries() do
                local qtitle, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle(qid)

                if meta["quest"] == qtitle then
                    local objectives = GetNumQuestLeaderBoards(qid)

                    if objectives then
                        for i = 1, objectives do
                            local text = GetQuestLogLeaderBoard(i, qid)

                            if text then
                                local objName, current, total = string.match(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                                if objName and current and total then
                                    objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")
                                    if string.len(objName) > 0 then
                                        CaptureMyQuestData(targetKey, qtitle, objName, tonumber(current), tonumber(total))
                                        if tooltipName and tooltipName ~= targetKey then
                                            CaptureMyQuestData(tooltipName, qtitle, objName, tonumber(current), tonumber(total))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local hasPartyData, matchedKey = false, nil

        if featureEnabled then
            if targetKey then
                for _, targets in pairs(partyQuestData) do
                    if targets[targetKey] then
                        hasPartyData, matchedKey = true, targetKey
                        break
                    end
                end
            end

            if not hasPartyData and tooltipName then
                for _, targets in pairs(partyQuestData) do
                    if targets[tooltipName] then
                        hasPartyData, matchedKey = true, tooltipName
                        break
                    end
                end
            end
        end

        DebugPrint("ShowTooltip: hasPartyData=" .. tostring(hasPartyData) .. " matchedKey=" .. tostring(matchedKey) .. " mouseoverExists=" .. tostring(UnitExists("mouseover")))

        if hasPartyData and matchedKey and not UnitExists("mouseover") then
            local oldquest = meta["quest"]
            meta["quest"] = nil
            local ok = pcall(orig_ShowTooltip, self, meta, tooltip)
            meta["quest"] = oldquest
            if not ok then
                DebugPrint("orig_ShowTooltip failed while suppressing quest line")
            end

            AddQuestGroupLines(tooltip, BuildQuestGroups(matchedKey))

            tooltip:Show()
        else
            orig_ShowTooltip(self, meta, tooltip)
        end
    end

    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = arg1, arg2, arg3, arg4
        if prefix == "pfqt" then
            ProcessQuestData(sender, message)
        elseif prefix == "PFQT_SYNC" then
            if GetNumPartyMembers() > 0 and sender ~= UnitName("player") then
                RebuildQuestMappings()
                ShareQuestData(true)
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        CleanupPartyData()
        if GetNumPartyMembers() > 0 then
            RebuildQuestMappings()
            SendAddonMessage("PFQT_SYNC", "1", "PARTY")
            ShareQuestData(true)
        end
    elseif event == "QUEST_LOG_UPDATE" then
        if GetNumPartyMembers() > 0 then
            RebuildQuestMappings()
            ShareQuestData()
        end
    end
end)

local function ExtendPfQuestConfig()
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "showPartyProgress" then
            return
        end
    end

    table.insert(pfQuest_defconfig, {
        text = "Show Party Quest Progress on Tooltips",
        default = "1",
        type = "checkbox",
        config = "showPartyProgress"
    })

    pfQuest_config["showPartyProgress"] = pfQuest_config["showPartyProgress"] or "1"
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
    HookGameTooltip()

    if GetNumPartyMembers() > 0 then
        RebuildQuestMappings()
        SendAddonMessage("PFQT_SYNC", "1", "PARTY")
        ShareQuestData(true)
    end

    local timer = 0
    local rebuildRetries = 0
    this:SetScript("OnUpdate", function()
        timer = timer + 1

        if rebuildRetries < 50 and (not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"]) then
            if timer % 5 == 0 then
                rebuildRetries = rebuildRetries + 1
                if pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
                    RebuildQuestMappings()
                    if GetNumPartyMembers() > 0 then
                        SendAddonMessage("PFQT_SYNC", "1", "PARTY")
                        ShareQuestData(true)
                    end
                end
            end
        end

        if timer > 10 then
            if HookPfQuestTooltip() then
                this:SetScript("OnUpdate", nil)
                this:UnregisterAllEvents()
            elseif timer > 300 then
                this:SetScript("OnUpdate", nil)
                this:UnregisterAllEvents()
            end
        end
    end)
end)

SLASH_PFQUESTDEBUG1 = "/pfqd"
SlashCmdList["PFQUESTDEBUG"] = function(msg)
    local lowerMsg = msg and string.lower(msg)
    if lowerMsg == "on" then
        PARTYPROGRESS_DEBUG = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Party progress debug logging ON - hover the mob to see what's happening")
        return
    elseif lowerMsg == "off" then
        PARTYPROGRESS_DEBUG = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Party progress debug logging OFF")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle Party Progress Debug:|r")
    DEFAULT_CHAT_FRAME:AddMessage("Party members: " .. GetNumPartyMembers())
    DEFAULT_CHAT_FRAME:AddMessage("Feature enabled: " .. tostring(pfQuest_config and pfQuest_config["showPartyProgress"] == "1"))

    local count = 0
    for _ in pairs(myQuestMappings) do count = count + 1 end
    DEFAULT_CHAT_FRAME:AddMessage("myQuestMappings targets: " .. count)
    for targetKey, quests in pairs(myQuestMappings) do
        DEFAULT_CHAT_FRAME:AddMessage("  Target: " .. targetKey)
        for _, data in ipairs(quests) do
            DEFAULT_CHAT_FRAME:AddMessage("    - " .. data.quest .. ": " .. data.objective .. " (" .. data.current .. "/" .. data.total .. ")")
        end
    end

    local partyCount = 0
    for _ in pairs(partyQuestData) do partyCount = partyCount + 1 end
    DEFAULT_CHAT_FRAME:AddMessage("partyQuestData players: " .. partyCount)
    for playerName, targets in pairs(partyQuestData) do
        DEFAULT_CHAT_FRAME:AddMessage("  Player: " .. playerName)
        for targetKey, quests in pairs(targets) do
            DEFAULT_CHAT_FRAME:AddMessage("    Target: " .. targetKey)
            for _, data in ipairs(quests) do
                DEFAULT_CHAT_FRAME:AddMessage("      - " .. data.quest .. ": " .. data.objective .. " (" .. data.current .. "/" .. data.total .. ")")
            end
        end
    end

    if count == 0 and partyCount == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000No quest data found!|r Try killing a quest mob, or run /pfqrebuild after joining a party.")
    end
end

SLASH_PFQUEREBUILD1 = "/pfqrebuild"
SlashCmdList["PFQUEREBUILD"] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Rebuilding quest mappings...")
    RebuildQuestMappings()
    if GetNumPartyMembers() > 0 then
        SendAddonMessage("PFQT_SYNC", "1", "PARTY")
        ShareQuestData(true)
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Done! Run /pfqd to see results.")
end

SLASH_PFQUESTTEST1 = "/pfqtest"
SlashCmdList["PFQUESTTEST"] = function(msg)
    if not msg or msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Usage: /pfqtest <exact unit name> - then mouseover that unit")
        return
    end

    partyQuestData["TestBuddy"] = partyQuestData["TestBuddy"] or {}
    partyQuestData["TestBuddy"][msg] = {
        {
            quest = "Test Quest",
            objective = "Kill " .. msg,
            current = 3,
            total = 10
        }
    }

    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Injected fake party progress for '" .. msg .. "' from TestBuddy. Mouseover it (or its map pin) to check the tooltip.")
end
