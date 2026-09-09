local function ExtendPfQuestConfig()
    -- Check if already added (prevents duplicates)
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "autoQuests" then
            return true
        end
    end

    table.insert(
        pfQuest_defconfig,
        {
            text = "|cff33ffccQuest automation|r",
            type = "header"
        }
    )

    table.insert(pfQuest_defconfig,
    {
        text = "Automatically accept and complete quests",
        default = "0",
        type = "checkbox",
        config = "autoQuests"
    })

    table.insert(pfQuest_defconfig,
    {
        text = "Skip accepting low level quests",
        default = "0",
        type = "checkbox",
        config = "autoQuestsSkipLowLevel"
    })

    table.insert(pfQuest_defconfig,
    {
        text = "Automate runecloth donations",
        default = "0",
        type = "checkbox",
        config = "automateRuneclothDonations"
    })

    if not pfQuest_config["autoQuests"] then
        pfQuest_config["autoQuests"] = "0"
    end

    if not pfQuest_config["autoQuestsSkipLowLevel"] then
        pfQuest_config["autoQuestsSkipLowLevel"] = "1"
    end

    if not pfQuest_config["automateRuneclothDonations"] then
        pfQuest_config["automateRuneclothDonations"] = "0"
    end

    return true
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
end)
if pfQuest_defconfig and pfQuest_config then ExtendPfQuestConfig() end

local questLogFrame = CreateFrame("Frame")
questLogFrame:RegisterEvent("QUEST_DETAIL")
questLogFrame:RegisterEvent('GOSSIP_SHOW')
questLogFrame:RegisterEvent('QUEST_COMPLETE')
questLogFrame:RegisterEvent('QUEST_GREETING')
questLogFrame:RegisterEvent('QUEST_PROGRESS')

-- Selecting a quest changes the dialog asynchronously. Repeated right-clicks
-- can emit another greeting/gossip event before that transition completes.
-- Use a short debounce instead of persistent state: some Turtle dialogs do not
-- emit a follow-up event, which must never leave automation locked forever.
local interactionLockedUntil = 0
local recentlyRewarded = {}
local rewardLockedUntil = 0

-- Turtle can keep a rewarded quest in the greeting/gossip list briefly after
-- GetQuestReward(). Do not select that stale row again while the server and
-- quest log catch up.
local function WasRecentlyRewarded(title)
    return title and recentlyRewarded[title] and recentlyRewarded[title] > GetTime()
end

local function RememberRewardedQuest()
    local title = GetTitleText and GetTitleText()
    if title and title ~= "" then
        recentlyRewarded[title] = GetTime() + 2
    end
end

local function BeginInteraction(kind)
    local now = GetTime()
    if now < interactionLockedUntil then
        return false
    end
    interactionLockedUntil = now + 0.25
    return true
end

local function EndInteraction()
    interactionLockedUntil = 0
end

-- Rewarding a quest can reindex the whole quest log a frame later. Re-scan
-- once it settles so another quest from the same NPC is redrawn from its own
-- current completion state instead of the just-removed quest's old slot.
local postRewardRefresh = CreateFrame("Frame")
postRewardRefresh:Hide()
postRewardRefresh.elapsed = 0
postRewardRefresh:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed < 0.35 then
        return
    end

    if pfQuest and pfQuest.UpdateQuestlog then
        pfQuest:UpdateQuestlog()
        pfQuest.updateQuestLog = true
        pfQuest.updateQuestGivers = true
    end
    if pfMap then
        pfMap.queue_update = GetTime()
    end

    -- Scripted dialogue chains can advance their next quest state after the
    -- first reward refresh. Run a second short pass before stopping so an old
    -- yellow turn-in pin cannot remain on the next unfinished quest.
    if this.passes == 0 then
        this.passes = 1
        this.elapsed = 0
        return
    end

    -- Turtle can reindex the remaining quest rows after the reward has been
    -- claimed. Redraw those active entries once, after that reindex, so a
    -- leftover unfinished quest does not retain the rewarded quest's yellow
    -- turn-in marker. This only runs following an automated reward.
    -- Rebuilding every remaining quest is useful only when the World Map is
    -- visible. Doing it immediately after a reward can hitch badly on newer
    -- quests with many objective nodes, even though no map is on screen.
    if WorldMapFrame and WorldMapFrame:IsShown() and pfQuest and pfQuest.questlog and pfDatabase and pfMap then
        for questid, data in pairs(pfQuest.questlog) do
            if type(questid) == "number" and data.qlogid and data.title then
                pfMap:DeleteNode("PFQUEST", data.title)
                pfDatabase:SearchQuestID(questid, { ["addon"] = "PFQUEST", ["qlogid"] = data.qlogid })
            end
        end
        pfMap.queue_update = GetTime()
    end

    this:Hide()
