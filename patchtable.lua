-- Initialize all static variables
local loc = GetLocale()
local dbs = { "items", "quests", "quests-itemreq", "objects", "units", "zones", "professions", "areatrigger", "refloot" }
local noloc = { "items", "quests", "objects", "units" }

-- Patch databases to merge TurtleWoW data
local function patchtable(base, diff)
  for k, v in pairs(diff) do
    if type(v) == "string" and v == "_" then
      base[k] = nil
    else
      base[k] = v
    end
  end
end

-- Detect a typo from old clients and re-apply the typo to the zones table
-- This is a workaround which is required until all clients are updated
for id, name in pairs({GetMapZones(2)}) do
  if name == "Northwind " then
    pfDB["zones"]["enUS-turtle"][5581] = "Northwind "
  end
end

local loc_core, loc_update
for _, db in pairs(dbs) do
  if pfDB[db]["data-turtle"] then
    patchtable(pfDB[db]["data"], pfDB[db]["data-turtle"])
  end

  for loc, _ in pairs(pfDB.locales) do
    if pfDB[db][loc] and pfDB[db][loc.."-turtle"] then
      loc_update = pfDB[db][loc.."-turtle"] or pfDB[db]["enUS-turtle"]
      patchtable(pfDB[db][loc], loc_update)
    end
  end
end

loc_core = pfDB["professions"][loc] or pfDB["professions"]["enUS"]
loc_update = pfDB["professions"][loc.."-turtle"] or pfDB["professions"]["enUS-turtle"]
if loc_update then patchtable(loc_core, loc_update) end

if pfDB["minimap-turtle"] then patchtable(pfDB["minimap"], pfDB["minimap-turtle"]) end
if pfDB["meta-turtle"] then patchtable(pfDB["meta"], pfDB["meta-turtle"]) end

-- The legacy SQL importer represented some reference-loot pointers as though
-- the reference ID itself were an item drop.  Reference IDs often overlap a
-- real item ID, so this produces impossible drops in the loot panel (for
-- example, Lost Soul -> Onyxian Drake).  A leaked pointer has an exact copy of
-- its reference pool's source list; mark only those exact copies for filtering.
local function SameSourceSet(first, second)
  if not first or not second then return false end

  local count = 0
  for id in pairs(first) do
    count = count + 1
    if not second[id] then return false end
  end
  if count == 0 then return false end

  for id in pairs(second) do
    if not first[id] then return false end
  end

  return true
end

local function IsReferenceToken(item, reference)
  local hasSources = false
  for _, sourceType in pairs({ "U", "O" }) do
    if item[sourceType] or reference[sourceType] then
      if not SameSourceSet(item[sourceType], reference[sourceType]) then
        return false
      end
      hasSources = true
    end
  end
  return hasSources
end

for id, reference in pairs(pfDB["refloot"]["data"]) do
  local item = pfDB["items"]["data"][id]
  if item and IsReferenceToken(item, reference) then
    item["reference-token"] = true
  end
end

-- Detect german client patch and switch some databases
if TURTLE_DE_PATCH then
  pfDB["zones"]["loc"] = pfDB["zones"]["deDE"] or pfDB["zones"]["enUS"]
  pfDB["professions"]["loc"] = pfDB["professions"]["deDE"] or pfDB["professions"]["enUS"]
end

-- Update bitmasks to include custom races
if pfDB.bitraces then
  pfDB.bitraces[256] = "Goblin"
  pfDB.bitraces[512] = "BloodElf"
end

-- Use turtle-wow database url
pfQuest.dburl = "https://database.turtle-wow.org/?quest="

-- Disable Minimap in custom dungeon maps
function pfMap:HasMinimap(map_id)
  -- disable dungeon minimap
  local has_minimap = not IsInInstance()

  -- enable dungeon minimap if continent is less then 3 (e.g AV)
  if IsInInstance() and GetCurrentMapContinent() < 3 then
    has_minimap = true
  end

  return has_minimap
end

-- Reload all pfQuest internal database shortcuts
pfDatabase:Reload()

