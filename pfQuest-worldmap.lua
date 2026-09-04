local original_UpdateNodes = pfMap.UpdateNodes
local original_UpdateNode = pfMap.UpdateNode

local continentPins = {}
local maxContinentPins = 2000

local CONTINENT_DEBUG = false
local function DebugPrint(msg)
    if CONTINENT_DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[ContinentPins]|r " .. msg)
    end
end

-- ============================================================================
-- WorldMapArea-style zone bounding boxes, in world coordinates.
-- Format: {width, height, left, top}
-- ============================================================================
local mapData = {
    -- Eastern Kingdoms zones (instance 0)
    [1429] = {3470.84, 2314.62, 1535.42, -7939.58},     -- Elwynn Forest
    [1436] = {3500.00, 2333.3, 3016.67, -9400},         -- Westfall
    [1433] = {2170.84, 1447.9, -1570.83, -8575},        -- Redridge Mountains
    [1431] = {2700.00, 1800.03, 833.333, -9716.67},     -- Duskwood
    [1434] = {6381.25, 4254.1, 2220.83, -11168.8},      -- Stranglethorn Vale
    [1453] = {1737.50, 1158.34, 1722.92, -7995.83},     -- Stormwind City
    [1426] = {4925.00, 3283.34, 1802.08, -3877.08},     -- Dun Morogh
    [1455] = {790.63, 527.61, -713.591, -4569.24},      -- Ironforge
    [1432] = {2758.33, 1839.58, -1993.75, -4487.5},     -- Loch Modan
    [1437] = {4135.42, 2756.25, -389.583, -2147.92},    -- Wetlands
    [1424] = {3200.00, 2133.33, 1066.67, 400},          -- Hillsbrad Foothills
    [1416] = {2800.00, 1866.667, 783.333, 1500},        -- Alterac Mountains
    [1417] = {3600.00, 2400.00, -866.667, -133.333},    -- Arathi Highlands
    [1425] = {3850.00, 2566.67, -1575, 1466.67},        -- The Hinterlands
    [1420] = {4518.75, 3012.5, 3033.33, 3837.5},        -- Tirisfal Glades
    [1421] = {4200.00, 2800.00, 3450, 1666.67},         -- Silverpine Forest
    [1458] = {959.38, 640.1, 873.193, 1877.94},         -- Undercity
    [1422] = {4300.00, 2866.67, 416.667, 3366.67},      -- Western Plaguelands
    [1423] = {4031.25, 2687.5, -2287.5, 3704.17},       -- Eastern Plaguelands
    [1418] = {2487.50, 1658.34, -2079.17, -5889.58},    -- Badlands
    [1427] = {2231.253, 1487.5, -322.917, -6100},       -- Searing Gorge
    [1428] = {2929.163, 1952.08, -266.667, -7031.25},   -- Burning Steppes
    [1435] = {2293.75, 1529.17, -2222.92, -9620.83},    -- Swamp of Sorrows
    [1419] = {3350.00, 2233.30, -1241.67, -10566.7},    -- Blasted Lands
    [1430] = {2500.00, 1666.63, -833.333, -9866.67},    -- Deadwind Pass
    -- Kalimdor zones (instance 1)
    [1438] = {5091.66, 3393.7, 3814.58, 11831.2},       -- Teldrassil
    [1457] = {1058.33, 705.71, 2938.36, 10238.3},       -- Darnassus
    [1439] = {6550.00, 4366.66, 2941.67, 8333.33},      -- Darkshore
    [1440] = {5766.67, 3843.75, 1700, 4672.92},         -- Ashenvale
    [1442] = {4883.33, 3256.25, 3245.83, 2916.67},      -- Stonetalon Mountains
    [1413] = {10133.34, 6756.25, 2622.92, 1612.5},      -- The Barrens
    [1411] = {5287.5, 3525, -1962.5, 1808.33},          -- Durotar
    [1454] = {1402.61, 935.42, -3680.6, 2273.88},       -- Orgrimmar
    [1412] = {5137.5, 3425.00, 2047.92, -272.917},      -- Mulgore
    [1456] = {1043.75, 695.83, 516.667, -850},          -- Thunder Bluff
    [1443] = {4495.83, 2997.91, 4233.33, 452.083},      -- Desolace
    [1444] = {6950.00, 4633.33, 5441.67, -2366.67},     -- Feralas
    [1441] = {4400.00, 2933.33, -433.333, -3966.67},    -- Thousand Needles
    [1446] = {6900.00, 4600.00, -218.75, -5875},        -- Tanaris
    [1449] = {3700.00, 2466.66, 533.333, -5966.67},     -- Un'Goro Crater
    [1451] = {3483.33, 2322.92, 2537.5, -5958.33},      -- Silithus
    [1445] = {5250.00, 3500.00, -975, -2033.33},        -- Dustwallow Marsh
    [1452] = {7100.00, 4733.33, -316.667, 8533.33},     -- Winterspring
    [1447] = {5070.84, 3381.25, -3277.08, 5341.67},     -- Azshara
    [1448] = {5750.00, 3833.33, 1641.67, 7133.33},      -- Felwood
    [1450] = {2308.33, 1539.59, -1381.25, 8491.67},     -- Moonglade
    -- Continents
    [1415] = {40500.00, 23700.00, 18500.00, 7500.00},  -- Eastern Kingdoms continent
    [1414] = {36799.81, 24533.20, 17066.60, 12799.90},  -- Kalimdor continent
}

