-- Retain quest records unique to the feature branch when importing the new database.
pfDB["quests"]["data-turtle"] = pfDB["quests"]["data-turtle"] or {}
pfDB["quests"]["data-turtle"][8595] = { ["end"] = { ["U"] = { 15503 } }, ["event"] = 164, ["lvl"] = 60, ["min"] = 60, ["obj"] = { ["I"] = { 21229 } }, ["start"] = { ["U"] = { 15503 } } }
pfDB["quests"]["data-turtle"][8764] = { ["end"] = { ["U"] = { 15192 } }, ["event"] = 164, ["lvl"] = 60, ["min"] = 60, ["obj"] = { ["I"] = { 20858, 20859, 20860, 21200 } }, ["start"] = { ["U"] = { 15192 } } }
pfDB["quests"]["data-turtle"][8765] = { ["end"] = { ["U"] = { 15192 } }, ["event"] = 164, ["lvl"] = 60, ["min"] = 60, ["obj"] = { ["I"] = { 20861, 20862, 20863, 21210 } }, ["start"] = { ["U"] = { 15192 } } }
pfDB["quests"]["data-turtle"][8766] = { ["end"] = { ["U"] = { 15192 } }, ["event"] = 164, ["lvl"] = 60, ["min"] = 60, ["obj"] = { ["I"] = { 20858, 20864, 20865, 21205 } }, ["start"] = { ["U"] = { 15192 } } }

-- High-confidence objective links found by matching clear kill, collect, and
-- recover objectives to existing Turtle entity records with map coordinates.
-- Keep this as a small overlay so database upgrades do not overwrite the audit.
local turtleQuestObjectives = {
  -- Redridge item-objectives: also list the source object directly.  The base
  -- item links alone are not consistently added to the active quest overlay.
  [125]   = { ["I"] = { 1309 }, ["O"] = { 32 } }, -- The Lost Tools: Sunken Chest in Lake Everstill
  [2282]  = { ["I"] = { 7871 }, ["O"] = { 121264 } }, -- Alther's Mill: Lucius's Lockbox
  [3741]  = { ["I"] = { 10958 }, ["O"] = { 154357 } }, -- Hilary's Necklace: Glinting Mud
  [465]   = { ["O"] = { 1000098 } }, -- Nek'rosh's Gambit: Dragonmaw Catapults
  [41947] = { ["U"] = { 63088 } }, -- Wanted: Tama'an the Ruthless
  [41976] = { ["O"] = { 2020320 } }, -- In Search of Tauren Relics
  [41978] = { ["U"] = { 62760 } }, -- The Wrath of Malgan
  [41982] = { ["U"] = { 62781 } }, -- Destroy the Deathtotem
  [41989] = { ["O"] = { 2020321 } }, -- Slithering Snakes
  [41931] = { ["U"] = { 62871 } }, -- The Corruption of Timbermaw Hold
  [41933] = { ["O"] = { 2020307, 2020308 } }, -- Unbridled Darkness
  [42004] = { ["O"] = { 2020330 } }, -- Drenched in Power
  [42005] = { ["U"] = { 60748 } }, -- The Rift Calls
  [42037] = { ["O"] = { 2020338 } }, -- Airfield Supplies
  [42038] = { ["U"] = { 63166, 63167, 63170 } }, -- The Frostmane War
  [42039] = { ["U"] = { 63131 } }, -- Chieftain Ubukaz
  [42040] = { ["O"] = { 2020339 } }, -- A Grave Misunderstanding!
  [40474] = { ["U"] = { 60858 } }, -- Deliver the Harvester Blueprint to Maltimor
}

for questId, objectives in pairs(turtleQuestObjectives) do
  local quest = pfDB["quests"]["data-turtle"][questId]
  if quest then
    quest["obj"] = objectives
  end
end
