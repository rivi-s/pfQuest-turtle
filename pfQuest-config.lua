local function RebuildConfigUI()
    if not pfQuestConfig or not pfQuestConfig.RebuildConfigUI then
        return false
    end
    pfQuestConfig:RebuildConfigUI()
    pfQuestConfig:SetScale(math.min(1.0, 0.6 / UIParent:GetEffectiveScale()))
    if ResizeArrow then ResizeArrow() end
    return true
end

pfQuest.RebuildConfigUI = RebuildConfigUI

local configFrame = CreateFrame("Frame")
configFrame:RegisterEvent("VARIABLES_LOADED")
configFrame:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        local timer = 0
        self:SetScript("OnUpdate", function()
            timer = timer + 1

            if timer > 10 then
                if RebuildConfigUI() then
                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                elseif timer > 300 then
                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Config UI rebuild failed")
                end
            end
        end)
    end
end)
