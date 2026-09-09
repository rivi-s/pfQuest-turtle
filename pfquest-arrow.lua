local function ExtendPfQuestConfig()
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "arrowscale" then
            return true
        end
    end

    local insertPos = nil
    for id, data in pairs(pfQuest_defconfig) do
        if data.config and data.config == "arrow" then
            insertPos = id
            break
        end
    end

    if insertPos == nil then
        return  -- shouldn't happen but don't insert the setting at a random place either
    end

    table.insert(pfQuest_defconfig, insertPos + 1,
    {
        text = "Arrow Scale",
        default = "1.0",
        type = "text",
        config = "arrowscale",
    })

    if not pfQuest_config["arrowscale"] then
        pfQuest_config["arrowscale"] = "1.0"
    end
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
end)
if pfQuest_defconfig and pfQuest_config then ExtendPfQuestConfig() end

function ResizeArrow()
    local scale = tonumber(pfQuest_config["arrowscale"]) or 1
    scale = max(0.5, min(3.0, scale))
    scale = floor(scale * 10 + 0.5) / 10
    pfQuest_config["arrowscale"] = tostring(scale)
    pfQuest.route.arrow:SetScale(pfQuest_config["arrowscale"])
end

-- While dead/a ghost, repurpose the tracking arrow to point at your corpse
-- instead, with a random (and pointed) message, since you're not tracking
-- anything useful while dead anyway.
local corpseMessages = {
    "Skill Issue, have fun running back",
    "Git Gud Scrub",
    "You Died LOL",
    "Walk of Shame Initiated",
    "Corpse Run Express",
    "Better Luck Next Time",
    "RIP Your Repair Bill",
    "Death Tax Collector Awaits",
    "Your Body is Over There Dummy",
    "Congratulations, You're Dead",
    "Achievement Unlocked: Floor Tank",
    "Press F to Pay Respects",
    "This is Why We Can't Have Nice Things",
    "Maybe Try Reading the Tactics Next Time",
    "Outstanding Move, Chief",
    "Welcome to the Spirit World",
    "Ghost Mode: ACTIVATED",
    "That Went Well",
    "Professional Grave Digger",
    "Another Happy Landing",
    "Task Failed Successfully",
    "Speedrun: Any% Death Category",
    "You've Been Disconnected from Life",
    "Error 404: HP Not Found",
    "Critical Hit: Your Pride",
    "Respawn Timer: Your Dignity",
    "New Personal Best: Worst Decision",
    "Plot Twist: You're the Bad Guy",
    "Congratulations, You Played Yourself",
    "Tutorial Complete: How to Die",
    "Achievement: First Time?",
    "Pro Tip: Don't Die Next Time",
    "Your Performance Review: Needs Improvement",
    "Status Update: Currently Deceased",
    "That's a Bold Strategy Cotton",
    "The Afterlife Called, They're Expecting You",
    "Death Certificate: Cause of Death - Bad Decision",
}

local originalArrowOnUpdate = pfQuest.route.arrow:GetScript("OnUpdate")
local corpseMessage = ""
local wasDeadLastFrame = false

pfQuest.route.arrow:SetScript("OnUpdate", function()
    if not this.parent then return end

    local isCurrentlyDead = UnitIsDead("player") or UnitIsGhost("player")

    if isCurrentlyDead then
        if not wasDeadLastFrame then
            corpseMessage = corpseMessages[math.random(1, table.getn(corpseMessages))]
            wasDeadLastFrame = true
        end

        -- A few older 1.12 client builds do not expose corpse map coordinates.
        local cx, cy
        if GetCorpseMapPosition then
            cx, cy = GetCorpseMapPosition()
        end
        -- corpse coords are 0-1; ignore if invalid (0,0)
        if cx and cy and (cx > 0 or cy > 0) then
            local xplayer, yplayer = GetPlayerMapPosition("player")
            local dx = (cx - xplayer) * 100 * 1.5
            local dy = (cy - yplayer) * 100

            local corpseDistance = ceil(math.sqrt(dx * dx + dy * dy) * 100) / 100

            local dir = atan2(dx, -dy)
            dir = dir > 0 and (2 * math.pi) - dir or -dir
            if dir < 0 then dir = dir + 360 end
            local angle = math.rad(dir) - pfQuestCompat.GetPlayerFacing()

            -- rotate the arrow model to point at corpse
            -- Lua 5.0 (the 1.12 client) has no % operator.
            local cell = math.mod(floor(angle / (2 * math.pi) * 108 + .5), 108)
            local col = math.mod(cell, 9)
            local row = floor(cell / 9)
            this.model:SetTexCoord(
                (col * 56) / 512, ((col + 1) * 56) / 512,
                (row * 42) / 512, ((row + 1) * 42) / 512
            )

            this.title:SetText("Corpse")
            this.description:SetText("|cffff0000" .. corpseMessage .. "|r")
            this.distance:SetText("|cffaaaaaa" .. (pfQuest_Loc["Distance"] or "Distance") .. ": " .. string.format("%.1f", corpseDistance))

            this:Show()
            return
        end
    else
        if wasDeadLastFrame then
            wasDeadLastFrame = false
            corpseMessage = ""
        end
    end

    if originalArrowOnUpdate then originalArrowOnUpdate() end
end)