local function strsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

-- Complete quest id including all pre quests
local function complete(history, qid)
  -- ignore empty or broken questid
  if not qid or not tonumber(qid) then return end

  -- mark quest as complete
  local time = pfQuest_history[qid] and pfQuest_history[qid][1] or 0
  local level = pfQuest_history[qid] and pfQuest_history[qid][2] or 0
  history[qid] = { time, level }

  -- complete all quests that are closed by the selcted one
  local close = pfDB["quests"]["data"][qid] and pfDB["quests"]["data"][qid]["close"]
  if close then
    for _, qid in pairs(close) do
      if not history[qid] then complete(history, qid) end
    end
  end

  -- make sure all prequests are marked as done aswell
  local prequests = pfDB["quests"]["data"][qid] and pfDB["quests"]["data"][qid]["pre"]
  if prequests then
    for _, qid in pairs(prequests) do
      if not history[qid] then complete(history, qid) end
    end
  end
end

-- Temporary workaround for a faction group translation error

-- Add function to query for quest completion
local query = CreateFrame("Frame")
query:Hide()

query:SetScript("OnEvent", function()
  if arg1 == "TWQUEST" then
    for _, qid in pairs({strsplit(" ", arg2)}) do
      complete(this.history, tonumber(qid))
    end
  end
end)

query:SetScript("OnShow", function()
  this.history = {}
  this.time = GetTime()
  this:RegisterEvent("CHAT_MSG_ADDON")
  SendChatMessage(".queststatus", "GUILD")
end)

query:SetScript("OnHide", function()
  this:UnregisterEvent("CHAT_MSG_ADDON")

  local count = 0
  for qid in pairs(this.history) do count = count + 1 end

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: A total of " .. count .. " quests have been marked as completed.")

  pfQuest_history = this.history
  this.history = nil

  pfQuest:ResetAll()
end)

query:SetScript("OnUpdate", function()
  if GetTime() > this.time + 3 then this:Hide() end
end)

function pfDatabase:QueryServer()
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Receiving quest data from server...")
  query:Show()
end

-- Automatically clear quest cache if new turtle quests have been found
local updatecheck = CreateFrame("Frame")
updatecheck:RegisterEvent("PLAYER_ENTERING_WORLD")
updatecheck:SetScript("OnEvent", function()
  if pfDB["quests"]["data-turtle"] then
    -- count all known turtle-wow quests
    local count = 0
    for k, v in pairs(pfDB["quests"]["data-turtle"]) do
      count = count + 1
    end

    pfQuest:Debug("TurtleWoW loaded with |cff33ffcc" .. count .. "|r quests.")

    -- check if the last count differs to the current amount of quests
    if not pfQuest_turtlecount or pfQuest_turtlecount ~= count then
      -- remove quest cache to force reinitialisation of all quests.
      pfQuest:Debug("New quests found. Reloading |cff33ffccCache|r")
      pfQuest_questcache = {}
    end

    -- write current count to the saved variable
    pfQuest_turtlecount = count
  end
end)

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

local RANK_INFO = {
  ["1"] = { text = "Elite",      r = 1, g = 0.5,  b = 0 },
  ["2"] = { text = "Rare Elite", r = 1, g = 0.42, b = 0.71 },
  ["3"] = { text = "Boss",       r = 1, g = 0,    b = 0 },
  ["4"] = { text = "Rare",       r = 1, g = 1,    b = 0 },
}

local function AddRankLine(tooltip, spawnid, spawntype)
  -- Unit and object IDs share the same number space. Looking up an object ID
  -- in the unit table can therefore show an unrelated creature rank.
  if not spawnid or spawntype ~= pfQuest_Loc["Unit"] then return end

  local units = pfDB["units"] and pfDB["units"]["data"]
  local unit = units and units[spawnid]
  local info = unit and unit["rnk"] and RANK_INFO[tostring(unit["rnk"])]
  if not info then return end

  tooltip:AddDoubleLine((pfQuest_Loc["Rank"] or "Rank") .. ":", info.text, .8, .8, .8, info.r, info.g, info.b)