end)

local function SchedulePostRewardRefresh()
    -- This cleanup exists only to redraw a visible World Map after an
    -- automated reward. Let the normal quest-log scan handle gameplay with
    -- the map closed, avoiding a pair of expensive immediate refreshes.
    if WorldMapFrame and WorldMapFrame:IsShown() then
        postRewardRefresh.elapsed = 0
        postRewardRefresh.passes = 0
        postRewardRefresh:Show()
    end
end

local function CompleteQuestWithRewards()
    if GetNumQuestChoices() == 0 then
        GetQuestReward()
        SchedulePostRewardRefresh()
    end
end

local function SkipLowLevelQuest(isLowLevel)
    return pfQuest_config["autoQuestsSkipLowLevel"] == "1" and isLowLevel
end

local function IsAvailableQuestLowLevel(index)
    -- GetAvailableQuestInfo is not exposed by every Turtle client build.
    if GetAvailableQuestInfo then
        return GetAvailableQuestInfo(index)
    end

    -- The classic API returns title, level, then its low-level/trivial flag.
    if GetAvailableTitle then
        local _, _, isLowLevel = GetAvailableTitle(index)
        return isLowLevel
    end

    return false
end

local function IsTrivialQuest()
    local title = GetTitleText()
    return string.find(string.lower(title), "low level") ~= nil
end

-- Turtle's GetActiveTitle only returns a title. The matching quest-log row
-- does expose completion state, so use it to identify turn-ins at greetings.
local function IsGreetingQuestComplete(title)
    for qlogid = 1, 40 do
        local qtitle, _, _, header, _, complete = pfQuestCompat.GetQuestLogTitle(qlogid)
        if qtitle and not header and qtitle == title then
            return complete and true or false
        end
    end
    return false
end

-- Report/talk quests can be listed as active at their destination before
-- Turtle marks them complete. They have no objective rows, unlike incomplete
-- kill or collection quests, so they are safe to select at a quest greeting.
local function IsGreetingQuestReady(title)
    for qlogid = 1, 40 do
        local qtitle, _, _, header, _, complete = pfQuestCompat.GetQuestLogTitle(qlogid)
        if qtitle and not header and qtitle == title then
            return complete or (GetNumQuestLeaderBoards(qlogid) or 0) == 0
        end
    end
    return false
end

-- Turtle can report false from IsQuestCompletable() for simple talk/report
-- quests, even when their quest-log row is already complete. QUEST_PROGRESS
-- is only allowed to advance when either API confirms completion or the
-- selected/current quest is marked complete in the log.
local function IsQuestReadyToComplete()
    if IsQuestCompletable and IsQuestCompletable() then
        return true
    end

    if GetQuestLogSelection then
        local selection = GetQuestLogSelection()
        if selection then
            local _, _, _, header, _, complete = pfQuestCompat.GetQuestLogTitle(selection)
            if not header and complete then
                return true
            end
        end
    end

    local title = GetTitleText and GetTitleText()
    return title and IsGreetingQuestComplete(title) or false
end

-- Some Turtle chains use QUEST_PROGRESS for a scripted dialogue step. Advance
-- only an enabled Continue button; do not force ordinary incomplete quests.
local function IsQuestDialogueContinue()
    local button = QuestFrameCompleteButton
    if not button or not button:IsShown() or not button:IsEnabled() then
        return false
    end

    local text = button:GetText()
    return text == "Continue" or (CONTINUE and text == CONTINUE)
end

local function SelectFirstAvailableQuest()
    if not GetNumAvailableQuests or GetNumAvailableQuests() < 1 then
        return false
    end

    if SkipLowLevelQuest(IsAvailableQuestLowLevel(1)) then
        return false
    end

    SelectAvailableQuest(1)
    return true
end

-- Some Turtle NPCs open a normal quest greeting but expose their available
-- quests only through the gossip API (not GetNumAvailableQuests). This is
-- notably used by cross-faction/server-custom quest offerings.
local function SelectFirstGossipAvailableQuest()
    if not GetGossipAvailableQuests or not SelectGossipAvailableQuest then
        return false
    end

    local available = { GetGossipAvailableQuests() }
    if type(available[1]) ~= "string" then
        return false
    end

    SelectGossipAvailableQuest(1)
    return true
end