local zoneToUiMapID = {
    -- Eastern Kingdoms
    [12] = 1429, [40] = 1436, [44] = 1433, [10] = 1431, [33] = 1434,
    [1519] = 1453, [1] = 1426, [1537] = 1455, [38] = 1432, [11] = 1437,
    [267] = 1424, [36] = 1416, [45] = 1417, [47] = 1425, [85] = 1420,
    [130] = 1421, [1497] = 1458, [28] = 1422, [139] = 1423, [3] = 1418,
    [51] = 1427, [46] = 1428, [8] = 1435, [4] = 1419, [41] = 1430,
    -- Kalimdor
    [141] = 1438, [1657] = 1457, [148] = 1439, [331] = 1440, [406] = 1442,
    [17] = 1413, [14] = 1411, [1637] = 1454, [215] = 1412, [1638] = 1456,
    [405] = 1443, [357] = 1444, [400] = 1441, [440] = 1446, [490] = 1449,
    [1377] = 1451, [15] = 1445, [618] = 1452, [16] = 1447, [361] = 1448,
    [493] = 1450,
}

-- Custom zones are not represented by Blizzard's WorldMapArea data. Their
-- normalized bounds are measured from the client continent map; add future
-- custom-zone calibrations here without altering the projection code.
local customContinentTransforms = {
    -- Alah'Thalas: Eastern Kingdoms. Fitted from Warden Sira Moonwarden
    -- (26.7 / 25.9 -> 50.9 / 13.0) and Marrondra
    -- (35.7 / 32.5 -> 51.3 / 13.3).
    [2040] = { continent = 2, left = 0.49713, top = 0.11823, width = 0.04444, height = 0.04545 },
    -- Moonwhisper Coast: north-east of Kalimdor, visible on the client map.
    -- Calibrated against Gordnak (51.89 / 36.61) at Kalimdor 61.1 / 18.9.
    [5642] = { continent = 1, left = 0.445, top = -0.016, width = 0.32, height = 0.56 },
}

local function GetZoneData(zoneID)
    return pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][zoneID]
end

-- Continent assignments (2 = Eastern Kingdoms, 1 = Kalimdor)
local zoneContinent = {
    [1] = 2, [3] = 2, [4] = 2, [8] = 2, [10] = 2, [11] = 2, [12] = 2, [28] = 2,
    [33] = 2, [36] = 2, [38] = 2, [40] = 2, [41] = 2, [44] = 2, [45] = 2, [46] = 2,
    [47] = 2, [51] = 2, [85] = 2, [130] = 2, [139] = 2, [267] = 2, [1497] = 2,
    [1519] = 2, [1537] = 2,
    [14] = 1, [15] = 1, [16] = 1, [17] = 1, [141] = 1, [148] = 1, [215] = 1,
    [331] = 1, [357] = 1, [361] = 1, [400] = 1, [405] = 1, [406] = 1, [440] = 1,
    [490] = 1, [493] = 1, [618] = 1, [1377] = 1, [1637] = 1, [1638] = 1, [1657] = 1,
}