end

-- A single map pin can represent several creatures at the same coordinate.
-- Keep the pin compact, but make every represented creature visible in its
-- tooltip so players know the location is shared rather than incomplete.
local function AddSharedSpawnLine(tooltip, sharedspawns, primary)
  if not sharedspawns then return end

  local names = {}
  for name in pairs(sharedspawns) do
    if name and name ~= primary then
      table.insert(names, name)
    end
  end
  if table.getn(names) == 0 then return end

  table.sort(names)
  tooltip:AddLine("Shared with: " .. table.concat(names, ", "), .7, .7, .7, true)
end

-- Helper to gather item drop source info for a quest-starting item
local function GetItemDropSources(item, items, units, objects, refloot)
  local drop_sources = {}
  local sources_with_levels = {}

  if items[item]["U"] then
    for unit, chance in pairs(items[item]["U"]) do
      local unit_name = pfDB["units"]["loc"][unit]
      if unit_name and not drop_sources[unit_name] then
        drop_sources[unit_name] = true
        local unit_level = units[unit] and units[unit]["lvl"] or "?"
        sources_with_levels[unit_name] = {level = unit_level, chance = chance}
      end
    end
  end

  if items[item]["O"] then
    for object, chance in pairs(items[item]["O"]) do
      local obj_name = pfDB["objects"]["loc"][object]
      if obj_name and not drop_sources[obj_name] then
        drop_sources[obj_name] = true
        sources_with_levels[obj_name] = {level = "Object", chance = chance}
      end
    end
  end

  if items[item]["R"] then
    for ref, chance in pairs(items[item]["R"]) do
      if refloot[ref] then
        if refloot[ref]["U"] then
          for unit in pairs(refloot[ref]["U"]) do
            local unit_name = pfDB["units"]["loc"][unit]
            if unit_name and not drop_sources[unit_name] then
              drop_sources[unit_name] = true
              local unit_level = units[unit] and units[unit]["lvl"] or "?"
              sources_with_levels[unit_name] = {level = unit_level, chance = chance}
            end
          end
        end
        if refloot[ref]["O"] then
          for object in pairs(refloot[ref]["O"]) do
            local obj_name = pfDB["objects"]["loc"][object]
            if obj_name and not drop_sources[obj_name] then
              drop_sources[obj_name] = true
              sources_with_levels[obj_name] = {level = "Object", chance = chance}
            end
          end
        end
      end
    end
  end

  -- Build display text (up to 3 sources)
  local sources_text = ""
  local source_count = 0
  local display_count = 0
  for _ in pairs(drop_sources) do
    source_count = source_count + 1
  end

  for source_name in pairs(drop_sources) do
    display_count = display_count + 1
    if display_count > 1 then sources_text = sources_text .. ", " end
    sources_text = sources_text .. source_name
    if display_count >= 3 then
      if source_count > 3 then
        sources_text = sources_text .. " (+" .. (source_count - 3) .. " more)"
      end
      break
    end
  end

  return drop_sources, sources_with_levels, sources_text
end

-- Helper to find the best map source (most spawn points) for an item
local function GetBestItemSource(item, items, units, objects, refloot)
  local best_source = nil
  local best_count = 0

  if items[item]["U"] then
    for unit, chance in pairs(items[item]["U"]) do
      if units[unit] and units[unit]["coords"] then
        local count = table.getn(units[unit]["coords"])
        if count > best_count then
          best_count = count
          best_source = {type = "unit", id = unit}
        end
      end
    end
  end

  if items[item]["O"] then
    for object, chance in pairs(items[item]["O"]) do
      if objects[object] and objects[object]["coords"] then
        local count = table.getn(objects[object]["coords"])
        if count > best_count then
          best_count = count
          best_source = {type = "object", id = object}
        end
      end
    end
  end

  if items[item]["R"] then
    for ref, chance in pairs(items[item]["R"]) do
      if refloot[ref] then
        if refloot[ref]["U"] then
          for unit in pairs(refloot[ref]["U"]) do
            if units[unit] and units[unit]["coords"] then
              local count = table.getn(units[unit]["coords"])
              if count > best_count then
                best_count = count
                best_source = {type = "unit", id = unit}
              end
            end
          end
        end
        if refloot[ref]["O"] then
          for object in pairs(refloot[ref]["O"]) do
            if objects[object] and objects[object]["coords"] then
              local count = table.getn(objects[object]["coords"])
              if count > best_count then
                best_count = count
                best_source = {type = "object", id = object}
              end
            end
          end
        end
      end
    end
  end

  return best_source