local function SelectFirstCompletedActiveQuest()
    if not GetNumActiveQuests then
        return false
    end

    local numActiveQuests = GetNumActiveQuests()
    for i = 1, numActiveQuests do
        local title = GetActiveTitle(i)
        if title and not WasRecentlyRewarded(title) and IsGreetingQuestReady(title) then
            SelectActiveQuest(i)
            return true
        end
    end

    return false
end

-- Gossip uses a separate quest list. Its active rows can include unfinished
-- quests, so never select one merely because it is first in the list.
local function SelectFirstCompletedGossipActiveQuest()
    if not GetGossipActiveQuests or not SelectGossipActiveQuest then
        return false
    end

    local active = { GetGossipActiveQuests() }
    local questIndex = 0
    for i = 1, table.getn(active) do
        if type(active[i]) == "string" then
            questIndex = questIndex + 1
            if not WasRecentlyRewarded(active[i]) and IsGreetingQuestReady(active[i]) then
                SelectGossipActiveQuest(questIndex)
                return true
            end
        end
    end

    return false
end

local function SelectAutoQuestGreeting()
    -- Always prefer a completed turn-in over an available quest at the same NPC.
    return SelectFirstCompletedActiveQuest() or SelectFirstAvailableQuest()
end

-- Turtle populates the greeting quest list shortly after QUEST_GREETING.
-- Retry briefly so automation does not inspect either list before it exists.
local questGreetingRetry = CreateFrame("Frame")
questGreetingRetry:Hide()
questGreetingRetry.elapsed = 0
questGreetingRetry:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed < 0.1 then
        return
    end

    if (pfQuest_config["autoQuests"] == "1" and not IsShiftKeyDown() and SelectAutoQuestGreeting()) or this.elapsed >= 1 then
        this:Hide()
    end
end)

questLogFrame:SetScript("OnEvent", function()
    if pfQuest_config["autoQuests"] == "0" or IsShiftKeyDown() then
        return
    end

    if event == "QUEST_PROGRESS" then
        EndInteraction()
        if IsQuestReadyToComplete() or IsQuestDialogueContinue() then
            CompleteQuest()
        end
    end

    if event == "QUEST_COMPLETE" then
        EndInteraction()
        if GetTime() < rewardLockedUntil then
            return
        end
        if GetNumQuestChoices() == 0 then
            -- Some Turtle clients emit QUEST_COMPLETE more than once after a
            -- reward is claimed. Guard the reward API itself, not only the
            -- greeting list, so a stale completion cannot loop.
            rewardLockedUntil = GetTime() + 2
            RememberRewardedQuest()
            GetQuestReward()
            SchedulePostRewardRefresh()
        elseif QuestFrameRewardPanel.itemChoice and QuestFrameRewardPanel.itemChoice > 0 then
            GetQuestReward(QuestFrameRewardPanel.itemChoice)
        end
    end

    if event == "QUEST_GREETING" then
        if not BeginInteraction("greeting") then
            return
        end

        -- Selecting a turn-in opens the completion dialog on the next client
        -- update. QUEST_COMPLETE below then safely claims a no-choice reward.
        if not SelectAutoQuestGreeting() then
            EndInteraction()
            questGreetingRetry.elapsed = 0
            questGreetingRetry:Show()
        end
    end

    if event == "QUEST_DETAIL" then
        EndInteraction()
        if not IsTrivialQuest() then
            AcceptQuest()
        end
    end

    if event == "GOSSIP_SHOW" and GetGossipAvailableQuests then
        if not BeginInteraction("gossip") then
            return
        end

        -- Match normal greetings: completed turn-ins always win over an
        -- available quest, and unfinished active quests are left alone.
        if SelectFirstCompletedGossipActiveQuest() then
            return
        end

        local available = { GetGossipAvailableQuests() }
        local questIndex = 0
        local i = 1
        while i <= table.getn(available) do
            if type(available[i]) == "string" then
                questIndex = questIndex + 1
                -- Turtle's custom gossip list can omit the usual boolean
                -- low-level flag, yielding title, level, title, level. Only
                -- a real boolean may be used to skip a low-level quest.
                local isLowLevel = type(available[i + 2]) == "boolean" and available[i + 2] or false
                if not SkipLowLevelQuest(isLowLevel) then
                    SelectGossipAvailableQuest(questIndex)
                    return
                end
                i = i + (type(available[i + 2]) == "boolean" and 3 or 2)
            else
                i = i + 1
            end
        end

        -- No gossip row was selected, so a new interaction should be allowed.
        EndInteraction()
    end
end)