local function GetZoneContinent(zoneID)
    local custom = customContinentTransforms[zoneID]
    if custom then
        return custom.continent
    end

    if zoneContinent[zoneID] then
        return zoneContinent[zoneID]
    end

    local zoneData = GetZoneData(zoneID)
    if zoneData and zoneData[1] then
        local continent = zoneData[1]
        if continent == 0 then
            continent = 2
        elseif continent == 1 then
            continent = 1
        else
            return nil
        end

        zoneContinent[zoneID] = continent
        return continent
    end

    return nil
end

local function ZoneToWorld(x, y, zoneID)
    local uiMapID = zoneToUiMapID[zoneID]
    if not uiMapID then
        return nil, nil
    end
    local data = mapData[uiMapID]
    if not data then
        return nil, nil
    end

    local worldX = data[3] - data[1] * (x / 100)
    local worldY = data[4] - data[2] * (y / 100)

    return worldX, worldY
end

-- continent: 1 = Kalimdor, 2 = Eastern Kingdoms
local function WorldToContinent(worldX, worldY, continent)
    local contData = mapData[continent == 1 and 1414 or 1415]
    if not contData then
        return nil, nil
    end

    local x = (contData[3] - worldX) / contData[1]
    local y = (contData[4] - worldY) / contData[2]

    return x, y
end

local function ZoneToContinent(x, y, zoneID, continent)
    local custom = customContinentTransforms[zoneID]
    if custom then
        if custom.continent ~= continent then
            return nil, nil
        end
        return custom.left + custom.width * (x / 100), custom.top + custom.height * (y / 100)
    end

    local worldX, worldY = ZoneToWorld(x, y, zoneID)
    if not worldX or not worldY then
        return nil, nil
    end
    return WorldToContinent(worldX, worldY, continent)
end

local function NodeAnimate(self, max)
    return
end

local inverseMapScale = 1.0
local function ResizeContinentNode(frame)
    if not frame.icon then
        frame.defsize = tonumber(pfQuest_config["continentNodeSize"]) or 12
        frame.defsize = frame.defsize * inverseMapScale
    else
        frame.defsize = tonumber(pfQuest_config["continentUtilityNodeSize"]) or 14
        frame.defsize = (frame.defsize - 2) * inverseMapScale + 2
    end
    frame:SetWidth(frame.defsize)
    frame:SetHeight(frame.defsize)
    frame.hl:SetWidth(frame.defsize)
    frame.hl:SetHeight(frame.defsize)
end

local lastResize = 0
local doResize = false

local nodeResizeFrame = CreateFrame("Frame")
nodeResizeFrame:SetScript("OnUpdate", function()
    lastResize = lastResize + (arg1 or 0)
    if doResize and lastResize >= 1 then
        lastResize = 0
        doResize = false

        pfMap:UpdateNodes()

        local i = 1
        if continentPins then
            while continentPins[i] and continentPins[i]:IsShown() do
                ResizeContinentNode(continentPins[i])
                i = i + 1
            end
        end
    end
end)

local function ResizeContinentNodes()
    doResize = true
end

local function OnMapScaleChanged(frame, scale, originalfunction)
    originalfunction(frame, scale)

    local newInverseScale = 1.0 / WorldMapButton:GetEffectiveScale()
    if (inverseMapScale ~= newInverseScale) then
        inverseMapScale = newInverseScale
        ResizeContinentNodes()
    end
end

local originalWorldMapFrame_SetScale = WorldMapFrame.SetScale
WorldMapFrame.SetScale = function(frame, scale)
    OnMapScaleChanged(frame, scale, originalWorldMapFrame_SetScale)
end
local originalWorldMapDetailFrame_SetScale = WorldMapDetailFrame.SetScale
WorldMapDetailFrame.SetScale = function(frame, scale)
    OnMapScaleChanged(frame, scale, originalWorldMapDetailFrame_SetScale)
end
local originalWorldMapButton_SetScale = WorldMapButton.SetScale
WorldMapButton.SetScale = function(frame, scale)
    OnMapScaleChanged(frame, scale, originalWorldMapButton_SetScale)
end