end

-- Helper to add item drop map nodes for a given quest/item
local function AddItemDropNodes(id, item, meta, maps, quests, items, units, objects, refloot, sources_text, sources_with_levels)
  local best_source = GetBestItemSource(item, items, units, objects, refloot)
  if not best_source then return maps end

  local coords_table = best_source.type == "unit" and units[best_source.id]["coords"] or objects[best_source.id]["coords"]

  local zones_coords = {}
  for _, data in pairs(coords_table) do
    local x, y, zone = unpack(data)
    if zone > 0 and not zones_coords[zone] then
      zones_coords[zone] = {x, y}
    end
  end

  for zone, coords in pairs(zones_coords) do
    local item_meta = {}
    for k, v in pairs(meta or {}) do item_meta[k] = v end

    item_meta["QTYPE"] = "ITEM_START"
    item_meta["layer"] = 4
    item_meta["texture"] = pfQuestConfig.path.."\\img\\available"

    local plevel = UnitLevel("player")
    if quests[id]["min"] and quests[id]["min"] > plevel then
      item_meta["vertex"] = { 1, .6, .6 }
      item_meta["layer"] = 2
    elseif quests[id]["lvl"] and quests[id]["lvl"] <= GetGrayLevel(plevel) then
      item_meta["vertex"] = { 1, 1, 1 }
      item_meta["layer"] = 2
    elseif quests[id]["event"] then
      item_meta["vertex"] = { .2, .8, 1 }
      item_meta["layer"] = 2
    end

    item_meta["spawn"] = pfDB["items"]["loc"][item] or UNKNOWN
    item_meta["spawnid"] = item
    item_meta["item"] = pfDB["items"]["loc"][item]
    item_meta["dropsources"] = sources_text
    item_meta["dropsources_levels"] = sources_with_levels
    item_meta["title"] = item_meta["quest"] or item_meta["spawn"]
    item_meta["zone"] = zone
    item_meta["x"] = coords[1]
    item_meta["y"] = coords[2]
    item_meta["level"] = pfQuest_Loc["N/A"]
    item_meta["spawntype"] = "Item Drop"
    item_meta["respawn"] = pfQuest_Loc["N/A"]
    item_meta["qlvl"] = quests[id]["lvl"]
    item_meta["qmin"] = quests[id]["min"]
    item_meta["description"] = pfDatabase:BuildQuestDescription(item_meta)

    maps = maps or {}
    maps[zone] = maps[zone] and maps[zone] + 1 or 1
    pfMap:AddNode(item_meta)
  end

  return maps
end

-- Item Drop System: Override SearchQuestID to show item-start quests for current quest givers
local originalSearchQuestID = pfDatabase.SearchQuestID
pfDatabase.SearchQuestID = function(self, id, meta, maps)
  maps = originalSearchQuestID(self, id, meta, maps)

  local quests = pfDB["quests"]["data"]
  local items = pfDB["items"]["data"]
  local units = pfDB["units"]["data"]
  local objects = pfDB["objects"]["data"]
  local refloot = pfDB["refloot"]["data"]

  if not quests[id] then return maps end

  if pfQuest_config["currentquestgivers"] == "1" then
    if quests[id]["start"] and not meta["qlogid"] then
      if quests[id]["start"]["I"] then
        for _, item in pairs(quests[id]["start"]["I"]) do
          if items[item] then
            local _, sources_with_levels, sources_text = GetItemDropSources(item, items, units, objects, refloot)
            maps = AddItemDropNodes(id, item, meta, maps, quests, items, units, objects, refloot, sources_text, sources_with_levels)
          end
        end
      end
    end
  end

  return maps
