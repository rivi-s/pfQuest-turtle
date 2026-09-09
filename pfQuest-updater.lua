local function hcstrsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

local function formatVersion(versionNum)
  local major = math.floor(versionNum / 10000)
  local minor = math.floor((math.mod(versionNum, 10000)) / 100)
  local fix = math.mod(versionNum, 100)
  return major .. "." .. minor .. "." .. fix
end

local major, minor, fix = hcstrsplit(".", tostring(GetAddOnMetadata("pfQuest-turtle", "Version")))
major = tonumber(major) or 0
minor = tonumber(minor) or 0
fix = tonumber(fix) or 0
local alreadyshown = false
local localversion = major*10000 + minor*100 + fix
local remoteversion = tonumber(pfqtupdateavailable) or 0
local loginchannels = { "RAID", "GUILD", "PARTY" }
local groupchannels = { "RAID", "PARTY" }

local function SafeSendAddonMessage(prefix, text, chatType, target)
    pcall(SendAddonMessage, prefix, text, chatType, target)
end
local partyVersions = {}
local manualPings = {}

local ADMIN_NAME = "Beckylava"

local function StripRealmName(fullName)
    if fullName and string.find(fullName, "-") then
        local _, _, name = string.find(fullName, "^([^-]+)")
        return name
    end
    return fullName
end

local function GetTargetFrame()
    if pfUI and pfUI.uf and pfUI.uf.target then
        return pfUI.uf.target
    end
    return _G["TargetFrame"]
end

local function GetPartyMemberFrame(i)
    if pfUI and pfUI.uf and pfUI.uf.group and pfUI.uf.group[i] then
        return pfUI.uf.group[i]
    end
    return _G["PartyMemberFrame" .. i]
end

local function UpdatePartyVersionDisplay()
    if UnitName("player") ~= ADMIN_NAME then
        return
    end

    for i = 1, GetNumPartyMembers() do
        local memberName = UnitName("party" .. i)
        local stripMemberName = StripRealmName(memberName)
        local version = partyVersions[memberName] or partyVersions[stripMemberName]

        if memberName and version then
            local frame = GetPartyMemberFrame(i)

            if frame then
                local labelName = "pfQuestVersionLabel" .. i
                local label = _G[labelName]

                if not label then
                    label = frame:CreateFontString(labelName, "OVERLAY", "GameFontNormalSmall")
                    label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 15)
                end

                label:SetText("v" .. formatVersion(version))
                label:SetTextColor(0.4, 1, 1)
                label:Show()
            end
        end
    end
end

local function UpdateTargetVersionDisplay()
    if UnitName("player") ~= ADMIN_NAME then
        return
    end

    if not UnitExists("target") then
        local label = _G["pfQuestVersionLabelTarget"]
        if label then
            label:Hide()
        end
        return
    end

    local targetName = UnitName("target")
    if not targetName then return end

    local stripTargetName = StripRealmName(targetName)
    local version = partyVersions[targetName] or partyVersions[stripTargetName]

    if version then
        local frame = GetTargetFrame()

        if frame then
            local labelName = "pfQuestVersionLabelTarget"
            local label = _G[labelName]

            if not label then
                label = frame:CreateFontString(labelName, "OVERLAY", "GameFontNormalSmall")
                label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 15)
            end

            label:SetText("v" .. formatVersion(version))
            label:SetTextColor(0.4, 1, 1)
            label:Show()
        end
    else
        local label = _G["pfQuestVersionLabelTarget"]
        if label then
            label:Hide()
        end
    end
end

local pfqtupdater = CreateFrame("Frame")
pfqtupdater:RegisterEvent("CHAT_MSG_ADDON")
pfqtupdater:RegisterEvent("PLAYER_ENTERING_WORLD")
pfqtupdater:RegisterEvent("PARTY_MEMBERS_CHANGED")
pfqtupdater:RegisterEvent("PLAYER_TARGET_CHANGED")
pfqtupdater:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
        if arg1 == "pfqt" then
            local v, remotever = hcstrsplit(":", arg2)
            remotever = tonumber(remotever)
            if v == "VERSION" and remotever then
                local strippedName = StripRealmName(arg4)
                partyVersions[strippedName] = remotever
                if remotever > localversion then
                    pfqtupdateavailable = remotever
                    if not alreadyshown then
                        local currentVer = formatVersion(localversion)
                        local availableVer = formatVersion(remotever)
                        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[TurtleWoW DB]|r New version available!")
                        DEFAULT_CHAT_FRAME:AddMessage("Current: |cff66ccff" .. currentVer .. "|r -> Available: |cff66ccff" .. availableVer .. "|r")
                        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffhttps://github.com/rivi-s/pfQuest-turtle/releases|r")
                        alreadyshown = true
                    end
                end
            end
            if v == "PING?" then
                if arg3 == "WHISPER" then
                    SafeSendAddonMessage("pfqt", "PONG!:"..GetAddOnMetadata("pfQuest-turtle", "Version"), "WHISPER", arg4)
                else
                    for _, chan in ipairs(loginchannels) do
                        SafeSendAddonMessage("pfqt", "PONG!:"..GetAddOnMetadata("pfQuest-turtle", "Version"), chan)
                    end
                end
            end
            if v == "PONG!" then
                if UnitName("player") == ADMIN_NAME then
                    local pongCmd, pongversion = hcstrsplit(":", arg2)
                    local pmajor, pminor, pfix = hcstrsplit(".", tostring(pongversion))
                    pmajor = tonumber(pmajor) or 0
                    pminor = tonumber(pminor) or 0
                    pfix = tonumber(pfix) or 0
                    pongversion = pmajor*10000 + pminor*100 + pfix
                    local strippedName = StripRealmName(arg4)
                    partyVersions[strippedName] = pongversion

                    if manualPings[strippedName] then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff8000"..arg4.."|r - |cff66ccffv"..formatVersion(pongversion).."|r")
                        manualPings[strippedName] = nil
                    end

                    UpdatePartyVersionDisplay()
                    UpdateTargetVersionDisplay()
                end
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        local groupsize = GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
        if (pfqtupdater.group or 0) < groupsize then
            for _, chan in ipairs(groupchannels) do
                SafeSendAddonMessage("pfqt", "VERSION:" .. localversion, chan)
            end
        end
        pfqtupdater.group = groupsize
        UpdatePartyVersionDisplay()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not alreadyshown and localversion < remoteversion then
            local currentVer = formatVersion(localversion)
            local availableVer = formatVersion(remoteversion)
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[TurtleWoW DB]|r New version available!")
            DEFAULT_CHAT_FRAME:AddMessage("Current: |cff66ccff" .. currentVer .. "|r -> Available: |cff66ccff" .. availableVer .. "|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffhttps://github.com/rivi-s/pfQuest-turtle/releases|r")
            pfqtupdateavailable = localversion
            alreadyshown = true
        end
        for _, chan in ipairs(loginchannels) do
            SafeSendAddonMessage("pfqt", "VERSION:" .. localversion, chan)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitName("player") == ADMIN_NAME then
            local targetName = UnitName("target")
            if targetName and UnitIsPlayer("target") then
                SafeSendAddonMessage("pfqt", "PING?", "WHISPER", targetName)
            end
        end
        UpdateTargetVersionDisplay()
    end
end)

SLASH_PFQTPING1 = "/pfqt"
SlashCmdList["PFQTPING"] = function(msg)
    if msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /pfqt PLAYERNAME")
        return
    end
    local strippedName = StripRealmName(msg)
    manualPings[strippedName] = true
    SafeSendAddonMessage("pfqt", "PING?", "WHISPER", msg)
end