local function CreateContinentPin(index)
    if not continentPins[index] then
        local pin = CreateFrame("Button", "pfQuestContinentPin" .. index, WorldMapButton)

        pin.tex = pin:CreateTexture(nil, "BACKGROUND")
        pin.tex:SetAllPoints(pin)

        pin.pic = pin:CreateTexture(nil, "BORDER")
        pin.pic:SetPoint("TOPLEFT", pin, "TOPLEFT", 1, -1)
        pin.pic:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -1, 1)

        pin.hl = pin:CreateTexture(nil, "OVERLAY")
        pin.hl:SetTexture(pfQuestConfig.path .. "\\img\\track")
        pin.hl:SetPoint("TOPLEFT", pin, "TOPLEFT", -5, 5)
        pin.hl:Hide()

        pin.defalpha = 1
        pin.Animate = NodeAnimate
        pin.dt = 0

        if pfQuest_config["continentClickThrough"] == "1" then
            local function CheckTooltip(elapsed)
                if not this:IsVisible() then return end

                local x, y = GetCursorPosition()
                local scale = this:GetEffectiveScale()
                x = x / scale
                y = y / scale

                local left = this:GetLeft()
                local right = this:GetRight()
                local top = this:GetTop()
                local bottom = this:GetBottom()

                local isMouseOver = false
                if left and right and top and bottom then
                    isMouseOver = (x >= left and x <= right and y >= bottom and y <= top)
                end

                if isMouseOver and not this.wasMouseOver then
                    if this.node then
                        pfMap.NodeEnter()
                    end
                    this.wasMouseOver = true
                elseif not isMouseOver and this.wasMouseOver then
                    this.pulse = 1
                    this.mod = 1
                    this:SetWidth(this.defsize)
                    this:SetHeight(this.defsize)
                    pfMap.NodeLeave()
                    this.wasMouseOver = false
                end
            end

            pin:SetScript("OnUpdate", function()
                if IsControlKeyDown() then
                    if not this.mouseEnabled then
                        this:EnableMouse(true)
                        this:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                        this.mouseEnabled = true
                    end
                else
                    if this.mouseEnabled ~= false then
                        this:EnableMouse(false)
                        this:RegisterForClicks()
                        this.mouseEnabled = false
                    end
                end

                CheckTooltip(arg1)
            end)

            pin:SetScript("OnClick", function()
                if IsControlKeyDown() and this.node then
                    if pfMap.NodeClick then
                        pfMap.NodeClick()
                    end
                end
            end)
        else
            pin:EnableMouse(true)
            pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            pin:SetScript("OnEnter", function()
                if CONTINENT_DEBUG then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[ContinentPins]|r OnEnter fired: pin=" .. tostring(this:GetName()) .. " hasNode=" .. tostring(this.node ~= nil) .. " spawn=" .. tostring(this.spawn) .. " level=" .. tostring(this:GetFrameLevel()) .. " strata=" .. tostring(this:GetFrameStrata()))
                end
                if this.node then
                    pfMap.NodeEnter()
                end
            end)

            pin:SetScript("OnLeave", function()
                this.pulse = 1
                this.mod = 1
                this:SetWidth(this.defsize)
                this:SetHeight(this.defsize)
                pfMap.NodeLeave()
            end)

            pin:SetScript("OnClick", function()
                if this.node then
                    if pfMap.NodeClick then
                        pfMap.NodeClick()
                    end
                end
            end)
        end

        continentPins[index] = pin
    end
    return continentPins[index]
end

function pfMap:UpdateNode(frame, node, color, obj, distance)
    original_UpdateNode(self, frame, node, color, obj, distance)

    if obj == "minimap" then
        return
    end

    ResizeContinentNode(frame)
end

local function GetGrayLevel(charLevel)
    if charLevel <= 5 then
        return 0
    elseif charLevel <= 49 then
        return charLevel - math.floor(charLevel / 10) - 5
    elseif charLevel == 50 then
        return 40
    elseif charLevel <= 59 then
        return charLevel - math.floor(charLevel / 5) - 1
    else
        return charLevel - 9
    end
end

-- Where each continent sits within the combined world-view canvas.
-- Same {width, height, left, top} format as the mapData entries above,
local IDENTITY_LAYOUT = {1, 1, 0, 0}
local WORLD_VIEW_LAYOUT = {
    [1] = {0.85, 0.82, -0.20, 0.06}, -- Kalimdor (left)
    [2] = {0.85, 0.82, 0.35, 0.06}, -- Eastern Kingdoms (right)
}