end

local function ItemDropQuestFilter(id, plevel, pclass, prace)
  local quests = pfDB["quests"]["data"]

  -- hide active quest
  if pfQuest.questlog[id] then return end
  -- hide completed quests
  if pfQuest_history[id] then return end
  -- hide broken quests without names
  if not pfDB.quests.loc[id] or not pfDB.quests.loc[id].T then return end

  local quest = quests[id]
  if not quest then return end

  -- hide missing pre-quests
  if quest["pre"] then
    local one_complete = nil
    for _, prequest in pairs(quest["pre"]) do
      if pfQuest_history[prequest] then
        one_complete = true
      end
    end
    if not one_complete then return end
  end

  -- hide non-available quests for your race
  if quest["race"] and not ( bit.band(quest["race"], prace) == prace ) then return end
  -- hide non-available quests for your class
  if quest["class"] and not ( bit.band(quest["class"], pclass) == pclass ) then return end
  -- hide non-available quests for your profession
  if quest["skill"] and not pfDatabase:GetPlayerSkill(quest["skill"]) then return end
  -- hide highlevel quests that are too far above player
  if quest["min"] and quest["min"] > plevel + 3 then return end

  return true
end

local originalSearchQuests = pfDatabase.SearchQuests
pfDatabase.SearchQuests = function(self, meta, maps)
  maps = originalSearchQuests(self, meta, maps)

  local quests = pfDB["quests"]["data"]
  local items = pfDB["items"]["data"]
  local units = pfDB["units"]["data"]
  local objects = pfDB["objects"]["data"]
  local refloot = pfDB["refloot"]["data"]

  local plevel = UnitLevel("player")
  local pfaction = UnitFactionGroup("player")
  pfaction = pfaction == "Horde" and "H" or pfaction == "Alliance" and "A" or "GM"

  local _, race = UnitRace("player")
  local prace = pfDatabase:GetBitByRace(race)
  local _, class = UnitClass("player")
  local pclass = pfDatabase:GetBitByClass(class)

  for id in pairs(quests) do
    if quests[id]["start"] and quests[id]["start"]["I"] and ItemDropQuestFilter(id, plevel, pclass, prace) then
      -- Additional faction check for quest enders
      local validFaction = true
      if quests[id]["end"] and quests[id]["end"]["U"] then
        validFaction = false
        for _, unit in pairs(quests[id]["end"]["U"]) do
          local unitData = units[unit]
          if pfDatabase:IsFriendly(unit) or (unitData and not unitData["fac"]) then
            validFaction = true
            break
          end
        end
      end

      if validFaction then
        for _, item in pairs(quests[id]["start"]["I"]) do
          if items[item] then
            local _, sources_with_levels, sources_text = GetItemDropSources(item, items, units, objects, refloot)

            local quest_meta = {}
            for k, v in pairs(meta or {}) do quest_meta[k] = v end
            quest_meta["quest"] = pfDB["quests"]["loc"][id] and pfDB["quests"]["loc"][id].T or UNKNOWN
            quest_meta["questid"] = id

            maps = AddItemDropNodes(id, item, quest_meta, maps, quests, items, units, objects, refloot, sources_text, sources_with_levels)
          end
        end
      end
    end
  end

  return maps
end

-- Override BuildQuestDescription to handle ITEM_START quest type
local originalBuildQuestDescription = pfDatabase.BuildQuestDescription
pfDatabase.BuildQuestDescription = function(self, meta)
  if meta and meta.QTYPE == "ITEM_START" then
    if not meta.title or not meta.quest then return meta.description end
    if meta.dropsources and meta.dropsources ~= "" then
      return string.format("Loot |cff33ffcc[%s]|r from |cff33ffcc%s|r to obtain |cff66ff66[!]|cff33ffcc %s|r", (meta.spawn or UNKNOWN), meta.dropsources, (meta.quest or UNKNOWN))
    else
      return string.format("Loot |cff33ffcc[%s]|r to obtain |cff66ff66[!]|cff33ffcc %s|r", (meta.spawn or UNKNOWN), (meta.quest or UNKNOWN))
    end
  end
  return originalBuildQuestDescription(self, meta)
