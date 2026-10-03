-- Older standard cores do not expose the optional backend boundary.
local function HDBEnabled()
  return pfDatabase and type(pfDatabase.IsHDBEnabled) == "function"
    and pfDatabase:IsHDBEnabled() or false
end

local PARTYPROGRESS_DEBUG = false
local partyQuestData = {}
local myQuestMappings = {}
local lastBroadcastState = {}
local previousQuestList = {}
local lastPartyPinSignature = nil
local RenderPartyQuestPins

local function CanonicalPlayerName(name)
    name = tostring(name or "")
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    name = string.gsub(name, "%-.*$", "")
    return string.lower(name)
end

local function CleanupPartyData()
    local validPlayers = {}
    validPlayers[CanonicalPlayerName(UnitName("player"))] = true

    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if name then
            validPlayers[CanonicalPlayerName(name)] = true
        end
    end

    for playerName in pairs(partyQuestData) do
        if not validPlayers[CanonicalPlayerName(playerName)] then
            partyQuestData[playerName] = nil
        end
    end
end

local function RebuildQuestMappings(onComplete)
    local hdbAvailable = HDBEnabled() and type(pfQuestHearthDB.GetQuestTargetsAsync) == "function"
    if not hdbAvailable and (not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"] or not pfDB["quests"]["enUS"]) then
        if onComplete then onComplete() end
        return
    end

    local activeQuests = {}
    local activeQuestIds = {}
    local unresolvedTitles = {}
    local questIdByLogIndex = {}
    if pfQuest and pfQuest.questlog then
        for questId, state in pairs(pfQuest.questlog) do
            if type(questId) == "number" and state and state.qlogid then
                questIdByLogIndex[state.qlogid] = questId
            end
        end
    end
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle(qid)
        if questTitle and complete ~= 1 then
            activeQuests[questTitle] = {}
            local questId = questIdByLogIndex[qid]
            if not questId then
                local preserveSelection = QuestLogFrame and QuestLogFrame:IsShown()
                local ids = pfDatabase:GetQuestIDs(qid, preserveSelection)
                questId = ids and tonumber(ids[1])
            end
            if questId then activeQuestIds[questId] = { title = questTitle, objectives = activeQuests[questTitle] }
            else unresolvedTitles[questTitle] = true end
            -- The client can briefly return nil while the quest log is
            -- unavailable during transitions such as taking a flight path.
            local numObjectives = tonumber(GetNumQuestLeaderBoards(qid)) or 0

            for i = 1, numObjectives do
                local text, objType, finished = GetQuestLogLeaderBoard(i, qid)
                if text then
                    local _, _, objName, current, total = string.find(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
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

    if hdbAvailable then
        myQuestMappings = {}
        local pending = 0
        for _ in pairs(activeQuestIds) do pending = pending + 1 end
        if pending == 0 then if onComplete then onComplete() end return end

        local function StoreMapping(targetName, questId, questTitle, activeObj, target)
            myQuestMappings[targetName] = myQuestMappings[targetName] or {}
            table.insert(myQuestMappings[targetName], {
                quest = questTitle, questId = questId, objective = activeObj.objective,
                current = activeObj.current, total = activeObj.total,
                targetId = target.targetID, itemId = target.originKind == "I" and target.originID or nil,
                targetType = target.originKind == "I" and (target.targetKind == "O" and "O" or "I") or target.targetKind
            })
        end

        for questId, active in pairs(activeQuestIds) do
            local currentQuestId, current = questId, active
            pfQuestHearthDB:GetQuestTargetsAsync(currentQuestId, function(records, err)
                if not err and records then
                    local seen = {}
                    for _, target in ipairs(records) do
                        if target.phase == "obj" and (target.targetKind == "U" or target.targetKind == "O") and target.title then
                            for _, activeObj in ipairs(current.objectives) do
                                local matches = false
                                if target.originKind == "I" and target.itemTitle then
                                    matches = string.find(activeObj.objective, target.itemTitle, 1, true) and true or false
                                elseif (target.originKind or target.targetKind) == target.targetKind then
                                    local objectiveBase = string.gsub(activeObj.objective, " slain$", "")
                                    objectiveBase = string.gsub(objectiveBase, " killed$", "")
                                    matches = objectiveBase == target.title or string.find(activeObj.objective, target.title, 1, true)
                                end
                                local key = target.title .. ":" .. activeObj.objective
                                if matches and not seen[key] then
                                    seen[key] = true
                                    StoreMapping(target.title, currentQuestId, current.title, activeObj, target)
                                end
                            end
                        end
                    end
                end
                pending = pending - 1
                if pending == 0 and onComplete then onComplete() end
            end)
        end
        return
    end

    -- Party joins and quest turn-ins can produce several QUEST_LOG_UPDATE
    -- events. Only inspect the handful of active quest records instead of
    -- walking the entire quest database for every refresh. The title fallback
    -- is retained for the brief client states where a log index has no ID yet.
    local candidateQuests = {}
    for questId in pairs(activeQuestIds) do
        local localizedData = pfDB["quests"]["enUS"][questId]
        if localizedData then candidateQuests[questId] = localizedData end
    end
    if next(unresolvedTitles) then
        for questId, localizedData in pairs(pfDB["quests"]["enUS"]) do
            if localizedData["T"] and unresolvedTitles[localizedData["T"]] then
                candidateQuests[questId] = localizedData
            end
        end
    end

    for questId, localizedData in pairs(candidateQuests) do
        local questTitle = localizedData["T"]

        if questTitle and activeQuests[questTitle] then
            local questData = pfDB["quests"]["data"][questId]
            if questData and questData["obj"] then
                if questData["obj"]["U"] then
                    for _, unitId in pairs(questData["obj"]["U"]) do
                        if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                            local targetName = pfDB["units"]["enUS"][unitId]

                            for _, activeObj in ipairs(activeQuests[questTitle]) do
                                local objNameBase = string.gsub(activeObj.objective, " slain$", "")
                                objNameBase = string.gsub(objNameBase, " killed$", "")
                                if objNameBase == targetName or string.find(activeObj.objective, targetName, 1, true) then
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
                                            if itemName and string.find(activeObj.objective, itemName, 1, true) then
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
                                            if itemName and string.find(activeObj.objective, itemName, 1, true) then
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
    if onComplete then onComplete() end
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

-- True when the local player also has this exact quest+objective active
-- (tracked via the same myQuestMappings this file already builds for its own
-- tooltip/broadcast use). When true, the player's own normal PFQUEST pin
-- already sits at this spot -- HookPfQuestTooltip already appends every
-- party member's progress to that pin's tooltip -- so a separate PFPARTY pin
-- would only be a redundant, differently-styled duplicate at the same coords.
local function LocalPlayerHasObjective(targetKey, questTitle, objectiveText)
    local quests = myQuestMappings[targetKey]
    if not quests then return false end
    for _, localData in ipairs(quests) do
        if localData.quest == questTitle and localData.objective == objectiveText then
            return true
        end
    end
    return false
end

-- Renders party members' active, incomplete quest objectives as map pins
-- under a dedicated "PFPARTY" addon namespace, kept separate from the
-- player's own "PFQUEST" pins so it never appears in the quest tracker
-- (tracker.lua only reads PFQUEST nodes). Only rendered for objectives the
-- local player does NOT also have active (see LocalPlayerHasObjective above)
-- -- otherwise the normal PFQUEST pin already covers it. Opt-in via the
-- showPartyQuestPins config checkbox. No meta.texture is set: map.lua's
-- UpdateNode gives an untextured PFPARTY node the same star shape as the
-- "fav" marker but tinted through the ordinary color-hash/click-to-recolor
-- path (see the frame.addon == "PFPARTY" branch there), and (since QTYPE
-- below always contains "OBJECTIVE") it becomes eligible for the same
-- raw-objective route-arrow targeting those use -- a dedicated meta.texture
-- would have skipped both (see the route-eligibility gate added in map.lua's
-- raw-objective detection for the opt-out).
-- Forward-declared above: both this synchronous caller and
-- ProcessHDBPartyEntry's async GetQuestMapPinsAsync callback need to call it,
-- and the async one resolves after this point in the file.
RenderPartyQuestPins = function()
    if not pfMap or not pfMap.DeleteNode then
        return
    end

    local enabled = pfQuest_config and pfQuest_config["showPartyQuestPins"] == "1"

    -- Cheap signature of what would actually be drawn. Several triggers call
    -- this function far more often than the rendered pin set ever changes
    -- (e.g. QUEST_LOG_UPDATE firing on unrelated log activity); tearing down
    -- and rebuilding identical nodes on every one of those made a pin's
    -- tooltip flicker/disappear if the player happened to be hovering it.
    local sigParts = {}
    if enabled then
        for playerName, targets in pairs(partyQuestData) do
            for targetKey, quests in pairs(targets) do
                for _, data in ipairs(quests) do
                    if data.targetType and data.targetId and data.questId
                      and (data.current or 0) < (data.total or 0)
                      and not LocalPlayerHasObjective(targetKey, data.quest, data.objective) then
                        table.insert(sigParts, playerName .. ":" .. targetKey .. ":" .. data.quest
                            .. ":" .. data.current .. "/" .. data.total)
                    end
                end
            end
        end
        table.sort(sigParts)
    end
    local signature = enabled and table.concat(sigParts, ";") or "off"

    if signature == lastPartyPinSignature then
        return
    end
    lastPartyPinSignature = signature

    pfMap:DeleteNode("PFPARTY")

    if not enabled then
        return
    end

    for playerName, targets in pairs(partyQuestData) do
        for targetKey, quests in pairs(targets) do
            for _, data in ipairs(quests) do
                if data.targetType and data.targetId and data.questId
                  and (data.current or 0) < (data.total or 0)
                  and not LocalPlayerHasObjective(targetKey, data.quest, data.objective) then
                    if data.spawns and table.getn(data.spawns) > 0 then
                        -- HDB-resolved target: GetQuestMapPinsAsync already gave us
                        -- real coordinates from SQLite, one per known spawn point.
                        -- Those IDs are a different space than the legacy static
                        -- pfDB.units/objects tables, so SearchMobID/SearchObjectID
                        -- would silently find nothing here (see SearchQuestPreviewHDB
                        -- and AddPin in hdb_adapter.lua for the same direct-AddNode
                        -- pattern used elsewhere for HDB pins). Mirror AddPin's field
                        -- mapping so tooltip/loot-panel behave like an ordinary quest
                        -- pin; only addon marks this as a party pin.
                        for _, spawn in ipairs(data.spawns) do
                            local qtype, item
                            local spawntype = spawn.targetKind == "O" and pfQuest_Loc["Object"] or pfQuest_Loc["Unit"]
                            if spawn.originKind == "I" then
                                qtype = "ITEM_OBJECTIVE_LOOT"
                                item = spawn.itemTitle or (pfDB.items.loc and pfDB.items.loc[spawn.originID])
                            elseif spawn.targetKind == "O" then
                                qtype = "OBJECT_OBJECTIVE"
                            else
                                qtype = "UNIT_OBJECTIVE"
                            end

                            pfMap:AddNode({
                                addon = "PFPARTY",
                                title = data.quest,
                                quest = data.quest,
                                questid = data.questId,
                                questObjective = data.objective,
                                level = spawn.level or UNKNOWN,
                                spawn = targetKey,
                                spawnid = spawn.targetID or data.targetId,
                                spawntype = spawntype,
                                zone = spawn.zone,
                                x = spawn.x,
                                y = spawn.y,
                                respawn = spawn.respawn and SecondsToTime(spawn.respawn) or "N/A",
                                droprate = spawn.sourceKind == "V" and nil or spawn.chance,
                                sellcount = spawn.sourceKind == "V" and spawn.chance or nil,
                                item = item,
                                QTYPE = qtype,
                            })
                        end
                    elseif pfDatabase and pfDatabase.SearchMobID and pfDatabase.SearchObjectID then
                        -- Static-fallback data (HDB provider unavailable): targetId
                        -- came from the legacy pfDB tables, so the legacy lookup is
                        -- the correct (and only) way to resolve it, and it already
                        -- returns every known spawn coordinate for that target.
                        local meta = {
                            addon = "PFPARTY",
                            quest = data.quest,
                            questid = data.questId,
                        }

                        if data.targetType == "U" then
                            pfDatabase:SearchMobID(data.targetId, meta)
                        elseif data.targetType == "O" then
                            pfDatabase:SearchObjectID(data.targetId, meta)
                        end
                    end
                end
            end
        end
    end
end

-- HDB resolves party objectives asynchronously and a full sync may complete
-- many callbacks in one frame. Coalesce them so the party pin layer is drawn
-- once after the burst instead of once per resolved objective.
local partyPinRefresh = CreateFrame("Frame")
local function QueuePartyPinRender()
    partyPinRefresh.elapsed = 0
    partyPinRefresh:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 0.10 then
            this:SetScript("OnUpdate", nil)
            RenderPartyQuestPins()
        end
    end)
end

local function StoreRemoteQuestProgress(sender, targetName, questTitle, objectiveText, current, total, questId, targetId, targetType, pin)
    if not targetName or not questTitle then return end
    partyQuestData[sender] = partyQuestData[sender] or {}
    partyQuestData[sender][targetName] = partyQuestData[sender][targetName] or {}

    local data
    for _, existing in ipairs(partyQuestData[sender][targetName]) do
        if existing.quest == questTitle then
            data = existing
            break
        end
    end
    if not data then
        data = { quest = questTitle, spawns = {}, spawnSeen = {} }
        table.insert(partyQuestData[sender][targetName], data)
    end

    data.objective, data.current, data.total = objectiveText, current, total
    data.questId, data.targetId, data.targetType = questId, targetId, targetType

    -- Each matching HDB pin is a distinct physical spawn point of this target
    -- (mirroring how AddPin in hdb_adapter.lua calls pfMap:AddNode once per
    -- pin for the player's own quests). Keep every one so party pins show all
    -- known spawns, not just the first resolved.
    if pin and pin.zoneID and pin.x and pin.y then
        local coordKey = pin.zoneID .. ":" .. pin.x .. ":" .. pin.y
        if not data.spawnSeen[coordKey] then
            data.spawnSeen[coordKey] = true
            table.insert(data.spawns, {
                zone = pin.zoneID, x = pin.x, y = pin.y,
                level = pin.level, respawn = pin.respawn, rank = pin.rank,
                targetKind = pin.targetKind, targetID = pin.targetID,
                originKind = pin.originKind, originID = pin.originID,
                itemTitle = pin.itemTitle, sourceKind = pin.sourceKind, chance = pin.chance,
            })
        end
    end
end

local function ProcessHDBPartyEntry(sender, targetType, targetId, questId, current, total, objectiveText)
    if not HDBEnabled() or type(pfQuestHearthDB.GetQuestMapPinsAsync) ~= "function" then return false end
    local accepted = pfQuestHearthDB:GetQuestMapPinsAsync(questId, function(result, err)
        if err or not result then return end
        for _, target in ipairs(result.pins or {}) do
            -- Only objective pins are real spawn/interaction points; "start"/"end"
            -- pins (quest giver/turn-in) can coincidentally share a targetKind/ID.
            local matches = target.phase == "obj" and (
                (targetType == "I" and target.originKind == "I" and target.originID == targetId)
                or (targetType ~= "I" and target.targetKind == targetType and target.targetID == targetId)
            )
            if matches and target.title then
                -- Store the specific spawn source's own kind/ID (target.targetKind/
                -- targetID), not the wire-level targetType/targetId: for an item
                -- objective those are "I"+itemId, which GetQuestTargetsAsync-style
                -- rendering can't place a pin at directly, whereas each matched
                -- target here is a concrete unit or object with real coordinates.
                StoreRemoteQuestProgress(sender, target.title, result.title, objectiveText, current, total,
                    questId, target.targetID, target.targetKind, target)
            end
        end
        QueuePartyPinRender()
    end)
    return accepted and true or false
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

    -- Read the quest log once, then apply progress to every mapped spawn.
    -- Item objectives can map to many units/objects, so rescanning the full
    -- log for each mapping caused a noticeable hitch during full party syncs.
    local objectiveProgress = {}
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle = pfQuestCompat.GetQuestLogTitle(qid)
        if questTitle then
            objectiveProgress[questTitle] = objectiveProgress[questTitle] or {}
            local numObjectives = tonumber(GetNumQuestLeaderBoards(qid)) or 0
            for i = 1, numObjectives do
                local text = GetQuestLogLeaderBoard(i, qid)
                if text then
                    local _, _, objName, current, total = string.find(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                    if objName then
                        objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")
                        objectiveProgress[questTitle][objName] = {
                            current = tonumber(current), total = tonumber(total)
                        }
                    end
                end
            end
        end
    end
    for _, quests in pairs(myQuestMappings) do
        for _, questData in ipairs(quests) do
            local progress = objectiveProgress[questData.quest]
                and objectiveProgress[questData.quest][questData.objective]
            if progress then
                questData.current = progress.current
                questData.total = progress.total
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
    -- Turtle may qualify addon-message senders with a realm suffix while
    -- UnitName returns the short name. Keep storage, cleanup, and the local
    -- echo guard on the same form.
    local _, _, shortSender = string.find(sender or "", "^([^-]+)")
    sender = shortSender or sender
    -- Some Turtle clients also fire CHAT_MSG_ADDON for messages we send to the
    -- party. Local progress is already rendered by the normal quest tooltip;
    -- retaining it here produces a duplicate line labelled with our own name.
    if CanonicalPlayerName(sender) == CanonicalPlayerName(UnitName("player")) then
        return
    end

    local _, _, removeQuestId, removeQuestTitle = string.find(message, "^REMOVEQ:(%d+):(.+)$")
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
            local _, _, targetType, targetId, questId, current, total, objectiveText =
                string.find(entry, "^([UIO])(%d+)Q(%d+):(%d+):(%d+):(.*)$")

            if targetType and targetId and questId and current and total then
                targetId = tonumber(targetId)
                questId = tonumber(questId)
                current = tonumber(current)
                total = tonumber(total)

                if not objectiveText or objectiveText == "" then
                    objectiveText = "Quest Objective"
                end

                if ProcessHDBPartyEntry(sender, targetType, targetId, questId, current, total, objectiveText) then
                    -- HearthDB resolves both the quest title and every matching
                    -- source name asynchronously; no loaded Lua tables needed.
                else
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
                                            data.questId = questId
                                            data.targetId = unitId
                                            data.targetType = "U"
                                            data.itemId = targetId
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(partyQuestData[sender][npcName], {
                                            quest = questTitle,
                                            objective = objectiveText,
                                            current = current,
                                            total = total,
                                            questId = questId,
                                            targetId = unitId,
                                            targetType = "U",
                                            itemId = targetId
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
                                            data.questId = questId
                                            data.targetId = objectId
                                            data.targetType = "O"
                                            data.itemId = targetId
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(partyQuestData[sender][objName], {
                                            quest = questTitle,
                                            objective = objectiveText,
                                            current = current,
                                            total = total,
                                            questId = questId,
                                            targetId = objectId,
                                            targetType = "O",
                                            itemId = targetId
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
                                data.questId = questId
                                data.targetId = targetId
                                data.targetType = targetType
                                found = true
                                break
                            end
                        end

                        if not found then
                            table.insert(partyQuestData[sender][targetName], {
                                quest = questTitle,
                                objective = objectiveText,
                                current = current,
                                total = total,
                                questId = questId,
                                targetId = targetId,
                                targetType = targetType
                            })
                        end
                    end
                end
                end
            end
        end
    end
end

local function GetClassColor(playerName)
    if CanonicalPlayerName(playerName) == CanonicalPlayerName(UnitName("player")) then
        local _, class = UnitClass("player")
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local classColor = RAID_CLASS_COLORS[class]
            return {classColor.r, classColor.g, classColor.b}
        end
    end

    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if CanonicalPlayerName(name) == CanonicalPlayerName(playerName) then
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
        if CanonicalPlayerName(playerName) ~= CanonicalPlayerName(localPlayerName) and targets[matchedKey] then
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
        if UnitIsPlayer("mouseover") then return end

        local featureEnabled = pfQuest_config and pfQuest_config["showPartyProgress"] == "1"
        if not featureEnabled then return end

        local hasData = false
        for _, targets in pairs(partyQuestData) do
            if targets[unitName] then
                hasData = true
                break
            end
        end
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


        if meta["quest"] and inParty and featureEnabled and targetKey then
            for qid = 1, GetNumQuestLogEntries() do
                local qtitle, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle(qid)

                if meta["quest"] == qtitle then
                    local objectives = tonumber(GetNumQuestLeaderBoards(qid)) or 0

                    if objectives > 0 then
                        for i = 1, objectives do
                            local text = GetQuestLogLeaderBoard(i, qid)

                            if text then
                                local _, _, objName, current, total = string.find(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
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


        if hasPartyData and matchedKey and not UnitExists("mouseover") then
            local oldquest = meta["quest"]
            meta["quest"] = nil
            local ok = pcall(orig_ShowTooltip, self, meta, tooltip)
            meta["quest"] = oldquest
            if not ok then
            end

            AddQuestGroupLines(tooltip, BuildQuestGroups(matchedKey))

            tooltip:Show()
        else
            orig_ShowTooltip(self, meta, tooltip)
        end
    end

    return true
end

-- QUEST_LOG_UPDATE arrives in bursts during login. Rebuilding mappings walks
-- the active log and database relations, so coalesce those bursts into one
-- pass after the client has settled.
local mappingRefresh = CreateFrame("Frame")
local function QueueMappingRefresh(forceFullSync, requestPeers)
    mappingRefresh.forceFullSync = mappingRefresh.forceFullSync or forceFullSync
    mappingRefresh.requestPeers = mappingRefresh.requestPeers or requestPeers
    mappingRefresh.elapsed = 0
    mappingRefresh:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 0.5 then
            local force = this.forceFullSync
            local request = this.requestPeers
            this.forceFullSync = nil
            this.requestPeers = nil
            this:SetScript("OnUpdate", nil)
            if GetNumPartyMembers() > 0 then
                RebuildQuestMappings(function()
                    if request then SendAddonMessage("PFQT_SYNC", "1", "PARTY") end
                    ShareQuestData(force)
                    -- myQuestMappings just changed, which is what
                    -- LocalPlayerHasObjective reads: re-evaluate now rather
                    -- than waiting for the next unrelated trigger, so a party
                    -- star drops out (or appears) as soon as the local player's
                    -- own quest state actually does.
                    QueuePartyPinRender()
                end)
            end
        end
    end)
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
            -- Covers the synchronous (static Lua fallback) storage path.
            -- Async HDB results and multipart addon messages share the same
            -- short render queue, so a full party sync produces one redraw.
            QueuePartyPinRender()
        elseif prefix == "PFQT_SYNC" then
            if GetNumPartyMembers() > 0 and CanonicalPlayerName(sender) ~= CanonicalPlayerName(UnitName("player")) then
                QueueMappingRefresh(true)
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        CleanupPartyData()
        QueuePartyPinRender()
        if GetNumPartyMembers() > 0 then
            QueueMappingRefresh(true, true)
        end
    elseif event == "QUEST_LOG_UPDATE" then
        if GetNumPartyMembers() > 0 then
            QueueMappingRefresh()
            -- Piggyback on this frequently-firing event to pick up a config
            -- checkbox toggle without a dedicated polling ticker.
            QueuePartyPinRender()
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
        text = "Party Quest Sharing",
        type = "header",
        page = "features"
    })

    table.insert(pfQuest_defconfig, {
        text = "Show Party Quest Progress on Tooltips",
        default = "1",
        type = "checkbox",
        config = "showPartyProgress"
    })

    table.insert(pfQuest_defconfig, {
        text = "Show Party Members' Quest Objectives on Map |cffffcc00[Beta]|r",
        default = "0",
        type = "checkbox",
        config = "showPartyQuestPins",
        tooltip = "This feature is still being tested. Party members' active quest objectives are shown as a separate colored marker on the map. Behavior may change or have rough edges."
    })

    table.insert(pfQuest_defconfig, {
        text = "Allow Routing to Party Members' Quest Objectives |cffffcc00[Beta]|r",
        default = "0",
        type = "checkbox",
        config = "showPartyQuestPinsRoutable",
        tooltip = "This feature is still being tested. When enabled, the navigation arrow can target a party member's quest objective marker, not just your own."
    })

    pfQuest_config["showPartyProgress"] = pfQuest_config["showPartyProgress"] or "1"
    pfQuest_config["showPartyQuestPins"] = pfQuest_config["showPartyQuestPins"] or "0"
    pfQuest_config["showPartyQuestPinsRoutable"] = pfQuest_config["showPartyQuestPinsRoutable"] or "0"
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
    HookGameTooltip()
    RenderPartyQuestPins()

    if GetNumPartyMembers() > 0 then
        QueueMappingRefresh(true, true)
    end

    local timer = 0
    local rebuildRetries = 0
    this:SetScript("OnUpdate", function()
        timer = timer + 1

        if rebuildRetries < 50 and (not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"]) then
            if math.mod(timer, 5) == 0 then
                rebuildRetries = rebuildRetries + 1
                if pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
                    RebuildQuestMappings(function()
                        if GetNumPartyMembers() > 0 then
                            SendAddonMessage("PFQT_SYNC", "1", "PARTY")
                            ShareQuestData(true)
                        end
                        RenderPartyQuestPins()
                    end)
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
if pfQuest_defconfig and pfQuest_config then ExtendPfQuestConfig() end

SLASH_PFQUEREBUILD1 = "/pfqrebuild"
SlashCmdList["PFQUEREBUILD"] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Rebuilding quest mappings...")
    RebuildQuestMappings(function()
        if GetNumPartyMembers() > 0 then
            SendAddonMessage("PFQT_SYNC", "1", "PARTY")
            ShareQuestData(true)
        end
        RenderPartyQuestPins()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Quest mappings rebuilt.")
    end)
end

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
    DEFAULT_CHAT_FRAME:AddMessage("Tooltip progress enabled: " .. tostring(pfQuest_config and pfQuest_config["showPartyProgress"] == "1"))
    DEFAULT_CHAT_FRAME:AddMessage("Map pins enabled: " .. tostring(pfQuest_config and pfQuest_config["showPartyQuestPins"] == "1")
        .. " (routable: " .. tostring(not pfQuest_config or pfQuest_config["showPartyQuestPinsRoutable"] ~= "0") .. ")")

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
    local pinnableCount = 0
    for _ in pairs(partyQuestData) do partyCount = partyCount + 1 end
    DEFAULT_CHAT_FRAME:AddMessage("partyQuestData players: " .. partyCount)
    for playerName, targets in pairs(partyQuestData) do
        DEFAULT_CHAT_FRAME:AddMessage("  Player: " .. playerName)
        for targetKey, quests in pairs(targets) do
            DEFAULT_CHAT_FRAME:AddMessage("    Target: " .. targetKey)
            for _, data in ipairs(quests) do
                local pinnable = data.targetType and data.targetId and data.questId
                  and (data.current or 0) < (data.total or 0)
                if pinnable then pinnableCount = pinnableCount + 1 end
                DEFAULT_CHAT_FRAME:AddMessage("      - " .. data.quest .. ": " .. data.objective .. " (" .. data.current .. "/" .. data.total .. ")"
                    .. (pinnable and " |cff33ffcc[pinnable]|r" or ""))
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("Pinnable party entries: " .. pinnableCount)

    if count == 0 and partyCount == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000No quest data found!|r Try killing a quest mob, or run /pfqrebuild after joining a party.")
    end
end


SLASH_PFQUESTTEST1 = "/pfqtest"
SlashCmdList["PFQUESTTEST"] = function(msg)
    if not msg or msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Usage: /pfqtest <exact unit name> - tooltip-only test, then mouseover that unit")
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Usage: /pfqtest <exact unit name> <unitId> <questId> - also drops a test map pin, real IDs required")
        return
    end

    local unitName, unitId, questId = string.match(msg, "^(.-)%s+(%d+)%s+(%d+)$")

    partyQuestData["TestBuddy"] = partyQuestData["TestBuddy"] or {}

    if unitName and unitId and questId then
        unitId = tonumber(unitId)
        questId = tonumber(questId)
        partyQuestData["TestBuddy"][unitName] = {
            {
                quest = "Test Quest",
                objective = "Kill " .. unitName,
                current = 3,
                total = 10,
                questId = questId,
                targetId = unitId,
                targetType = "U"
            }
        }
        RenderPartyQuestPins()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Injected fake party progress + pin for '" .. unitName
            .. "' (unit " .. unitId .. ", quest " .. questId .. ") from TestBuddy. Requires showPartyQuestPins enabled and unit "
            .. unitId .. " to have known spawn coordinates.")
    else
        partyQuestData["TestBuddy"][msg] = {
            {
                quest = "Test Quest",
                objective = "Kill " .. msg,
                current = 3,
                total = 10
            }
        }
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-turtle:|r Injected fake party progress for '" .. msg .. "' from TestBuddy. Mouseover it to check the tooltip.")
    end
end