local function PlaceContinentPins(continent, layout, pinCount, playerLevel, processedQuests, stats)
    for addon, addonData in pairs(pfMap.nodes) do
        for zID, zoneNodes in pairs(addonData) do
            stats.zonesSeen = stats.zonesSeen + 1
            local zoneCont = GetZoneContinent(zID)
            if zoneCont == continent then
                stats.zonesMatched = stats.zonesMatched + 1
                local uiMapID = zoneToUiMapID[zID]
                if customContinentTransforms[zID] or (uiMapID and mapData[uiMapID]) then
                    stats.zonesWithUiMapID = stats.zonesWithUiMapID + 1
                    for coords, node in pairs(zoneNodes) do
                        local skipNode = false
                        local questKey = nil

                        for title, data in pairs(node) do
                            local needsDeduplication = false
                            local isUtilityNPC = false

                            if data.addon and string.find(data.addon, "TRACK_") then
                                -- avoid over populating continent maps with crap make zone only
                                local allowedTracks = {
                                    "TRACK_FLIGHT", "TRACK_AUCTIONEER", "TRACK_BANKER", "TRACK_BATTLEMASTER",
                                    "TRACK_INNKEEPER", "TRACK_MAILBOX", "TRACK_STABLEMASTER",
                                    "TRACK_SPIRITHEALER", "TRACK_MEETINGSTONE",
                                }

                                local isAllowed = false
                                for _, track in pairs(allowedTracks) do
                                    if string.find(data.addon, track) then
                                        isAllowed = true
                                        break
                                    end
                                end

                                if isAllowed then
                                    isUtilityNPC = true
                                else
                                    skipNode = true
                                    break
                                end
                            end

                            -- avoid duplicate pins for zone/city pairs that overlap
                            if
                                (zID == 141 or zID == 1657) or (zID == 12 or zID == 1519) or
                                    (zID == 1 or zID == 1537) or (zID == 14 or zID == 1637) or
                                    (zID == 215 or zID == 1638) or (zID == 85 or zID == 1497)
                            then
                                needsDeduplication = true

                                if zID == 141 or zID == 1657 then
                                    questKey = title .. "_teldrassil"
                                elseif zID == 12 or zID == 1519 then
                                    questKey = title .. "_stormwind"
                                elseif zID == 1 or zID == 1537 then
                                    questKey = title .. "_ironforge"
                                elseif zID == 14 or zID == 1637 then
                                    questKey = title .. "_orgrimmar"
                                elseif zID == 215 or zID == 1638 then
                                    questKey = title .. "_thunderbluff"
                                elseif zID == 85 or zID == 1497 then
                                    questKey = title .. "_undercity"
                                end
                            end

                            if needsDeduplication and questKey and processedQuests[questKey] then
                                skipNode = true
                                break
                            end

                            local questLevel = tonumber(data.qlvl) or tonumber(data.lvl) or 0
                            local minLevel = tonumber(data.min) or 0

                            if not isUtilityNPC then
                                if pfQuest_config["showlowlevel"] == "0" then
                                    if questLevel > 0 and questLevel <= GetGrayLevel(playerLevel) then
                                        if not (data.texture and string.find(data.texture, "complete")) then
                                            skipNode = true
                                            break
                                        end
                                    end
                                end

                                if minLevel > playerLevel + (pfQuest_config["showhighlevel"] == "1" and 3 or 0) then
                                    if not (data.texture and string.find(data.texture, "complete")) then
                                        skipNode = true
                                        break
                                    end
                                end

                                if pfQuest_config["showlowlevel"] == "0" then
                                    if minLevel <= 1 and questLevel <= GetGrayLevel(playerLevel) then
                                        if not (data.texture and string.find(data.texture, "complete")) then
                                            skipNode = true
                                            break
                                        end
                                    end
                                end
                            end

                            if needsDeduplication and questKey and not skipNode then
                                processedQuests[questKey] = true
                            end
                        end

                        if not skipNode then
                            local _, _, strx, stry = strfind(coords, "(.*)|(.*)")
                            local zoneX = tonumber(strx)
                            local zoneY = tonumber(stry)

                            if zoneX and zoneY then
                                local contX, contY = ZoneToContinent(zoneX, zoneY, zID, continent)
                                if contX and contY then
                                    stats.nodesConverted = stats.nodesConverted + 1
                                    if contX and contY and contX >= 0 and contX <= 1 and contY >= 0 and contY <= 1 then
                                        pinCount = pinCount + 1
                                        if pinCount > maxContinentPins then
                                            break
                                        end

                                        local worldMapX = layout[3] + layout[1] * contX
                                        local worldMapY = layout[4] + layout[2] * contY

                                        local pin = CreateContinentPin(pinCount)
                                        pin.node = node
                                        pin.sourceContinent = continent

                                        pfMap:UpdateNode(pin, node, nil, nil, nil)

                                        ResizeContinentNode(pin)

                                        pin:ClearAllPoints()
                                        pin:SetPoint(
                                            "CENTER",
                                            WorldMapButton,
                                            "TOPLEFT",
                                            worldMapX * WorldMapButton:GetWidth(),
                                            -worldMapY * WorldMapButton:GetHeight()
                                        )
                                        pin:Show()

                                        if CONTINENT_DEBUG and not stats.zonesSampled[zID] then
                                            stats.zonesSampled[zID] = true
                                            local zoneName = pfDB and pfDB["zones"] and pfDB["zones"]["loc"] and pfDB["zones"]["loc"][zID] or "?"
                                            DebugPrint("zone sample: continent=" .. continent .. " zID=" .. tostring(zID) .. " name=" .. tostring(zoneName) .. " contXY=" .. string.format("%.3f,%.3f", contX, contY) .. " worldMapXY=" .. string.format("%.3f,%.3f", worldMapX, worldMapY) .. " screenXY=" .. string.format("%.0f,%.0f", worldMapX * WorldMapButton:GetWidth(), worldMapY * WorldMapButton:GetHeight()))
                                        end
                                    elseif not stats.sampledOutOfBounds then
                                        stats.sampledOutOfBounds = true
                                        DebugPrint("sample out-of-bounds: continent=" .. continent .. " zID=" .. tostring(zID) .. " zoneXY=" .. tostring(zoneX) .. "," .. tostring(zoneY) .. " contXY=" .. tostring(contX) .. "," .. tostring(contY))
                                    end
                                end
                            end
                        else
                            stats.nodesFiltered = stats.nodesFiltered + 1
                        end
                    end
                    if pinCount >= maxContinentPins then
                        break
                    end
                end
            end
        end
        if pinCount >= maxContinentPins then
            break
        end
    end

    return pinCount
