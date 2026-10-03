-- Usage: lua export_quests.lua /path/to/pfQuest /path/to/output-directory
local source, output, turtle, localeList = arg[1], arg[2], arg[3], arg[4]
assert(source and output, "usage: lua export_quests.lua <pfQuest source> <output-directory> [pfQuest-turtle source] [locales]")
turtle = turtle ~= "" and turtle or nil

dofile(source .. "/db/init.lua")
dofile(source .. "/db/quests.lua")
dofile(source .. "/db/units.lua")
dofile(source .. "/db/objects.lua")
dofile(source .. "/db/items.lua")
dofile(source .. "/db/refloot.lua")
dofile(source .. "/db/zones.lua")
dofile(source .. "/db/areatrigger.lua")
dofile(source .. "/db/quests-itemreq.lua")
dofile(source .. "/db/meta.lua")
-- Apply the base addon's hand-maintained corrections before Turtle overlays
-- and before any rows are exported. These records are part of the effective
-- live database even though they do not reside in db/quests.lua.
dofile(source .. "/overwrites.lua")

-- Turtle supplies sparse overlay tables. Merge them once here so the generated
-- SQLite data mirrors pfQuest-turtle's runtime patchtable behavior.
local function LoadIfPresent(path)
  local file = io.open(path, "rb")
  if file then file:close(); dofile(path) end
end
local function patchtable(base, diff)
  for key, value in pairs(diff or {}) do
    if value == "_" then base[key] = nil else base[key] = value end
  end
end
local dbs = { "items", "quests", "quests-itemreq", "objects", "units", "zones", "professions", "areatrigger", "refloot" }
if turtle then
  for _, db in ipairs(dbs) do LoadIfPresent(turtle .. "/db/" .. db .. "-turtle.lua") end
  LoadIfPresent(turtle .. "/db/feature-compat.lua")
  LoadIfPresent(turtle .. "/db/meta-turtle.lua")
  -- Apply Turtle's hand-maintained corrections while its sparse overlay tables
  -- still exist. The HDB runtime intentionally does not load these large tables.
  LoadIfPresent(turtle .. "/overwrites.lua")
end
if pfDB.meta and pfDB["meta-turtle"] then patchtable(pfDB.meta, pfDB["meta-turtle"]) end
for _, db in ipairs(dbs) do
  if pfDB[db] and pfDB[db]["data-turtle"] then patchtable(pfDB[db]["data"], pfDB[db]["data-turtle"]) end
end
local function ApplyTurtleLocale(locale, db)
  if not turtle then return end
  LoadIfPresent(turtle .. "/db/" .. locale .. "/" .. db .. "-turtle.lua")
  if pfDB[db] and pfDB[db][locale .. "-turtle"] then
    patchtable(pfDB[db][locale], pfDB[db][locale .. "-turtle"])
  end
end

local SEP, ROW = string.char(31), string.char(30)
local function Open(name)
  return assert(io.open(output .. "/" .. name, "wb"))
end

local function Safe(value)
  -- Parentheses keep string.gsub's replacement count from becoming a second
  -- table value when Safe() is the final expression in a table constructor.
  return (tostring(value or ""):gsub(SEP, " "):gsub(ROW, " "))
end

-- Quest text is locale-specific. Quest and spawn data are language-neutral.
local textFile = Open("quest_text.tsv")
local locales = {}
for locale in string.gmatch(localeList or "enUS", "[^,]+") do table.insert(locales, locale) end
for _, locale in ipairs(locales) do
  dofile(source .. "/db/" .. locale .. "/quests.lua")
  ApplyTurtleLocale(locale, "quests")
  for id, data in pairs(pfDB.quests.data) do
    local loc = pfDB.quests[locale][id]
    if loc and loc.T then
      textFile:write(table.concat({ Safe(locale), Safe(id), Safe(loc.T), Safe(loc.O), Safe(loc.D), Safe(data.lvl), Safe(data.min) }, SEP), ROW)
    end
  end
end
textFile:close()

-- Entity labels are needed before query results can become readable map pins.
local entityTextFile = Open("entity_text.tsv")
for _, locale in ipairs(locales) do
  dofile(source .. "/db/" .. locale .. "/units.lua")
  ApplyTurtleLocale(locale, "units")
  dofile(source .. "/db/" .. locale .. "/objects.lua")
  ApplyTurtleLocale(locale, "objects")
  for id, name in pairs(pfDB.units[locale]) do
    if name and name ~= "" then
      entityTextFile:write(table.concat({ Safe(locale), "U", Safe(id), Safe(name) }, SEP), ROW)
    end
  end
  for id, name in pairs(pfDB.objects[locale]) do
    if name and name ~= "" then
      entityTextFile:write(table.concat({ Safe(locale), "O", Safe(id), Safe(name) }, SEP), ROW)
    end
  end
end
entityTextFile:close()

-- Levels and faction flags are language-neutral. They support map pin
-- tooltips and native filtering of available quest givers.
local entityMetaFile = Open("entity_meta.tsv")
for id, data in pairs(pfDB.units.data) do
  entityMetaFile:write(table.concat({ "U", Safe(id), Safe(data.lvl), Safe(data.fac), Safe(data.rnk) }, SEP), ROW)
end
for id, data in pairs(pfDB.objects.data) do
  entityMetaFile:write(table.concat({ "O", Safe(id), "N/A", Safe(data.fac), "" }, SEP), ROW)
end
entityMetaFile:close()

