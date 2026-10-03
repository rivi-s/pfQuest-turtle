-- Native asynchronous SQLite provider used by pfQuest's HDB adapter.
local addon = CreateFrame("Frame")
pfQuestHearthDB = {}
local dbHandle
local opened
local shuttingDown
local questTextCache = {}
local questTargetCache = {}
local questMapPinCache = {}
local questSearchCache = {}
local questTitleIDCache = {}
local questTitleByIDCache = {}
local questTitleIDPreloaded
local questTitleIDPreloading
local questDisambiguationCache = {}
local questDisambiguationPreloaded
local questDisambiguationPreloading
local entityInfoCache = {}
local entityTitleCache = {}
local entitySearchCache = {}
local itemSearchCache = {}
local unitDropsCache = {}

local function Print(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-HDB|r " .. message)
end

local function Available()
  return type(HDB_GetVersion) == "function"
    and type(HDB_OpenAddon) == "function"
    and type(HDB_QueryRawAsync) == "function"
    and type(HDB_ClearPoison) == "function"
end

local function Open()
  if shuttingDown then return nil end
  if opened then return dbHandle end

  if not Available() then
    Print("HearthDB is not available; companion is idle.")
    return nil
  end

  local ok, handle = pcall(HDB_OpenAddon, "pfQuest-HearthDB-turtle", "data/pfquest-turtle.sqlite")
  if not ok or not handle then
    Print("could not open data/pfquest-turtle.sqlite")
    return nil
  end

  dbHandle = handle
  opened = true
  return dbHandle
end

local function CurrentLocale()
  local locale = GetLocale and GetLocale() or "enUS"
  if pfDB and pfDB.quests and pfDB.quests[locale] then
    return locale
  end
  return "enUS"
end

local function CacheKey(id, limit)
  return CurrentLocale() .. ":" .. tostring(id) .. ":" .. tostring(limit or "all")
end

local function ClearCache()
  questTextCache = {}
  questTargetCache = {}
  questMapPinCache = {}
  questSearchCache = {}
  questTitleIDCache = {}
  questTitleByIDCache = {}
  questTitleIDPreloaded = nil
  questTitleIDPreloading = nil
  questDisambiguationCache = {}
  questDisambiguationPreloaded = nil
  questDisambiguationPreloading = nil
  entityInfoCache = {}
  entityTitleCache = {}
  entitySearchCache = {}
  itemSearchCache = {}
  unitDropsCache = {}
end

-- HearthDB owns a native SQLite handle and asynchronous query queue. Close it
-- while Lua is still alive instead of leaving native cleanup to the game's
-- process teardown.
local function Close()
  shuttingDown = true
  if dbHandle and type(HDB_Close) == "function" then
    pcall(HDB_Close, dbHandle)
  end
  dbHandle = nil
  opened = nil
  ClearCache()
end

function pfQuestHearthDB:SearchEntityTitlesAsync(kind, query, limit, callback)
  local handle = Open()
  query, limit = tostring(query or ""), tonumber(limit) or 50
  if not handle or (kind ~= "U" and kind ~= "O") or query == "" then
    if callback then callback(nil, "HearthDB is unavailable or entity search is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":" .. kind .. ":" .. string.lower(query) .. ":" .. limit
  if entitySearchCache[cacheKey] then
    if callback then callback(entitySearchCache[cacheKey], nil) end
    return true
  end
  local safeQuery = string.lower(string.gsub(query, "'", "''"))
  local searchColumn = tonumber(query) and "CAST(e.target_id AS TEXT)" or "LOWER(e.title)"
  local sql = "SELECT e.target_id, e.title, m.level, m.faction, m.rank, "
    .. "EXISTS (SELECT 1 FROM spawn s WHERE s.target_kind = e.target_kind AND s.target_id = e.target_id) "
    .. "FROM entity_text e LEFT JOIN entity_meta m ON m.target_kind = e.target_kind AND m.target_id = e.target_id "
    .. "WHERE e.locale = '" .. CurrentLocale() .. "' AND e.target_kind = '" .. kind
    .. "' AND " .. searchColumn .. " LIKE '%" .. safeQuery .. "%' ORDER BY e.title, e.target_id LIMIT " .. limit
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local results = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      local faction = row[4]
      local raceMask = faction == "A" and 77 or faction == "H" and 178
        or (faction == "AH" or faction == "HA") and 255 or 0
      results[tonumber(row[1])] = {
        title = row[2], level = row[3], faction = faction, rank = row[5],
        raceMask = raceMask, hasSpawns = tonumber(row[6]) == 1,
      }
    end
    entitySearchCache[cacheKey] = results
    if callback then callback(results, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit entity search query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetEntitiesByTitleAsync(kind, title, callback)
  local handle = Open()
  if not handle or (kind ~= "U" and kind ~= "O") or not title or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or entity title is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":" .. kind .. ":" .. title
  if entityTitleCache[cacheKey] then
    if callback then callback(entityTitleCache[cacheKey], nil) end
    return true
  end
  local safeTitle = string.gsub(title, "'", "''")
  local sql = "SELECT e.target_id, e.title, m.level, m.faction, m.rank, os.required_skill, os.profession, s.zone_id, s.x, s.y, s.respawn FROM entity_text e "
    .. "LEFT JOIN entity_meta m ON m.target_kind = e.target_kind AND m.target_id = e.target_id "
    .. "LEFT JOIN object_skill os ON e.target_kind = 'O' AND os.object_id = e.target_id "
    .. "LEFT JOIN spawn s ON s.target_kind = e.target_kind AND s.target_id = e.target_id "
    .. "WHERE e.locale = '" .. CurrentLocale() .. "' AND e.target_kind = '" .. kind .. "' AND LOWER(e.title) = LOWER('" .. safeTitle .. "')"
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local byID, records = {}, {}
    for index = 1, table.getn(rows or {}) do
      local row, id = rows[index], tonumber(rows[index][1])
      local record = byID[id]
      if not record then
        record = { id = id, kind = kind, title = row[2], level = row[3], faction = row[4], rank = row[5], requiredSkill = row[6], profession = row[7], zones = {}, spawns = {} }
        byID[id] = record
        table.insert(records, record)
      end
      if row[8] then
        local zone = tonumber(row[8])
        record.zones[zone] = (record.zones[zone] or 0) + 1
        table.insert(record.spawns, { zoneID = zone, x = tonumber(row[9]), y = tonumber(row[10]), respawn = tonumber(row[11]) })
      end
    end
    entityTitleCache[cacheKey] = records
    if callback then callback(records, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit entity title query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetMetaRelationAsync(relation, callback)
  local handle = Open()
  if not handle or not relation then if callback then callback(nil, "HearthDB is unavailable") end return nil end
  local safe = string.gsub(relation, "'", "''")
  local sql = "SELECT r.target_kind,r.target_id,r.value,e.title,m.level,s.zone_id,s.x,s.y,s.respawn FROM meta_relation r "
    .. "LEFT JOIN entity_text e ON e.locale='" .. CurrentLocale() .. "' AND e.target_kind=r.target_kind AND e.target_id=r.target_id "
    .. "LEFT JOIN entity_meta m ON m.target_kind=r.target_kind AND m.target_id=r.target_id "
    .. "LEFT JOIN spawn s ON s.target_kind=r.target_kind AND s.target_id=r.target_id WHERE r.relation='" .. safe .. "'"
  local ok,ticket=pcall(HDB_QueryRawAsync,handle,sql,function(_,rows,err)
    if err then HDB_ClearPoison(handle); if callback then callback(nil,err) end return end
    local records={} for i=1,table.getn(rows or {}) do local r=rows[i]; table.insert(records,{kind=r[1],id=tonumber(r[2]),value=r[3],title=r[4],level=r[5],zoneID=tonumber(r[6]),x=tonumber(r[7]),y=tonumber(r[8]),respawn=tonumber(r[9])}) end
    if callback then callback(records,nil) end
  end)
  if not ok or not ticket then if callback then callback(nil,"could not submit tracking query") end return nil end
  return ticket
end

function pfQuestHearthDB:GetEntityInfoAsync(kind, id, callback)
  local handle = Open()
  id = tonumber(id)
  if not handle or (kind ~= "U" and kind ~= "O") or not id then
    if callback then callback(nil, "HearthDB is unavailable or entity is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":" .. kind .. ":" .. id
  if entityInfoCache[cacheKey] then
    if callback then callback(entityInfoCache[cacheKey], nil) end
    return true
  end
  local sql = "SELECT e.title, m.level, m.faction, m.rank, os.required_skill, os.profession, s.zone_id, s.x, s.y, s.respawn FROM entity_text e "
    .. "LEFT JOIN entity_meta m ON m.target_kind = e.target_kind AND m.target_id = e.target_id "
    .. "LEFT JOIN object_skill os ON e.target_kind = 'O' AND os.object_id = e.target_id "
    .. "LEFT JOIN spawn s ON s.target_kind = e.target_kind AND s.target_id = e.target_id "
    .. "WHERE e.locale = '" .. CurrentLocale() .. "' AND e.target_kind = '" .. kind .. "' AND e.target_id = " .. id
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local record
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      record = record or { id = id, kind = kind, title = row[1], level = row[2], faction = row[3], rank = row[4], requiredSkill = row[5], profession = row[6], zones = {}, spawns = {} }
      if row[7] then
        local zone = tonumber(row[7])
        record.zones[zone] = (record.zones[zone] or 0) + 1
        table.insert(record.spawns, { zoneID = zone, x = tonumber(row[8]), y = tonumber(row[9]), respawn = tonumber(row[10]) })
      end
    end
    if record then entityInfoCache[cacheKey] = record end
    if callback then callback(record, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit entity query") end
    return nil
  end
  return ticket
end

-- Search is intentionally separate from the exact-title lookup above. The
-- browser needs partial matches, while map rendering needs exact duplicate
-- title handling. Keeping both APIs prevents an accidental broad query in a
-- map refresh.
function pfQuestHearthDB:SearchItemTitlesAsync(query, limit, callback)
  local handle = Open()
  query, limit = tostring(query or ""), tonumber(limit) or 50
  if not handle or query == "" then
    if callback then callback(nil, "HearthDB is unavailable or item search is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":" .. string.lower(query) .. ":" .. limit
  if itemSearchCache[cacheKey] then
    if callback then callback(itemSearchCache[cacheKey], nil) end
    return true
  end
  local safeQuery = string.lower(string.gsub(query, "'", "''"))
  local searchColumn = tonumber(query) and "CAST(item_id AS TEXT)" or "LOWER(title)"
  local sql = "SELECT i.item_id, i.title, "
    .. "EXISTS (SELECT 1 FROM item_source s WHERE s.item_id=i.item_id AND s.source_kind='U') "
    .. "OR EXISTS (SELECT 1 FROM item_source s JOIN refloot_source r ON r.reference_id=s.source_id "
    .. "WHERE s.item_id=i.item_id AND s.source_kind='R' AND r.source_kind='U'), "
    .. "EXISTS (SELECT 1 FROM item_source s WHERE s.item_id=i.item_id AND s.source_kind='O') "
    .. "OR EXISTS (SELECT 1 FROM item_source s JOIN refloot_source r ON r.reference_id=s.source_id "
    .. "WHERE s.item_id=i.item_id AND s.source_kind='R' AND r.source_kind='O'), "
    .. "EXISTS (SELECT 1 FROM item_source s WHERE s.item_id=i.item_id AND s.source_kind='V') "
    .. "FROM item_text i WHERE i.locale = '" .. CurrentLocale()
    .. "' AND " .. searchColumn .. " LIKE '%" .. safeQuery .. "%' ORDER BY i.title, i.item_id LIMIT " .. limit
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local results = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      results[tonumber(row[1])] = {
        title = row[2], hasUnitSources = tonumber(row[3]) == 1,
        hasObjectSources = tonumber(row[4]) == 1, hasVendorSources = tonumber(row[5]) == 1,
      }
    end
    itemSearchCache[cacheKey] = results
    if callback then callback(results, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit item search query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetItemIDsByTitleAsync(title, callback)
  local handle = Open()
  title = tostring(title or "")
  if not handle or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or item title is empty") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":exact:" .. string.lower(title)
  if itemSearchCache[cacheKey] then
    if callback then callback(itemSearchCache[cacheKey], nil) end
    return true
  end
  local safeTitle = string.gsub(title, "'", "''")
  local sql = "SELECT item_id, title FROM item_text WHERE locale = '" .. CurrentLocale()
    .. "' AND LOWER(title) = LOWER('" .. safeTitle .. "') ORDER BY item_id"
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local results = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      results[tonumber(row[1])] = row[2]
    end
    itemSearchCache[cacheKey] = results
    if callback then callback(results, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit item title query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:SearchQuestTitlesAsync(query, limit, callback)
  local handle = Open()
  query = tostring(query or "")
  limit = tonumber(limit) or 50
  if not handle or query == "" then
    if callback then callback(nil, "HearthDB is unavailable or query is empty") end
    return nil
  end

  local cacheKey = CurrentLocale() .. ":" .. string.lower(query) .. ":" .. limit
  if questSearchCache[cacheKey] then
    if callback then callback(questSearchCache[cacheKey], nil) end
    return true
  end

  local numeric = tonumber(query)
  local where
  if numeric then
    where = "CAST(t.id AS TEXT) LIKE '%" .. string.gsub(query, "'", "''") .. "%'"
  else
    where = "LOWER(t.title) LIKE '%" .. string.lower(string.gsub(query, "'", "''")) .. "%'"
  end
  local factionMatch = [[SELECT 1 FROM quest_target qt
      JOIN entity_meta em ON em.target_kind = qt.target_kind AND em.target_id = qt.target_id
      WHERE qt.quest_id = t.id AND qt.phase = 'start' AND em.faction IN (%s)]]
  local hasBoth = string.format(factionMatch, "'AH','HA'")
  local hasAlliance = string.format(factionMatch, "'A','AH','HA'")
  local hasHorde = string.format(factionMatch, "'H','AH','HA'")
  local sql = [[SELECT t.id, t.title, t.level,
      CASE WHEN qm.race_mask <> '' THEN CAST(qm.race_mask AS INTEGER)
           WHEN EXISTS (]] .. hasBoth .. [[) THEN 255
           WHEN EXISTS (]] .. hasAlliance .. [[) AND EXISTS (]] .. hasHorde .. [[) THEN 255
           WHEN EXISTS (]] .. hasAlliance .. [[) THEN 77
           WHEN EXISTS (]] .. hasHorde .. [[) THEN 178
           ELSE 0 END
    FROM quest_text t LEFT JOIN quest_meta qm ON qm.quest_id = t.id
    WHERE t.locale = ']] .. CurrentLocale() .. "' AND " .. where
    .. " ORDER BY t.title, t.id LIMIT " .. limit
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local results = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      results[tonumber(row[1])] = { title = row[2], level = row[3], raceMask = tonumber(row[4]) or 0 }
    end
    questSearchCache[cacheKey] = results
    if callback then callback(results, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest search query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetQuestTextAsync(id, callback)
  local handle = Open()
  id = tonumber(id)
  if not handle or not id then
    if callback then callback(nil, "HearthDB is unavailable or quest id is invalid") end
    return nil
  end
  local cacheKey = CacheKey(id)
  if questTextCache[cacheKey] then
    if callback then callback(questTextCache[cacheKey], nil) end
    return true
  end

  local sql = "SELECT id, title, objective, description, level, min_level FROM quest_text WHERE locale = '"
    .. CurrentLocale() .. "' AND id = " .. id
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local row = rows and rows[1]
    if not row then
      if callback then callback(nil, nil) end
      return
    end
    local record = {
      id = tonumber(row[1]), title = row[2], objective = row[3], description = row[4],
      level = row[5], minLevel = row[6],
    }
    questTextCache[cacheKey] = record
    if callback then callback(record, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest text query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetQuestIDsByTitleAsync(title, callback)
  local handle = Open()
  if not handle or not title or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or title is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":title-id:" .. string.lower(title)
  if questTitleIDCache[cacheKey] then
    if callback then callback(questTitleIDCache[cacheKey], nil) end
    return true
  end
  local safeTitle = (string.gsub(title, "'", "''"))
  local sql = "SELECT id FROM quest_text WHERE locale = '" .. CurrentLocale()
    .. "' AND LOWER(title) = LOWER('" .. safeTitle .. "') ORDER BY id"
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local ids = {}
    for index = 1, table.getn(rows or {}) do table.insert(ids, tonumber(rows[index][1])) end
    questTitleIDCache[cacheKey] = ids
    for index = 1, table.getn(ids) do questTitleByIDCache[ids[index]] = title end
    if callback then callback(ids, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit title query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetQuestTextByTitleAsync(title, callback)
  local handle = Open()
  if not handle or not title or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or title is invalid") end
    return nil
  end
  local safeTitle = string.gsub(title, "'", "''")
  local sql = "SELECT qt.id, qt.title, qt.objective, qt.description, qm.level, qm.min_level "
    .. "FROM quest_text qt JOIN quest_meta qm ON qm.quest_id = qt.id "
    .. "WHERE qt.locale = '" .. CurrentLocale() .. "' AND LOWER(qt.title) = LOWER('"
    .. safeTitle .. "') ORDER BY qt.id LIMIT 1"
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local row = rows and rows[1]
    if not row then
      if callback then callback(nil, "quest title was not found") end
      return
    end
    local record = {
      id = tonumber(row[1]), title = row[2], objective = row[3], description = row[4],
      level = tonumber(row[5]), minLevel = tonumber(row[6]),
    }
    questTextCache[CacheKey(record.id)] = record
    questTitleByIDCache[record.id] = record.title
    if callback then callback(record, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit title-text query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetCachedQuestIDsByTitle(title)
  if not title or title == "" then return nil, questTitleIDPreloaded end
  return questTitleIDCache["enUS:title-id:" .. string.lower(title)], questTitleIDPreloaded
end

function pfQuestHearthDB:GetCachedQuestTitleByID(id)
  return questTitleByIDCache[tonumber(id)], questTitleIDPreloaded
end

function pfQuestHearthDB:PreloadQuestTitleIDsAsync(callback)
  local handle = Open()
  if not handle then
    if callback then callback(nil, "HearthDB is unavailable") end
    return nil
  end
  if questTitleIDPreloaded then
    if callback then callback(true, nil) end
    return true
  end
  if questTitleIDPreloading then return true end
  questTitleIDPreloading = true
  local batchSize, firstTicket = 256, nil
  local grouped = {}
  local function SubmitBatch(offset)
    local sql = "SELECT title, id FROM quest_text WHERE locale = 'enUS' ORDER BY title, id LIMIT "
      .. batchSize .. " OFFSET " .. offset
    local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
      if err then
        questTitleIDPreloading = nil
        HDB_ClearPoison(handle)
        if callback then callback(nil, err) end
        return
      end
      local count = table.getn(rows or {})
      for index = 1, count do
        local row = rows[index]
        local key = "enUS:title-id:" .. string.lower(row[1])
        grouped[key] = grouped[key] or {}
        local id = tonumber(row[2])
        table.insert(grouped[key], id)
        questTitleByIDCache[id] = row[1]
      end
      if count == batchSize then SubmitBatch(offset + batchSize); return end
      for key, ids in pairs(grouped) do questTitleIDCache[key] = ids end
      questTitleIDPreloading = nil
      questTitleIDPreloaded = true
      if callback then callback(true, nil) end
    end)
    if not ok or not ticket then
      questTitleIDPreloading = nil
      if callback then callback(nil, "could not submit quest title preload") end
      return nil
    end
    if not firstTicket then firstTicket = ticket end
    return ticket
  end
  SubmitBatch(0)
  return firstTicket
end

function pfQuestHearthDB:GetQuestDisambiguationAsync(title, callback)
  local handle = Open()
  title = tostring(title or "")
  if not handle or title == "" then
    if callback then callback(nil, "HearthDB is unavailable or title is invalid") end
    return nil
  end
  local cacheKey = CurrentLocale() .. ":disambiguation:" .. string.lower(title)
  if questDisambiguationCache[cacheKey] then
    if callback then callback(questDisambiguationCache[cacheKey], nil) end
    return true
  end
  local safeTitle = string.gsub(title, "'", "''")
  local sql = [[SELECT d.quest_id, q.objective, q.description, d.objective_targets,
      d.prerequisites, d.level, d.race_mask, d.class_mask, d.resolution_class,
      (SELECT GROUP_CONCAT((CASE t.target_kind WHEN 'U' THEN 'monster' WHEN 'I' THEN 'item'
         WHEN 'O' THEN 'object' ELSE LOWER(t.target_kind) END) || ':'
         || LOWER(COALESCE(e.title, i.title, '')), '|')
       FROM quest_target t
       LEFT JOIN entity_text e ON e.locale = q.locale AND e.target_kind = t.target_kind
         AND e.target_id = t.target_id
       LEFT JOIN item_text i ON i.locale = q.locale AND t.target_kind = 'I'
         AND i.item_id = t.target_id
       WHERE t.quest_id = d.quest_id AND t.phase = 'obj')
    FROM quest_text q
    JOIN quest_disambiguation d ON d.locale = q.locale AND d.quest_id = q.id
    WHERE q.locale = ']] .. CurrentLocale() .. [[' AND LOWER(q.title) = LOWER(']]
    .. safeTitle .. [[') ORDER BY d.quest_id]]
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local records = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      table.insert(records, {
        id = tonumber(row[1]), objective = row[2], description = row[3],
        objectiveTargets = row[4], prerequisites = row[5], level = row[6],
        raceMask = row[7], classMask = row[8], resolutionClass = row[9], objectiveLabels = row[10],
      })
    end
    questDisambiguationCache[cacheKey] = records
    if callback then callback(records, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest disambiguation query") end
    return nil
  end
  return ticket
end

-- Turtle WoW uses the enUS client. Warm the small same-title candidate set in
-- the background at login so the first stage normally needs no SQLite trip.
function pfQuestHearthDB:PreloadQuestDisambiguationAsync(callback)
  local handle = Open()
  if not handle then
    if callback then callback(nil, "HearthDB is unavailable") end
    return nil
  end
  if questDisambiguationPreloaded then
    if callback then callback(true, nil) end
    return true
  end
  if questDisambiguationPreloading then return true end
  questDisambiguationPreloading = true
  local batchSize = 128
  local grouped = {}
  local baseSQL = [[SELECT q.title, d.quest_id, q.objective, q.description, d.objective_targets,
      d.prerequisites, d.level, d.race_mask, d.class_mask, d.resolution_class,
      (SELECT GROUP_CONCAT((CASE t.target_kind WHEN 'U' THEN 'monster' WHEN 'I' THEN 'item'
         WHEN 'O' THEN 'object' ELSE LOWER(t.target_kind) END) || ':'
         || LOWER(COALESCE(e.title, i.title, '')), '|')
       FROM quest_target t
       LEFT JOIN entity_text e ON e.locale = q.locale AND e.target_kind = t.target_kind
         AND e.target_id = t.target_id
       LEFT JOIN item_text i ON i.locale = q.locale AND t.target_kind = 'I'
         AND i.item_id = t.target_id
       WHERE t.quest_id = d.quest_id AND t.phase = 'obj')
    FROM quest_text q
    JOIN quest_disambiguation d ON d.locale = q.locale AND d.quest_id = q.id
    WHERE q.locale = 'enUS' ORDER BY q.title, d.quest_id]]
  local firstTicket
  local function SubmitBatch(offset)
    local sql = baseSQL .. " LIMIT " .. batchSize .. " OFFSET " .. offset
    local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
      if err then
        questDisambiguationPreloading = nil
        HDB_ClearPoison(handle)
        if callback then callback(nil, err) end
        return
      end
      local count = table.getn(rows or {})
      for index = 1, count do
        local row = rows[index]
        local key = "enUS:disambiguation:" .. string.lower(row[1])
        grouped[key] = grouped[key] or {}
        table.insert(grouped[key], {
          id = tonumber(row[2]), objective = row[3], description = row[4],
          objectiveTargets = row[5], prerequisites = row[6], level = row[7],
          raceMask = row[8], classMask = row[9], resolutionClass = row[10], objectiveLabels = row[11],
        })
      end
      if count == batchSize then
        SubmitBatch(offset + batchSize)
        return
      end
      for key, records in pairs(grouped) do questDisambiguationCache[key] = records end
      questDisambiguationPreloading = nil
      questDisambiguationPreloaded = true
      if callback then callback(true, nil) end
    end)
    if not ok or not ticket then
      questDisambiguationPreloading = nil
      if callback then callback(nil, "could not submit quest disambiguation preload") end
      return nil
    end
    if not firstTicket then firstTicket = ticket end
    return ticket
  end
  SubmitBatch(0)
  return firstTicket
end

function pfQuestHearthDB:GetItemSourcesAsync(id, callback)
  local handle = Open()
  id = tonumber(id)
  if not handle or not id then
    if callback then callback(nil, "HearthDB is unavailable or item id is invalid") end
    return nil
  end
  local locale = CurrentLocale()
  local sql = [[WITH source AS (
      SELECT source_kind, source_id, chance, 'direct' AS source_mode
      FROM item_source WHERE item_id = ]] .. id .. [[ AND source_kind IN ('U', 'O', 'V')
      UNION ALL
      SELECT r.source_kind, r.source_id, s.chance, 'reference' AS source_mode
      FROM item_source s JOIN refloot_source r ON r.reference_id = s.source_id
      WHERE s.item_id = ]] .. id .. [[ AND s.source_kind = 'R'
    )
    SELECT i.title, s.source_kind, s.source_id, s.chance, s.source_mode, e.title,
      sp.zone_id, sp.x, sp.y, sp.respawn, em.level
    FROM item_text i
    LEFT JOIN source s ON 1 = 1
    LEFT JOIN entity_text e ON e.target_kind = CASE WHEN s.source_kind = 'V' THEN 'U' ELSE s.source_kind END
      AND e.target_id = s.source_id AND e.locale = ']]
    .. locale .. [['
    LEFT JOIN entity_meta em ON em.target_kind = CASE WHEN s.source_kind = 'V' THEN 'U' ELSE s.source_kind END
      AND em.target_id = s.source_id
    LEFT JOIN spawn sp ON sp.target_kind = CASE WHEN s.source_kind = 'V' THEN 'U' ELSE s.source_kind END
      AND sp.target_id = s.source_id
    WHERE i.locale = ']] .. locale .. [[' AND i.item_id = ]] .. id
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local record = { id = id, sources = {} }
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      record.title = row[1] or record.title
      if row[2] then
        table.insert(record.sources, {
          kind = row[2], id = tonumber(row[3]), chance = tonumber(row[4]), mode = row[5], title = row[6],
          zoneID = tonumber(row[7]), x = tonumber(row[8]), y = tonumber(row[9]), respawn = tonumber(row[10]), level = row[11],
        })
      end
    end
    if not record.title then
      if callback then callback(nil, nil) end
      return
    end

    -- Some generic container templates carry loot but no individual world
    -- spawns. Resolve only those templates in a second query through mapped
    -- objects with the same localized name. Keeping this separate avoids
    -- changing the fast direct-source query used by ordinary item searches.
    local unresolved, sourceInfo = {}, {}
    for sourceIndex = 1, table.getn(record.sources) do
      local source = record.sources[sourceIndex]
      if source.kind == "O" and source.title and not source.zoneID and not sourceInfo[source.id] then
        sourceInfo[source.id] = source
        table.insert(unresolved, tostring(source.id))
      end
    end

    if table.getn(unresolved) == 0 then
      if callback then callback(record, nil) end
      return
    end

    local variantSQL = [[SELECT original.target_id, original.title,
        sp.zone_id, sp.x, sp.y, sp.respawn
      FROM entity_text original
      JOIN entity_text variant ON variant.target_kind = 'O'
        AND variant.locale = original.locale AND variant.title = original.title
      JOIN spawn sp ON sp.target_kind = 'O' AND sp.target_id = variant.target_id
      WHERE original.target_kind = 'O' AND original.locale = ']] .. locale .. [['
        AND original.target_id IN (]] .. table.concat(unresolved, ",") .. [[)
        AND NOT EXISTS (
          SELECT 1 FROM spawn direct_spawn
          WHERE direct_spawn.target_kind = 'O' AND direct_spawn.target_id = original.target_id
        )]]
    local variantOK, variantTicket = pcall(HDB_QueryRawAsync, handle, variantSQL, function(_, variantRows, variantErr)
      if not variantErr then
        for rowIndex = 1, table.getn(variantRows or {}) do
          local row, originalID = variantRows[rowIndex], tonumber(variantRows[rowIndex][1])
          local source = sourceInfo[originalID]
          if source then
            table.insert(record.sources, {
              kind = "O", id = originalID, chance = source.chance, mode = source.mode, title = row[2],
              zoneID = tonumber(row[3]), x = tonumber(row[4]), y = tonumber(row[5]), respawn = tonumber(row[6]),
            })
          end
        end
      else
        HDB_ClearPoison(handle)
      end
      if callback then callback(record, nil) end
    end)
    if not variantOK or not variantTicket then
      if callback then callback(record, nil) end
    end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit item source query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetUnitDropsAsync(unitID, callback)
  local handle = Open()
  unitID = tonumber(unitID)
  if not handle or not unitID then
    if callback then callback(nil, "HearthDB is unavailable or unit id is invalid") end
    return nil
  end
  if unitDropsCache[unitID] then callback(unitDropsCache[unitID], nil); return true end
  local sql = [[SELECT item_id, chance, source_type, source_count,
    EXISTS(SELECT 1 FROM quest_target q WHERE q.phase='start' AND q.target_kind='I' AND q.target_id=drops.item_id),
    (SELECT title FROM item_text it WHERE it.item_id=drops.item_id AND it.locale=']] .. CurrentLocale() .. [[' LIMIT 1) FROM (
    SELECT s.item_id AS item_id, s.chance AS chance, 'direct' AS source_type,
      (SELECT COUNT(*) FROM item_source c WHERE c.item_id=s.item_id AND c.source_kind='U') AS source_count
    FROM item_source s WHERE s.source_kind='U' AND s.source_id=]] .. unitID .. [[
      AND NOT EXISTS (SELECT 1 FROM refloot_source token WHERE token.reference_id=s.item_id)
    UNION ALL
    SELECT s.item_id AS item_id, s.chance AS chance, 'reference' AS source_type,
      (SELECT COUNT(*) FROM refloot_source c WHERE c.reference_id=s.source_id AND c.source_kind='U') AS source_count
    FROM item_source s JOIN refloot_source r ON r.reference_id=s.source_id
      AND r.source_kind='U' AND r.source_id=]] .. unitID .. [[
    WHERE s.source_kind='R') drops ORDER BY CAST(chance AS REAL) DESC]]
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(_, rows, err)
    if err then HDB_ClearPoison(handle); callback(nil, err); return end
    local drops, seen = {}, {}
    for index=1,table.getn(rows or {}) do local row=rows[index]; local item=tonumber(row[1])
      if item and not seen[item] then seen[item]=true; table.insert(drops,{item=item,chance=tonumber(row[2]) or 0,isRef=row[3]=="reference",sourceCount=tonumber(row[4]) or 0,isQuestStarter=tonumber(row[5])==1,title=row[6]}) end
    end
    unitDropsCache[unitID]=drops; callback(drops,nil)
  end)
  if not ok or not ticket then callback(nil,"could not submit unit drops query"); return nil end
  return ticket
end

function pfQuestHearthDB:GetQuestEligibilityAsync(id, callback)
  local handle = Open()
  id = tonumber(id)
  if not handle or not id then
    if callback then callback(nil, "HearthDB is unavailable or quest id is invalid") end
    return nil
  end
  local sql = [[SELECT m.level, m.min_level, m.race_mask, m.class_mask, m.skill, m.event, p.prerequisite_id
    FROM quest_meta m LEFT JOIN quest_prerequisite p ON p.quest_id = m.quest_id
    WHERE m.quest_id = ]] .. id
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local row = rows and rows[1]
    if not row then
      if callback then callback(nil, nil) end
      return
    end
    local record = {
      id = id, level = row[1], minLevel = row[2], raceMask = row[3], classMask = row[4],
      skill = row[5], event = row[6], prerequisites = {},
    }
    for index = 1, table.getn(rows) do
      if rows[index][7] then table.insert(record.prerequisites, tonumber(rows[index][7])) end
    end
    if callback then callback(record, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest eligibility query") end
    return nil
  end
  return ticket
end

-- Public experimental contract. It returns plain records, rather than HDB's
-- positional rows, so a future pfQuest adapter will not depend on SQL layout.
-- Native provider boundary for the available-quest-giver phase. It applies
-- stable eligibility predicates in SQLite; the addon will later apply history,
-- prerequisites, and profession checks before it renders any results.
function pfQuestHearthDB:GetQuestStartPinsAsync(options, callback)
  local handle = Open()
  options = options or {}
  if not handle then
    if callback then callback(nil, "HearthDB is unavailable") end
    return nil
  end
  local level = math.floor(tonumber(options.level) or 0)
  local highOffset = math.floor(tonumber(options.highOffset) or 0)
  local raceMask = math.floor(tonumber(options.raceMask) or 0)
  local classMask = math.floor(tonumber(options.classMask) or 0)
  local faction = options.faction == "H" and "H" or "A"
  local includeLow = options.includeLow and 1 or 0
  local includeAllLevels = options.includeAllLevels and 1 or 0
  local includeEvents = options.includeEvents and 1 or 0
  local questID = math.floor(tonumber(options.questID) or 0)
  local prerequisiteID = math.floor(tonumber(options.prerequisiteID) or 0)
  local sql = [[WITH resolved_start AS (
      SELECT q.quest_id, q.target_kind, q.target_id, q.target_kind AS origin_kind,
        q.target_id AS origin_id, NULL AS chance
      FROM quest_target q
      WHERE q.phase = 'start' AND q.target_kind IN ('U', 'O')
      UNION ALL
      SELECT q.quest_id, src.source_kind, src.source_id, 'I', q.target_id, src.chance
      FROM quest_target q JOIN item_source src ON src.item_id = q.target_id
        AND src.source_kind IN ('U', 'O')
      WHERE q.phase = 'start' AND q.target_kind = 'I'
      UNION ALL
      SELECT q.quest_id, ref.source_kind, ref.source_id, 'I', q.target_id, src.chance
      FROM quest_target q JOIN item_source src ON src.item_id = q.target_id AND src.source_kind = 'R'
      JOIN refloot_source ref ON ref.reference_id = src.source_id AND ref.source_kind IN ('U', 'O')
      WHERE q.phase = 'start' AND q.target_kind = 'I'
    )
    SELECT q.quest_id, qt.title, qt.objective, qm.level, qm.min_level, qm.skill, qm.event,
      q.target_kind, q.target_id, em.level, em.faction, s.x, s.y, s.zone_id, s.respawn, e.title,
      GROUP_CONCAT(qp.prerequisite_id), q.origin_kind, q.origin_id, q.chance, it.title
    FROM resolved_start q
    JOIN quest_text qt ON qt.id = q.quest_id AND qt.locale = ']] .. CurrentLocale() .. [['
    JOIN quest_meta qm ON qm.quest_id = q.quest_id
    LEFT JOIN quest_prerequisite qp ON qp.quest_id = q.quest_id
    JOIN spawn s ON s.target_kind = q.target_kind AND s.target_id = q.target_id
    LEFT JOIN entity_meta em ON em.target_kind = q.target_kind AND em.target_id = q.target_id
    LEFT JOIN entity_text e ON e.target_kind = q.target_kind AND e.target_id = q.target_id
      AND e.locale = ']] .. CurrentLocale() .. [['
    LEFT JOIN item_text it ON it.item_id = q.origin_id AND q.origin_kind = 'I'
      AND it.locale = ']] .. CurrentLocale() .. [['
    WHERE 1 = 1
      AND (]] .. questID .. [[ = 0 OR q.quest_id = ]] .. questID .. [[)
      AND (]] .. prerequisiteID .. [[ = 0 OR EXISTS (
        SELECT 1 FROM quest_prerequisite direct_pre
        WHERE direct_pre.quest_id = q.quest_id
          AND direct_pre.prerequisite_id = ]] .. prerequisiteID .. [[
      ))
      AND (qm.race_mask = '' OR (CAST(qm.race_mask AS INTEGER) & ]] .. raceMask .. [[) = ]] .. raceMask .. [[)
      AND (qm.class_mask = '' OR (CAST(qm.class_mask AS INTEGER) & ]] .. classMask .. [[) = ]] .. classMask .. [[)
      AND (]] .. includeEvents .. [[ = 1 OR qm.event = '')
      AND (]] .. includeAllLevels .. [[ = 1 OR ]] .. includeLow .. [[ = 1 OR CAST(qm.level AS INTEGER) >= ]] .. (level - 4) .. [[)
      AND (]] .. includeAllLevels .. [[ = 1 OR CAST(qm.min_level AS INTEGER) <= ]] .. (level + highOffset) .. [[)
      AND (em.faction IS NULL OR em.faction = '' OR instr(em.faction, ']] .. faction .. [[') > 0)
    GROUP BY q.quest_id, q.target_kind, q.target_id, q.origin_kind, q.origin_id,
      q.chance, s.x, s.y, s.zone_id, s.respawn]]
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local pins = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      table.insert(pins, {
        questID = tonumber(row[1]), quest = row[2], objective = row[3], qlvl = tonumber(row[4]) or 0,
        qmin = tonumber(row[5]) or 0, skill = row[6], event = row[7], targetKind = row[8],
        targetID = tonumber(row[9]), level = row[10], faction = row[11], x = tonumber(row[12]),
        y = tonumber(row[13]), zoneID = tonumber(row[14]), respawn = tonumber(row[15]), title = row[16],
        prerequisites = row[17], originKind = row[18], originID = tonumber(row[19]),
        chance = tonumber(row[20]), itemTitle = row[21],
      })
    end
    if callback then callback(pins, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit start-pin query") end
    return nil
  end
  return ticket
end

function pfQuestHearthDB:GetQuestTargetsAsync(id, callback, limit)
  local handle = Open()
  id = tonumber(id)
  if not handle or not id then
    if callback then callback(nil, "HearthDB is unavailable or quest id is invalid") end
    return nil
  end
  limit = math.floor(tonumber(limit) or 0)
  local cacheKey = CacheKey(id, limit > 0 and limit or nil)
  if questTargetCache[cacheKey] then
    if callback then callback(questTargetCache[cacheKey], nil) end
    return true
  end

  local sql = [[WITH resolved_target AS (
      -- Keep original quest links for objective semantics.
      SELECT quest_id, phase, target_kind, target_id, target_kind AS origin_kind, target_id AS origin_id, NULL AS chance,
        target_kind AS source_kind
      FROM quest_target WHERE target_kind <> 'IR'
      UNION
      -- Item requirements encode a direct source in pfQuest's database.
      SELECT q.quest_id, q.phase, ir.source_kind, ir.source_id, q.target_kind, q.target_id, NULL AS chance,
        ir.source_kind AS source_kind
      FROM quest_target q JOIN item_requirement ir
        ON q.target_kind = 'IR' AND ir.item_id = q.target_id
      UNION
      -- Normal item objectives need direct and reference-loot sources.
      SELECT q.quest_id, q.phase, CASE WHEN s.source_kind = 'V' THEN 'U' ELSE s.source_kind END, s.source_id,
        q.target_kind, q.target_id, s.chance, s.source_kind
      FROM quest_target q JOIN item_source s
        ON q.target_kind = 'I' AND s.item_id = q.target_id
      WHERE s.source_kind IN ('U', 'O', 'V')
      UNION
      SELECT q.quest_id, q.phase, CASE WHEN r.source_kind = 'V' THEN 'U' ELSE r.source_kind END, r.source_id,
        q.target_kind, q.target_id, s.chance, r.source_kind
      FROM quest_target q JOIN item_source s
        ON q.target_kind = 'I' AND s.item_id = q.target_id AND s.source_kind = 'R'
      JOIN refloot_source r ON r.reference_id = s.source_id
    )
    SELECT q.phase, q.target_kind, q.target_id, q.origin_kind, q.origin_id, q.chance, q.source_kind,
      COALESCE(em.level, 'N/A'), em.rank,
      COALESCE(s.x, a.x, z.x), COALESCE(s.y, a.y, z.y),
      COALESCE(s.zone_id, a.zone_id, z.map_id), COALESCE(s.respawn, '0'),
      COALESCE(e.title, zt.title,
        CASE WHEN q.target_kind = 'A' THEN 'Exploration Trigger ' || q.target_id END),
      it.title,
      (SELECT GROUP_CONCAT(shared_e.title, '|')
        FROM spawn shared_s
        JOIN entity_text shared_e ON shared_e.target_kind = 'U'
          AND shared_e.target_id = shared_s.target_id
          AND shared_e.locale = ']] .. CurrentLocale() .. [['
        WHERE q.target_kind = 'U'
          AND shared_s.target_kind = 'U'
          AND shared_s.zone_id = s.zone_id
          AND shared_s.x = s.x AND shared_s.y = s.y
          AND shared_s.target_id <> q.target_id) AS shared_titles,
      (SELECT GROUP_CONCAT(objective_e.title, '|')
        FROM quest_target objective_q
        JOIN entity_text objective_e
          ON objective_e.target_kind = objective_q.target_kind
          AND objective_e.target_id = objective_q.target_id
          AND objective_e.locale = ']] .. CurrentLocale() .. [['
        WHERE q.origin_kind = 'IR'
          AND objective_q.quest_id = q.quest_id
          AND objective_q.phase = 'obj'
          AND objective_q.target_kind IN ('U', 'O')
          AND objective_q.target_id <> q.target_id) AS related_objective_titles
    FROM resolved_target q
    LEFT JOIN spawn s ON s.target_kind = q.target_kind AND s.target_id = q.target_id
    LEFT JOIN areatrigger_spawn a ON q.target_kind = 'A' AND a.trigger_id = q.target_id
    LEFT JOIN zone_data z ON q.target_kind = 'Z' AND z.zone_id = q.target_id
    LEFT JOIN entity_meta em ON em.target_kind = q.target_kind AND em.target_id = q.target_id
    LEFT JOIN entity_text e ON e.target_kind = q.target_kind AND e.target_id = q.target_id
      AND e.locale = ']] .. CurrentLocale() .. [['
    LEFT JOIN item_text it ON (q.origin_kind = 'I' OR q.origin_kind = 'IR')
      AND it.item_id = q.origin_id AND it.locale = ']] .. CurrentLocale() .. [['
    LEFT JOIN zone_text zt ON q.target_kind = 'Z' AND zt.zone_id = q.target_id
      AND zt.locale = ']] .. CurrentLocale() .. [['
    WHERE q.quest_id = ]] .. id
  if limit > 0 then sql = sql .. " LIMIT " .. limit end

  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end

    local records = {}
    for index = 1, table.getn(rows or {}) do
      local row = rows[index]
      local sharedSpawns = {}
      for title in string.gfind(row[16] or "", "[^|]+") do sharedSpawns[title] = true end
      local relatedObjectives = {}
      for title in string.gfind(row[17] or "", "[^|]+") do relatedObjectives[title] = true end
      table.insert(records, {
        phase = row[1],
        targetKind = row[2],
        targetID = tonumber(row[3]),
        originKind = row[4],
        originID = tonumber(row[5]),
        chance = tonumber(row[6]),
        sourceKind = row[7], level = row[8],
        rank = row[9], x = tonumber(row[10]),
        y = tonumber(row[11]), zoneID = tonumber(row[12]),
        respawn = tonumber(row[13]), title = row[14], itemTitle = row[15],
        sharedSpawns = next(sharedSpawns) and sharedSpawns or nil,
        relatedObjectives = next(relatedObjectives) and relatedObjectives or nil,
      })
    end
    questTargetCache[cacheKey] = records
    if callback then callback(records, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit target query") end
    return nil
  end
  return ticket
end

-- Resolve the quest-log Show destination without materializing every objective
-- pin. Direct enders win over starters, matching the legacy Lua-table lookup.
function pfQuestHearthDB:GetQuestHubMapAsync(id, callback)
  local handle = Open()
  id = math.floor(tonumber(id) or 0)
  if not handle or id <= 0 then
    if callback then callback(nil, "HearthDB is unavailable or quest id is invalid") end
    return nil
  end
  local sql = [[SELECT q.phase, s.zone_id, COUNT(*)
    FROM quest_target q
    JOIN spawn s ON s.target_kind = q.target_kind AND s.target_id = q.target_id
    WHERE q.quest_id = ]] .. id .. [[
      AND q.phase IN ('start', 'end')
      AND q.target_kind IN ('U', 'O')
      AND s.zone_id > 0
    GROUP BY q.phase, s.zone_id
    ORDER BY CASE q.phase WHEN 'end' THEN 0 ELSE 1 END, COUNT(*) DESC, s.zone_id ASC]]
  local ok, ticket = pcall(HDB_QueryRawAsync, handle, sql, function(columns, rows, err)
    if err then
      HDB_ClearPoison(handle)
      if callback then callback(nil, err) end
      return
    end
    local row = rows and rows[1]
    if callback then callback(row and tonumber(row[2]) or nil, nil) end
  end)
  if not ok or not ticket then
    if callback then callback(nil, "could not submit quest hub query") end
    return nil
  end
  return ticket
end

-- Public provider boundary for a future vanilla pfQuest-HDB edition. It owns
-- the asynchronous lookup and returns only map-ready records, so consumers do
-- not need to know about SQLite rows, item source expansion, or cache keys.
function pfQuestHearthDB:GetQuestMapPinsAsync(id, callback, limit)
  id = tonumber(id)
  if not id then
    if callback then callback(nil, "quest id is invalid") end
    return nil
  end
  limit = math.floor(tonumber(limit) or 0)
  local cacheKey = CacheKey(id, limit > 0 and limit or nil)
  if questMapPinCache[cacheKey] then
    if callback then callback(questMapPinCache[cacheKey], nil) end
    return true
  end

  return self:GetQuestTextAsync(id, function(quest, textErr)
    if textErr or not quest then
      if callback then callback(nil, textErr or "quest was not found") end
      return
    end
    self:GetQuestTargetsAsync(id, function(records, targetErr)
      if targetErr then
        if callback then callback(nil, targetErr) end
        return
      end
      local result = {
        id = id, title = quest.title, objective = quest.objective, description = quest.description,
        level = quest.level, minLevel = quest.minLevel, pins = {}, hasObjectives = false,
      }
      for index = 1, table.getn(records or {}) do
        local row = records[index]
        if row.phase == "obj" then result.hasObjectives = true end
        if row.zoneID and row.x and row.y then
          table.insert(result.pins, {
            phase = row.phase,
            targetKind = row.targetKind,
            targetID = row.targetID,
            originKind = row.originKind,
            originID = row.originID,
            chance = row.chance,
            level = row.level,
            zoneID = row.zoneID,
            x = row.x,
            y = row.y,
            respawn = row.respawn,
            title = row.title or (row.targetKind .. " " .. row.targetID),
            itemTitle = row.itemTitle,
            sharedSpawns = row.sharedSpawns,
            relatedObjectives = row.relatedObjectives,
          })
        end
      end
      questMapPinCache[cacheKey] = result
      if callback then callback(result, nil) end
    end, limit)
  end)
end

SLASH_PFQUESTHDB1 = "/pfqhdb"
SlashCmdList.PFQUESTHDB = function(input)
  local command = string.lower(tostring(input or ""))
  if command == "cacheclear" then
    ClearCache()
    Print("HDB query cache cleared.")
  else
    Print("HearthDB=" .. tostring(Available()) .. ", open=" .. tostring(dbHandle ~= nil)
      .. ". Use /pfqhdb cacheclear to clear query caches.")
  end
end

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_LOGOUT")
addon:SetScript("OnEvent", function()
  if event == "PLAYER_LOGOUT" then
    Close()
  else
    Open()
    pfQuestHearthDB:PreloadQuestTitleIDsAsync()
    pfQuestHearthDB:PreloadQuestDisambiguationAsync()
  end
end)