end

function pfMap:UpdateNodes()
    local continent = GetCurrentMapContinent()
    local zone = GetCurrentMapZone()
    local mapName = GetMapInfo and GetMapInfo() or "?"

    original_UpdateNodes(self)

    for i = 1, maxContinentPins do
        if continentPins[i] then
            continentPins[i]:Hide()
            continentPins[i].node = nil
            continentPins[i].sourceContinent = nil
        end
    end

    DebugPrint("UpdateNodes: continent=" .. tostring(continent) .. " zone=" .. tostring(zone) .. " mapName=" .. tostring(mapName) .. " configOn=" .. tostring(pfQuest_config["continentPins"]))

    if pfQuest_config["continentPins"] == "0" then
        DebugPrint("skip: continentPins disabled in config")
        return
    end

    -- continent pins only apply at the top-level view of a single continent
    -- (continent 1 or 2) or the combined world view (continent 0)
    if zone > 0 or continent < 0 or continent > 2 then
        DebugPrint("skip: not a top-level continent view (zone=" .. tostring(zone) .. " continent=" .. tostring(continent) .. ")")
        return
    end

    for _, pin in pairs(pfMap.pins) do
        if pin then
            pin:Hide()
        end
    end

    local playerLevel = UnitLevel("player")
    local processedQuests = {}
    local stats = { zonesSeen = 0, zonesMatched = 0, zonesWithUiMapID = 0, nodesFiltered = 0, nodesConverted = 0, sampledOutOfBounds = false, zonesSampled = {} }

    local pinCount = 0
    if continent == 0 then
        -- combined world view: place both continents side by side using
        -- their own layout transform (see WORLD_VIEW_LAYOUT)
        pinCount = PlaceContinentPins(1, WORLD_VIEW_LAYOUT[1], pinCount, playerLevel, processedQuests, stats)
        pinCount = PlaceContinentPins(2, WORLD_VIEW_LAYOUT[2], pinCount, playerLevel, processedQuests, stats)
    else
        pinCount = PlaceContinentPins(continent, IDENTITY_LAYOUT, pinCount, playerLevel, processedQuests, stats)
    end

    for i = pinCount + 1, maxContinentPins do
        if continentPins[i] then
            continentPins[i]:Hide()
        end
    end

    DebugPrint("done: zonesSeen=" .. stats.zonesSeen .. " zonesMatchedContinent=" .. stats.zonesMatched .. " zonesWithUiMapID=" .. stats.zonesWithUiMapID .. " nodesFiltered=" .. stats.nodesFiltered .. " nodesConverted=" .. stats.nodesConverted .. " pinsPlaced=" .. pinCount)