-- Gathering nodes use the small meta relations table at runtime. Export only
-- the object-to-skill mapping needed for native object-map tooltips.
local objectSkillFile = Open("object_skill.tsv")
for _, relation in ipairs({ "herbs", "mines" }) do
  for entry, requiredSkill in pairs((pfDB.meta and pfDB.meta[relation]) or {}) do
    if tonumber(entry) and tonumber(entry) < 0 then
      objectSkillFile:write(table.concat({ Safe(-tonumber(entry)), Safe(requiredSkill), relation }, SEP), ROW)
    end
  end
end
objectSkillFile:close()

local metaRelationFile = Open("meta_relation.tsv")
for relation, entries in pairs(pfDB.meta or {}) do
  for entry, value in pairs(entries or {}) do
    local id = tonumber(entry)
    if id then
      metaRelationFile:write(table.concat({ Safe(relation), id < 0 and "O" or "U", Safe(math.abs(id)), Safe(value) }, SEP), ROW)
    end
  end
end
metaRelationFile:close()

local itemTextFile = Open("item_text.tsv")
for _, locale in ipairs(locales) do
  dofile(source .. "/db/" .. locale .. "/items.lua")
  ApplyTurtleLocale(locale, "items")
  for id, name in pairs(pfDB.items[locale]) do
    itemTextFile:write(table.concat({ Safe(locale), Safe(id), Safe(name) }, SEP), ROW)
  end
end
itemTextFile:close()

-- U/O sources map to creature/object spawns. R preserves reference-loot
-- links for a recursive resolver; V maps vendor items to their NPC spawns.
local itemSourceFile = Open("item_source.tsv")
for itemID, data in pairs(pfDB.items.data) do
  for _, sourceKind in ipairs({ "U", "O", "R", "V" }) do
    local sources = data[sourceKind]
    if type(sources) == "table" then
      for sourceID, chance in pairs(sources) do
        itemSourceFile:write(table.concat({ Safe(itemID), sourceKind, Safe(sourceID), Safe(chance) }, SEP), ROW)
      end
    end
  end
end
itemSourceFile:close()

local refLootFile = Open("refloot_source.tsv")
for referenceID, data in pairs(pfDB.refloot.data) do
  for _, sourceKind in ipairs({ "U", "O" }) do
    local sources = data[sourceKind]
    if type(sources) == "table" then
      for sourceID in pairs(sources) do
        refLootFile:write(table.concat({ Safe(referenceID), sourceKind, Safe(sourceID) }, SEP), ROW)
      end
    end
  end
end
refLootFile:close()

local zoneTextFile = Open("zone_text.tsv")
for _, locale in ipairs(locales) do
  dofile(source .. "/db/" .. locale .. "/zones.lua")
  ApplyTurtleLocale(locale, "zones")
  for id, name in pairs(pfDB.zones[locale]) do
    zoneTextFile:write(table.concat({ Safe(locale), Safe(id), Safe(name) }, SEP), ROW)
  end
end
zoneTextFile:close()

local zoneDataFile = Open("zone_data.tsv")
for id, data in pairs(pfDB.zones.data) do
  zoneDataFile:write(table.concat({ Safe(id), Safe(data[1]), Safe(data[4]), Safe(data[5]) }, SEP), ROW)
end
zoneDataFile:close()

local triggerFile = Open("areatrigger_spawn.tsv")
for id, data in pairs(pfDB.areatrigger.data) do
  if data.coords then
    for _, coord in ipairs(data.coords) do
      triggerFile:write(table.concat({ Safe(id), Safe(coord[1]), Safe(coord[2]), Safe(coord[3]) }, SEP), ROW)
    end
  end
end
triggerFile:close()

local questMetaFile = Open("quest_meta.tsv")
local prerequisiteFile = Open("quest_prerequisite.tsv")
for id, data in pairs(pfDB.quests.data) do
  questMetaFile:write(table.concat({
    Safe(id), Safe(data.lvl), Safe(data.min), Safe(data.race), Safe(data.class), Safe(data.skill), Safe(data.event)
  }, SEP), ROW)
  if type(data.pre) == "table" then
    for _, prerequisiteID in ipairs(data.pre) do
      prerequisiteFile:write(table.concat({ Safe(id), Safe(prerequisiteID) }, SEP), ROW)
    end
  end
end
questMetaFile:close()
prerequisiteFile:close()

local itemRequirementFile = Open("item_requirement.tsv")
for itemID, sources in pairs(pfDB["quests-itemreq"].data) do
  for entry, spell in pairs(sources) do
    local sourceKind = entry < 0 and "O" or "U"
    itemRequirementFile:write(table.concat({ Safe(itemID), sourceKind, Safe(math.abs(entry)), Safe(spell) }, SEP), ROW)
  end
end
itemRequirementFile:close()

local targetFile = Open("quest_target.tsv")
for questID, data in pairs(pfDB.quests.data) do
  for _, phase in ipairs({ "start", "end", "obj" }) do
    local targets = data[phase]
    if type(targets) == "table" then
      for targetKind, ids in pairs(targets) do
        if type(ids) == "table" then
          for _, targetID in ipairs(ids) do
            targetFile:write(table.concat({ Safe(questID), Safe(phase), Safe(targetKind), Safe(targetID) }, SEP), ROW)
          end
        end
      end
    end
  end
end
targetFile:close()

local spawnFile = Open("spawn.tsv")
local function ExportSpawns(kind, data)
  for id, entity in pairs(data) do
    if entity.coords then
      for _, coord in ipairs(entity.coords) do
        spawnFile:write(table.concat({ Safe(kind), Safe(id), Safe(coord[1]), Safe(coord[2]), Safe(coord[3]), Safe(coord[4]) }, SEP), ROW)
      end
    end
  end
end
ExportSpawns("U", pfDB.units.data)
ExportSpawns("O", pfDB.objects.data)
spawnFile:close()