end

-- Extend QuestFilter with a few title-based quest hide options (settings
-- added in pfQuest-worldmap.lua's "Quest Filters" section)
local originalQuestFilter = pfDatabase.QuestFilter
pfDatabase.QuestFilter = function(self, id, plevel, pclass, prace)
  if not originalQuestFilter(self, id, plevel, pclass, prace) then
    return
  end

  local title = pfDB.quests.loc[id] and pfDB.quests.loc[id].T

  if title then
    -- hide PvP/battleground quests
    if pfQuest_config["hidePvPQuests"] == "1" and not string.find(title, "Alteraci Shilling") and (
      string.find(title, "Warsong") or
      string.find(title, "Arathi") or
      string.find(title, "Alterac") or
      string.find(title, "Battleground") or
      string.find(title, "Call to Skirmish")
    ) then
      return
    end

    -- hide cloth donation quests
    if pfQuest_config["hideDonationQuests"] == "1" and (
      string.find(title, "A Donation of Wool") or
      string.find(title, "A Donation of Silk") or
      string.find(title, "A Donation of Mageweave") or
      string.find(title, "A Donation of Runecloth") or
      string.find(title, "Additional Runecloth")
    ) then
      return
    end

    -- hide chicken quests
    if pfQuest_config["hideChickenQuests"] == "1" and string.find(title, "CLUCK!") then
      return
    end

    -- hide Felwood corrupted flower quests
    if pfQuest_config["hideFelwoodFlowers"] == "1" and (
      title == "Corrupted Windblossom" or
      title == "Corrupted Whipper Root" or
      title == "Corrupted Songflower" or
      title == "Corrupted Night Dragon"
    ) then
      return
    end
  end

  return true
end

-- Override NodeEnter to show custom tooltips for ITEM_START nodes
local originalNodeEnter = pfMap.NodeEnter
local function AddConfiguredClickModifier(text, tooltip)
  if pfQuest_config["continentClickThrough"] == "1" and tooltip == WorldMapTooltip then
    text = string.gsub(text, "<Shift>%-Click", "<Ctrl>%-<Shift>%-Click")
    text = string.gsub(text, "Remove Nodes", "Hide Nodes")
    text = string.gsub(text, "<Alt>%-Click", "<Ctrl>%-<Alt>%-Click")
    text = string.gsub(text, "Alt%-Click", "Ctrl%-Alt%-Click")
    text = string.gsub(text, "^Click", "<Ctrl>%-Click")
  end
  return text
end

local function AddWorldMapHideHint(tooltip)
  if pfQuest_config["continentClickThrough"] == "1" and tooltip == WorldMapTooltip then
    tooltip:AddLine(pfQuest_Loc["<Ctrl>-<Shift>-Click To Hide Nodes"], .6, .6, .6)
  end
end

pfMap.NodeEnter = function()
  if not this or not this.node then
    if originalNodeEnter then originalNodeEnter() end
    return
  end

  local hasItemStart = false
  local itemStartMeta = nil
  for title, meta in pairs(this.node) do
    if meta.QTYPE == "ITEM_START" and meta.dropsources_levels then
      hasItemStart = true
      itemStartMeta = meta
      break
    end
  end

  if hasItemStart and itemStartMeta then
    local tooltip = this.worldmap and WorldMapTooltip or GameTooltip
    tooltip:SetOwner(this, "ANCHOR_LEFT")
    this.spawn = this.spawn or UNKNOWN
    tooltip:SetText(this.spawn..(pfQuest_config.showids == "1" and " |cffcccccc("..this.spawnid..")|r" or ""), .3, 1, .8)
    tooltip:AddDoubleLine(pfQuest_Loc["Type"] .. ":", (this.spawntype or UNKNOWN), .8,.8,.8, 1,1,1)
    AddRankLine(tooltip, this.spawnid, this.spawntype)
    AddSharedSpawnLine(tooltip, this.sharedspawns, this.spawn)

    if itemStartMeta.dropsources_levels then
      tooltip:AddLine(" ")
      tooltip:AddLine("Drops from:", .8,.8,.8)

      local sorted_sources = {}
      for source_name, data in pairs(itemStartMeta.dropsources_levels) do
        table.insert(sorted_sources, {name = source_name, level = data.level, chance = data.chance or 0})
      end

      table.sort(sorted_sources, function(a, b)
        return a.chance > b.chance
      end)

      local count = 0
      for _, source in ipairs(sorted_sources) do
        count = count + 1
        if count <= 5 then
          tooltip:AddLine("  " .. source.name .. " (" .. source.level .. ") - " .. source.chance .. "%", 1,1,1)
        end
      end

      if table.getn(sorted_sources) > 5 then
        tooltip:AddLine("  (+" .. (table.getn(sorted_sources) - 5) .. " more)", .7,.7,.7)
      end
    end

    tooltip:AddLine(" ")

    for title, meta in pairs(this.node) do
      pfMap:ShowTooltip(meta, tooltip)
    end

    if pfQuest_config["tooltiphelp"] == "1" then
      local text = pfQuest_Loc["Use <Shift>-Click To Mark Quest As Done"]
      text = AddConfiguredClickModifier(text, tooltip)
      tooltip:AddLine(text, .6, .6, .6)
      AddWorldMapHideHint(tooltip)
      tooltip:Show()
    end

    pfMap.highlight = pfQuest_config["mouseover"] == "1" and this.title
  else
    if pfQuestCompat and pfQuestCompat.client and pfQuestCompat.client >= 30300 then
      WorldMapPOIFrame.allowBlobTooltip = false
    end

    local tooltip = this.worldmap and WorldMapTooltip or GameTooltip
    tooltip:SetOwner(this, "ANCHOR_LEFT")
    this.spawn = this.spawn or UNKNOWN
    tooltip:SetText(this.spawn..(pfQuest_config.showids == "1" and " |cffcccccc("..this.spawnid..")|r" or ""), .3, 1, .8)
    tooltip:AddDoubleLine(pfQuest_Loc["Level"] .. ":", (this.level or UNKNOWN), .8,.8,.8, 1,1,1)
    tooltip:AddDoubleLine(pfQuest_Loc["Type"] .. ":", (this.spawntype or UNKNOWN), .8,.8,.8, 1,1,1)
    AddRankLine(tooltip, this.spawnid, this.spawntype)
    AddSharedSpawnLine(tooltip, this.sharedspawns, this.spawn)
    tooltip:AddDoubleLine(pfQuest_Loc["Respawn"] .. ":", (this.respawn or UNKNOWN), .8,.8,.8, 1,1,1)

    for title, meta in pairs(this.node) do
      pfMap:ShowTooltip(meta, tooltip)
    end

    if pfQuest_config["tooltiphelp"] == "1" then
      local text = pfQuest_Loc["Use <Shift>-Click To Remove Nodes"]

      if this.cluster then
        text = pfQuest_Loc["Hold <Ctrl> To Hide Cluster"]
      elseif tooltip == GameTooltip then
        text = pfQuest_Loc["Hold <Ctrl> To Hide Minimap Nodes"]
      elseif not this.texture then
        text = pfQuest_Loc["Click Node To Change Color"]
      elseif this.questid and this.texture and this.layer < 5 then
        text = pfQuest_Loc["Use <Shift>-Click To Mark Quest As Done"]
      end

      text = AddConfiguredClickModifier(text, tooltip)

      tooltip:AddLine(text, .6, .6, .6)
      AddWorldMapHideHint(tooltip)

      if this.spawnid and pfQuestLoot and pfQuestLoot.HasDrops and pfQuestLoot.HasDrops(this.spawnid) then
        tooltip:AddLine(AddConfiguredClickModifier(pfQuest_Loc["Alt-Click To Show Item Drops"] or "Alt-Click To Show Item Drops", tooltip), .6, .6, .6)
      end

      tooltip:Show()
    end

    pfMap.highlight = pfQuest_config["mouseover"] == "1" and this.title
  end
end

local originalNodeClick = pfMap.NodeClick
pfMap.NodeClick = function()
  if pfQuestLoot then
    pfQuestLoot.lastClickTrace = "map alt=" .. tostring(IsAltKeyDown()) .. " spawn=" .. tostring(this and this.spawnid)
  end
  if IsAltKeyDown() and this.spawnid then
    if pfQuestLoot and pfQuestLoot.HasDrops and pfQuestLoot.ShowPinned and pfQuestLoot.HasDrops(this.spawnid) then
      local ok, err = pcall(pfQuestLoot.ShowPinned, this)
      if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[pfQuest-turtle]|r ShowPinned error: " .. tostring(err))
      end
      return
    end
  end

  if originalNodeClick then originalNodeClick() end
end

-- Minimap pins are recycled.  A recycled pin can keep the core click handler
-- that was installed before the Turtle wrapper, which makes Alt-click work on
-- the world map but not on that minimap pin.  Wrap the pin's current handler
-- after every minimap update and retain it for ordinary clicks.
local function MinimapLootNodeClick()
  local altClick = IsAltKeyDown() or this.lootPanelAltMouseDown
  if pfQuestLoot then
    pfQuestLoot.lastClickTrace = "pin alt=" .. tostring(altClick) .. " spawn=" .. tostring(this.spawnid)
    pfQuestLoot.lastClickedNode = this
  end
  this.lootPanelAltMouseDown = nil
  if altClick and this.spawnid then
    if pfQuestLoot and pfQuestLoot.HasDrops and pfQuestLoot.ShowPinned and pfQuestLoot.HasDrops(this.spawnid) then
      local ok, err = pcall(pfQuestLoot.ShowPinned, this)
      if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[pfQuest-turtle]|r ShowPinned error: " .. tostring(err))
      end
      return
    end
  end

  if this.lootPanelOriginalClick then
    this.lootPanelOriginalClick()
  end
end

local originalUpdateNode = pfMap.UpdateNode
pfMap.UpdateNode = function(self, frame, node, color, obj, distance)
  originalUpdateNode(self, frame, node, color, obj, distance)

  -- Older clients bind node clicks directly to the pin frame, so wrap every
  -- spawn pin rather than relying on the map-level click callback.
  if frame.spawnid and frame:GetScript("OnClick") ~= MinimapLootNodeClick then
    frame.lootPanelOriginalClick = frame:GetScript("OnClick")
    frame:SetScript("OnClick", MinimapLootNodeClick)
    frame:SetScript("OnMouseDown", function()
      this.lootPanelAltMouseDown = IsAltKeyDown() and true or nil
    end)
  end
end

local function RebindUnitResultTooltips()
  local unitTab = pfBrowser and pfBrowser.tabs and pfBrowser.tabs["units"]
  if not unitTab or not unitTab.buttons then return end

  for _, button in pairs(unitTab.buttons) do
    if not button.rankTooltipHooked then
      local originalOnEnter = button:GetScript("OnEnter")
      button:SetScript("OnEnter", function()
        if originalOnEnter then originalOnEnter() end
        AddRankLine(GameTooltip, this.id, pfQuest_Loc["Unit"])
        GameTooltip:Show()
      end)
      button.rankTooltipHooked = true
    end
  end
end

local rankTooltipRebind = CreateFrame("Frame")
rankTooltipRebind:Hide()
rankTooltipRebind:SetScript("OnUpdate", function()
  this.delay = (this.delay or 0) - arg1
  if this.delay <= 0 then
    this:Hide()
    RebindUnitResultTooltips()
  end
end)

if pfBrowser and pfBrowser.input then
  local previous = pfBrowser.input:GetScript("OnTextChanged")
  pfBrowser.input:SetScript("OnTextChanged", function()
    if previous then previous() end
    rankTooltipRebind.delay = 0.7
    rankTooltipRebind:Show()
  end)
end