end

local continentPollFrame = CreateFrame("Frame")
local continentPollElapsed = 0
local lastPolledContinent, lastPolledZone
continentPollFrame:SetScript("OnUpdate", function()
    if not WorldMapFrame:IsShown() then
        return
    end

    local currentContinent = GetCurrentMapContinent()
    local currentZone = GetCurrentMapZone()

    if lastPolledContinent ~= currentContinent or lastPolledZone ~= currentZone then
        DebugPrint("poll transition: continent " .. tostring(lastPolledContinent) .. "->" .. tostring(currentContinent) .. " zone " .. tostring(lastPolledZone) .. "->" .. tostring(currentZone) .. " mapName=" .. tostring(GetMapInfo and GetMapInfo()) .. " buttonShown=" .. tostring(WorldMapButton:IsShown()))
        lastPolledContinent = currentContinent
        lastPolledZone = currentZone
    end

    continentPollElapsed = continentPollElapsed + (arg1 or 0)
    if continentPollElapsed >= 0.15 then
        continentPollElapsed = 0
        pfMap:UpdateNodes()
    end
end)

local function ExtendPfQuestConfig()
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "continentPins" then
            return
        end
    end

    table.insert(pfQuest_defconfig, { text = "|cff33ffccContinent Map|r", type = "header" })
    table.insert(pfQuest_defconfig, { text = "Display Continent Pins", default = "1", type = "checkbox", config = "continentPins" })
    table.insert(pfQuest_defconfig, { text = "Require Ctrl+Click for Pin Interaction", default = "0", type = "checkbox", config = "continentClickThrough" })
    table.insert(pfQuest_defconfig, { text = "Continent Node Size", default = "12", type = "text", config = "continentNodeSize" })
    table.insert(pfQuest_defconfig, { text = "Continent Utility Node Size", default = "14", type = "text", config = "continentUtilityNodeSize" })

    table.insert(pfQuest_defconfig, { text = "|cff33ffccQuest Filters|r", type = "header" })
    table.insert(pfQuest_defconfig, { text = "Hide Chicken Quests (CLUCK!)", default = "1", type = "checkbox", config = "hideChickenQuests" })
    table.insert(pfQuest_defconfig, { text = "Hide Felwood Corrupted Flowers", default = "1", type = "checkbox", config = "hideFelwoodFlowers" })
    table.insert(pfQuest_defconfig, { text = "Hide PvP/Battleground Quests", default = "1", type = "checkbox", config = "hidePvPQuests" })
    table.insert(pfQuest_defconfig, { text = "Hide Cloth Donation Quests", default = "0", type = "checkbox", config = "hideDonationQuests" })

    pfQuest_config["continentPins"] = pfQuest_config["continentPins"] or "1"
    pfQuest_config["continentClickThrough"] = pfQuest_config["continentClickThrough"] or "0"
    pfQuest_config["continentNodeSize"] = pfQuest_config["continentNodeSize"] or "12"
    pfQuest_config["continentUtilityNodeSize"] = pfQuest_config["continentUtilityNodeSize"] or "14"
    pfQuest_config["hideChickenQuests"] = pfQuest_config["hideChickenQuests"] or "1"
    pfQuest_config["hideFelwoodFlowers"] = pfQuest_config["hideFelwoodFlowers"] or "1"
    pfQuest_config["hidePvPQuests"] = pfQuest_config["hidePvPQuests"] or "1"
    pfQuest_config["hideDonationQuests"] = pfQuest_config["hideDonationQuests"] or "0"
end

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
end)
